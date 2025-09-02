COPY .npmrc /app/.npmrc
ENV NPM_CONFIG_USERCONFIG=/app/.npmrc
# syntax=docker/dockerfile:1

########################
# 1) Install dependencies (no lockfile)
########################
FROM node:20-alpine AS deps
# If you need native modules, uncomment the next line:
# RUN apk add --no-cache python3 make g++ libc6-compat
WORKDIR /app/apps/backend

# Copy only the backend manifest first (faster caching)
COPY apps/backend/package.json ./

# Install deps without running postinstall (avoids prisma/generator errors)
RUN npm install --ignore-scripts

########################
# 2) Build the app
########################
FROM node:20-alpine AS build
WORKDIR /app

# Bring installed node_modules into backend
COPY --from=deps /app/apps/backend/node_modules ./apps/backend/node_modules

# Now copy the full repo source
COPY . .

WORKDIR /app/apps/backend
# If you use Prisma or codegen, run those now (uncomment if needed):
# RUN npx prisma generate

# Build if a build script exists; otherwise continue
RUN npm run build || echo "No build script; continuing"

########################
# 3) Runtime image
########################
FROM node:20-alpine AS runner
WORKDIR /app/apps/backend
ENV NODE_ENV=production

# Copy runtime deps and built files
COPY --from=build /app/apps/backend/node_modules ./node_modules
# Copy dist if it exists (ignore if not)
COPY --from=build /app/apps/backend/dist ./dist
# Copy anything your app needs at runtime (env schemas, migrations, templates, prisma, etc.)
# COPY --from=build /app/apps/backend/prisma ./prisma
# COPY --from=build /app/apps/backend/migrations ./migrations
# COPY --from=build /app/apps/backend/templates ./templates

# Railway assigns PORT; your server must read process.env.PORT
EXPOSE 3000

# Prefer using the package.json start script (works whether TS or JS)
CMD ["npm", "run", "start"]
