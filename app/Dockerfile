#########################################
# Stage 1: Install Dependencies
#########################################
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files first (leverages Docker cache)
COPY package.json ./

# Install production dependencies only
RUN npm install --omit=dev --silent

#########################################
# Stage 2: Production Image
#########################################
FROM node:18-alpine

WORKDIR /app

# Create non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy dependencies from builder stage
COPY --from=builder /app/node_modules ./node_modules

# Copy application code
COPY package.json ./
COPY server.js ./

# Set ownership to non-root user
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Application port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/ || exit 1

# Start the application
CMD ["node", "server.js"]
