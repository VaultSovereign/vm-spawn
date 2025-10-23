FROM node:20-slim

# Install dependencies for git operations (needed by Remembrancer)
RUN apt-get update && \
    apt-get install -y git gpg && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the entire repository (Scheduler needs access to Remembrancer CLI)
COPY . /app

# Install Scheduler dependencies
WORKDIR /app/services/scheduler
RUN npm ci --production=false

# Install tsx for running TypeScript (better ESM support than ts-node)
RUN npm install -g tsx

# Note: Using tsx to run TypeScript directly (handles ESM + federation module issues)

# Create directories for state and output
RUN mkdir -p /app/out/state /app/out/batches

# Set environment variables
ENV NODE_ENV=production
ENV VMSH_ROOT=/app
ENV VMSH_NAMESPACES=/app/vmsh/config/namespaces.yaml
ENV VMSH_STATE=/app/out/state/scheduler.json
ENV VMSH_TICK_MS=30000
ENV METRICS_PORT=9091

EXPOSE 9091

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:9091/health', (r) => { process.exit(r.statusCode === 200 ? 0 : 1) })"

# Run using tsx (better TypeScript/ESM support)
CMD ["tsx", "src/index.ts"]
