#===============================================================================
#  Consumer Node.js - RabbitMQ to MongoDB
#===============================================================================

FROM node:20-alpine

LABEL maintainer="Vehicle Tracking System"
LABEL description="Node.js Consumer - RabbitMQ to MongoDB"

WORKDIR /app

# Install dependencies
RUN apk add --no-cache curl && \
    rm -rf /var/cache/apk/*

# Copy package files
COPY consumer-node/package*.json ./

# Install production dependencies
RUN npm install --omit=dev

# Copy source code
COPY consumer-node/src ./src
COPY consumer-node/index.js ./

# Copy proto files
COPY proto ./proto

# Expose ports
EXPOSE 3000 9124

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=5 \
    CMD curl -sf http://localhost:3000/health || exit 1

# Run as non-root user
USER node

# Start application
CMD ["node", "index.js"]
