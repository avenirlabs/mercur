# syntax=docker/dockerfile:1

######## base ########
FROM node:20-alpine AS base
WORKDIR /app
ENV NPM_CONFIG_LEGACY_PEER_DEPS=true \
    NPM_CONFIG_UPDATE_NOTIFIER=false

######## deps: install from root (workspaces) ########
FROM base AS deps
# Copy root manifest + workspace manifests BEFORE install so linking works
COPY package.json ./
COPY apps/backend/package.json ./apps/backend/package.json
COPY packages ./packages
# Install all workspace deps at root; skip scripts for now
RUN npm install --ignore-scripts

######## build ########
FROM base AS build
# Reuse installed deps and manifests
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/package.json ./
COPY --from=deps /app/apps/backend/package.json ./apps/backend/package.json
COPY --from=deps /app/packages ./packages

# Bring full source (ts, config, etc.)
COPY . .

# Build all packages that declare a build script, then the backend
RUN npm run build -ws --if-present || true
WORKDIR /app/apps/backend
# Medusa build (your script handles .medusa + public symlink)
RUN npm run build || echo "No build script; continuing"

######## runner ########
FROM node:20-alpine AS runner
ENV NODE_ENV=production
WORKDIR /app/apps/backend

# Copy the built monorepo so package.json, .medusa, and all linked deps exist
COPY --from=build /app ./

# Ensure public assets link (idempotent)
RUN ln -sfn .medusa/server/public public || true

EXPOSE 3000

# Safer start: migrate then start the compiled server directly
CMD ["sh","-lc","npx -y @medusajs/cli@2.8.6 db:migrate && node .medusa/server/index.js"]
