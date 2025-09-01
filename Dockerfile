# syntax=docker/dockerfile:1

FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
# Copy workspace/backend manifest if monorepo
COPY apps/backend/package*.json apps/backend/
RUN npm ci

FROM node:20-alpine AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
WORKDIR /app/apps/backend
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /app/apps/backend/node_modules ./node_modules
COPY --from=build /app/apps/backend/dist ./dist

# Railway provides a PORT env var – your server must use it
EXPOSE 3000
CMD ["node", "dist/server.js"]
