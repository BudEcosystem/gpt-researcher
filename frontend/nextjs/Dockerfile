###############################################
# 1) Dependencies layer
###############################################
FROM node:18.17.0-alpine AS deps
WORKDIR /app

# Copy only package manifest first for better layer caching
COPY package.json ./

# Install dependencies (no lock file present – recommend adding one for reproducibility).
# Extended timeouts + retries for slow emulated builds (arm64 via qemu) where
# npm's default 5-minute socket timeout otherwise trips.
RUN npm config set fetch-timeout 1200000 \
    && npm config set fetch-retries 5 \
    && npm config set fetch-retry-maxtimeout 180000 \
    && npm install --legacy-peer-deps --no-audit --no-fund

###############################################
# 2) Builder layer – builds Next.js (.next)
###############################################
FROM node:18.17.0-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
# Build Next.js application (produces .next)
RUN npm run build \
	&& npm prune --production

###############################################
# 3) Runner layer – production image serving Next.js
###############################################
FROM node:18.17.0-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production

# Copy only what is required at runtime
COPY --from=builder /app/package.json ./
COPY --from=builder /app/next.config.mjs ./
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules

# Expose port (Next.js default)
EXPOSE 3000

# Start the Next.js production server (serves API routes too)
CMD ["npm", "run", "start"]
