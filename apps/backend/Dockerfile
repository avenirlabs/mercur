# syntax=docker/dockerfile:1

######## base ########
FROM node:20-alpine AS base
WORKDIR /app
# Yarn Classic for predictable workspace behavior
RUN npm i -g yarn@1.22.22
ENV NODE_ENV=development \
    YARN_ENABLE_IMMUTABLE_INSTALLS=false

######## deps (install workspaces) ########
FROM base AS deps
# Copy manifests early for better caching
COPY package.json yarn.lock ./
COPY apps/backend/package.json ./apps/backend/package.json
COPY packages ./packages
# Install ALL workspace deps; skip scripts here to keep it light
RUN yarn install --frozen-lockfile --ignore-scripts

######## build ########
FROM base AS build
# Reuse installed deps + manifests
COPY --from=deps /app /app
# Bring the rest of the source (ts, config, etc.)
COPY . .
# Build internal packages (if they declare "build")
RUN yarn workspaces run build || true
# Build Medusa server output (.medusa) with more heap to avoid OOM
WORKDIR /app/apps/backend
ENV NODE_OPTIONS=--max-old-space-size=2048
RUN npx -y @medusajs/cli@2.8.6 build

######## runner ########
FROM node:20-alpine AS runner
WORKDIR /app/apps/backend
ENV NODE_ENV=production
# Minimal runtime copy (includes compiled `.medusa` and all node_modules)
COPY --from=build /app /app
# Ensure public assets are reachable if present
RUN ln -sfn .medusa/server/public public || true
EXPOSE 8080
# Bind to Railway's injected PORT and 0.0.0.0
CMD ["sh","-lc","HOST=0.0.0.0 PORT=${PORT:-8080} node .medusa/server/index.js"]
