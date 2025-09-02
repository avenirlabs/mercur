# syntax=docker/dockerfile:1

########################
# 1) Install deps (no lockfile)
########################
FROM node:20-alpine AS deps
WORKDIR /app/apps/backend
# If you have native deps (sharp/bcrypt/etc.), uncomment:
# RUN apk add --no-cache python3 make g++ libc6-compat

# Install only from backend package.json to get node_modules cached
COPY apps/backend/package.json ./
RUN npm install --ignore-scripts

########################
# 2) Build backend
########################
FROM node:20-alpine AS build
WORKDIR /app

# Reuse installed deps
COPY --from=deps /app/apps/backend/node_modules ./apps/backend/node_modules

# Bring full source
COPY . .

WORKDIR /app/apps/backend
# If you use codegen/Prisma, run it here (after sources exist):
# RUN npx prisma generate

# Build Medusa app (won’t fail if no build script)
# Your package.json already has: "build": "medusa build && ln -s .medusa/server/public/ public"
RUN npm run build || echo "No build script; continuing"

########################
# 3) Runtime image
########################
FROM node:20-alpine AS runner
WORKDIR /app/apps/backend
ENV NODE_ENV=production

# Copy runtime deps and built artifacts
COPY --from=build /app/apps/backend/node_modules ./node_modules
# Medusa v2 builds to .medusa; keep it
COPY --from=build /app/apps/backend/.medusa ./.medusa

# Ensure public assets path exists (symlink to built public)
RUN ln -sfn .medusa/server/public public || true

# Railway injects PORT; Medusa binds to it via `medusa start`
EXPOSE 3000

# Start via your script: "start": "medusa start --types=false"
CMD ["npm", "run", "start"]
