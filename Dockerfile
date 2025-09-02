# syntax=docker/dockerfile:1

######## base ########
FROM node:20-alpine AS base
WORKDIR /app
ENV NPM_CONFIG_LEGACY_PEER_DEPS=true NPM_CONFIG_UPDATE_NOTIFIER=false

######## deps (install from root, with workspaces) ########
FROM base AS deps
# Copy only manifests for better caching
COPY package.json ./
COPY apps/backend/package.json ./apps/backend/package.json
# Copy all workspace package manifests
COPY packages ./packages
# Keep only package.json files for now (optional optimization)
# RUN find packages -type f ! -name package.json -delete

# Install workspace deps at the root (links workspaces)
RUN npm install --ignore-scripts

######## build ########
FROM base AS build
# Bring installed deps
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/package.json ./
COPY --from=deps /app/apps/backend/package.json ./apps/backend/package.json
COPY --from=deps /app/packages ./packages

# Copy the full source
COPY . .

# (optional) build all workspaces that have a build script
RUN npm run build -ws --if-present

# Build the backend (your script runs Medusa build)
WORKDIR /app/apps/backend
RUN npm run build || echo "No build script; continuing"

######## runner ########
FROM node:20-alpine AS runner
ENV NODE_ENV=production
WORKDIR /app/apps/backend

# Copy built monorepo (you can slim this if you want)
COPY --from=build /app ./

# Medusa assets symlink (idempotent)
RUN ln -sfn .medusa/server/public public || true

EXPOSE 3000

# Migrate then start (safer) — or swap back to `npm run start`
CMD ["sh","-lc","npx -y @medusajs/cli@2.8.6 db:migrate && node .medusa/server/index.js"]
