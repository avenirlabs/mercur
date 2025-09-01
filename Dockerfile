# syntax=docker/dockerfile:1

FROM node:20-alpine AS deps
WORKDIR /app
# Copy root manifests + lockfile
COPY package.json package-lock.json ./
# Copy workspace package.json so npm can resolve them
COPY apps/backend/package.json apps/backend/package.json
# Install deps WITHOUT running postinstall (avoids prisma/build scripts failing)
RUN npm ci --ignore-scripts

FROM node:20-alpine AS build
WORKDIR /app
# Bring installed node_modules
COPY --from=deps /app/node_modules ./node_modules
# Now copy the full source
COPY . .
WORKDIR /app/apps/backend
# Now it’s safe to run scripts (schema, prisma generate, etc.)
# If you use Prisma, uncomment:
# RUN npx prisma generate
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
# Copy only what the backend needs
COPY --from=build /app/apps/backend/node_modules ./node_modules
COPY --from=build /app/apps/backend/dist ./dist
EXPOSE 3000
# Change to your actual entrypoint if different
CMD ["node", "dist/server.js"]
