# syntax=docker/dockerfile:1

######## base ########
FROM node:20-alpine AS base
WORKDIR /app
ENV NPM_CONFIG_LEGACY_PEER_DEPS=true \
    NPM_CONFIG_UPDATE_NOTIFIER=false

######## deps (install with workspaces) ########
FROM base AS deps
# Copy manifests BEFORE install so workspaces link
COPY package.json ./
COPY apps/backend/package.json ./apps/backend/package.json
COPY packages ./packages
# Install (skip scripts here if you want, we’ll build explicitly)
RUN npm install --ignore-scripts

######## build ########
FROM base AS build
# Reuse installed deps/manifests
COPY --from=deps /app /app
# Bring the rest of the source (ts configs, code, etc.)
COPY . .
# Build all workspaces that declare a build script -> creates packages/*/dist
RUN npm run build -ws --if-present || true
# Build backend (.medusa/)
WORKDIR /app/apps/backend
RUN npm run build || echo "No build script; continuing"

######## runner ########
FROM node:20-alpine AS runner
ENV NODE_ENV=production
WORKDIR /app/apps/backend
# Copy built monorepo
COPY --from=build /app /app
# Ensure public assets symlink
RUN ln -sfn .medusa/server/public public || true
EXPOSE 3000
# Migrate then start compiled server directly (avoids CLI wrapper traps)
CMD ["sh","-lc","npx -y @medusajs/cli@2.8.6 db:migrate && node .medusa/server/index.js"]
