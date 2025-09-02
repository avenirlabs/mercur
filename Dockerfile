# syntax=docker/dockerfile:1

########################
# 1) deps: install node_modules
########################
FROM node:20-alpine AS deps
WORKDIR /app/apps/backend

# If you need native builds (sharp/bcrypt/etc.), uncomment:
# RUN apk add --no-cache python3 make g++ libc6-compat

# Copy npm config for GitHub Packages auth (uses NPM_TOKEN env from Railway)
# Place a .npmrc in your repo root with the lines shown below.
COPY .npmrc /app/.npmrc
ENV NPM_CONFIG_USERCONFIG=/app/.npmrc

# Copy only manifest for faster layer caching
COPY apps/backend/package.json ./

# Install deps without running postinstall yet
RUN npm install --ignore-scripts

########################
# 2) build: compile app
########################
FROM node:20-alpine AS build
WORKDIR /app

# Bring installed deps
COPY --from=deps /app/apps/backend/node_modules ./apps/backend/node_modules

# Copy the rest of your source code
COPY . .

WORKDIR /app/apps/backend
# If you use codegen/Prisma, do it now (uncomment as needed):
# RUN npx prisma generate

# Build (won’t fail pipeline if there’s no build script)
RUN npm run build || echo "No build script; continuing"

########################
# 3) runner: minimal runtime image
########################
FROM node:20-alpine AS runner
WORKDIR /app/apps/backend
ENV NODE_ENV=production

# Copy runtime deps and built code
COPY --from=build /app/apps/backend/node_modules ./node_modules
COPY --from=build /app/apps/backend/dist ./dist

# Expose (Railway injects PORT; your app must use process.env.PORT)
EXPOSE 3000

# If your entry isn’t dist/server.js, change this or use npm start
CMD ["npm","run","start"]
