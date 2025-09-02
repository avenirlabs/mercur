# syntax=docker/dockerfile:1

######## base ########
FROM node:20-alpine AS base
WORKDIR /app
ENV NPM_CONFIG_LEGACY_PEER_DEPS=true \
    NPM_CONFIG_UPDATE_NOTIFIER=false

######## deps ########
FROM base AS deps
# Copy manifests early for caching; include packages if you have monorepo
COPY package.json ./
COPY apps/backend/package.json ./apps/backend/package.json
COPY packages ./packages
RUN npm install --ignore-scripts

######## build ########
FROM base AS build
COPY --from=deps /app /app
COPY . .
# Build internal packages (if they define "build")
RUN npm run build -ws --if-present || true

# Build Medusa output (.medusa) with a larger heap
WORKDIR /app/apps/backend
ENV NODE_OPTIONS=--max-old-space-size=2048
RUN npx -y @medusajs/cli@2.8.6 build

######## runner ########
FROM node:20-alpine AS runner
ENV NODE_ENV=production
WORKDIR /app/apps/backend

# Minimal runtime copy
COPY --from=build /app/apps/backend/package.json ./
COPY --from=build /app/apps/backend/node_modules ./node_modules
COPY --from=build /app/apps/backend/.medusa ./.medusa
COPY --from=build /app/apps/backend/public ./public 2>/dev/null || true

EXPOSE 3000
CMD ["node", ".medusa/server/index.js"]
