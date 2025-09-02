# syntax=docker/dockerfile:1

######## 1) deps ########
FROM node:20-alpine AS deps
# If you use native modules (sharp/bcrypt/etc.), uncomment:
# RUN apk add --no-cache python3 make g++ libc6-compat

WORKDIR /app/apps/backend
# Install only from backend manifest so we cache node_modules
COPY apps/backend/package.json ./
RUN npm install --ignore-scripts

######## 2) build ########
FROM node:20-alpine AS build
WORKDIR /app

# Reuse installed deps
COPY --from=deps /app/apps/backend/node_modules ./apps/backend/node_modules

# Bring full source
COPY . .

WORKDIR /app/apps/backend
# If you use codegen/Prisma, do it here (after sources exist):
# RUN npx prisma generate

# Build Medusa app (your scripts handle this). Won't fail if no build script.
RUN npm run build || echo "No build script; continuing"

######## 3) runner ########
FROM node:20-alpine AS runner
ENV NODE_ENV=production
WORKDIR /app/apps/backend

# Copy the WHOLE backend folder so package.json, configs, and .medusa exist
COPY --from=build /app/apps/backend ./ 

# Ensure public assets symlink points to built output (idempotent)
RUN ln -sfn .medusa/server/public public || true

# Optional: slim image (remove devDependencies)
# RUN npm prune --omit=dev

# Railway injects PORT; Medusa binds to it automatically via "medusa start"
EXPOSE 3000

# Start as defined in your package.json ("start": "medusa start --types=false")
CMD ["npm", "run", "start"]
