# syntax=docker/dockerfile:1

######## base ########
FROM node:20-alpine AS base
WORKDIR /app
ENV NPM_CONFIG_LEGACY_PEER_DEPS=true \
    NPM_CONFIG_UPDATE_NOTIFIER=false

######## deps ########
FROM base AS deps
# Copy local packages first so file: deps resolve during install
COPY packages ./packages
# Copy backend manifest
COPY apps/backend/package.json ./apps/backend/package.json
# Install backend deps (will link local packages via file:)
WORKDIR /app/apps/backend
RUN npm install --ignore-scripts

######## build ########
FROM base AS build
# Bring installed deps + manifests
COPY --from=deps /app /app
# Copy the rest of the source (ts, configs, etc.)
COPY . .
# Build local packages if they declare build scripts (optional but recommended)
# (requires a root package.json with "workspaces": ["apps/*","packages/*"])
RUN npm run build -ws --if-present || true
# Build the backend (creates .medusa/)
WORKDIR /app/apps/backend
RUN npm run build || echo "No build script; continuing"

######## runner ########
FROM node:20-alpine AS runner
ENV NODE_ENV=production
WORKDIR /app/apps/backend
# Copy built project
COPY --from=build /app /app
# Ensure public assets symlink exists
RUN ln -sfn .medusa/server/public public || true
EXPOSE 3000
# Migrate on boot, then start server directly (avoids CLI wrapper issues)
CMD ["sh","-lc","npx -y @medusajs/cli@2.8.6 db:migrate && node .medusa/server/index.js"]
