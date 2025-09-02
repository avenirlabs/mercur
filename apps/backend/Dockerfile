# syntax=docker/dockerfile:1

######## base ########
FROM node:20-alpine AS base
WORKDIR /app
ENV NPM_CONFIG_LEGACY_PEER_DEPS=true \
    NPM_CONFIG_UPDATE_NOTIFIER=false

######## deps ########
FROM base AS deps
# Copy manifests early for caching
COPY package.json ./
COPY apps/backend/package.json ./apps/backend/package.json
COPY packages ./packages
# Install all deps (with dev) at root/back-end for build
RUN npm install --ignore-scripts

######## build ########
FROM base AS build
# Bring deps + manifests
COPY --from=deps /app /app
# Bring full source
COPY . .
# Build internal packages if they have a build script
RUN npm run build -ws --if-present || true
# Build the Medusa server (.medusa/)
WORKDIR /app/apps/backend
# give the builder more heap so it won't OOM
ENV NODE_OPTIONS=--max-old-space-size=2048
RUN npx -y @medusajs/cli@2.8.6 build

######## runner ########
FROM node:20-alpine AS runner
ENV NODE_ENV=production
WORKDIR /app/apps/backend

# Copy only what's needed for runtime
COPY --from=build /app/apps/backend/package.json ./
COPY --from=build /app/apps/backend/node_modules ./node_modules
COPY --from=build /app/apps/backend/.medusa ./.medusa
COPY --from=build /app/apps/backend/public ./public 2>/dev/null || true
# (If you have config, migrations, etc., copy them too)
COPY --from=build /app/apps/backend/src ./src  # optional if you need runtime src

EXPOSE 3000

# Start the compiled server (no build at runtime)
CMD ["node", ".medusa/server/index.js"]
