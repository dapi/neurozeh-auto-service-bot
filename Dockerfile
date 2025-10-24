# Multi-stage build for optimization
FROM ruby:3.2.2-alpine AS builder

# Set working directory
WORKDIR /app

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    openssl-dev \
    libffi-dev \
    ncurses-dev \
    readline-dev \
    zlib-dev \
    tzdata

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install dependencies with clean output
RUN bundle config set --local without 'development test' && \
    bundle install --jobs=4 --retry=3 --deployment && \
    bundle clean

# Production stage
FROM ruby:3.2.2-alpine AS production

# Set working directory
WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache \
    openssl \
    libffi \
    ncurses-libs \
    readline \
    zlib \
    tzdata \
    ca-certificates \
    curl

# Create non-root user for security
RUN addgroup -g 1000 bot && \
    adduser -D -s /bin/sh -u 1000 -G bot bot

# Copy installed gems from builder stage
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /app /app

# Copy application files
COPY --chown=bot:bot . .

# Set permissions
RUN chmod +x bot.rb

# Switch to non-root user
USER bot

# Set environment variables
ENV RACK_ENV=production \
    RAILS_ENV=production \
    RUBYOPT="-W0" \
    LOG_LEVEL=info

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pgrep -f "ruby bot.rb" > /dev/null || exit 1

# Expose port (for webhook mode)
EXPOSE 3000

# Set entrypoint
ENTRYPOINT ["ruby", "bot.rb"]

# Labels for metadata
LABEL maintainer="Danil Pismenny" \
      version="1.0.0" \
      description="Neurozeh Auto Service Bot for auto service booking" \
      org.opencontainers.image.title="auto-service-auto-service-bot" \
      org.opencontainers.image.description="Telegram bot for auto service booking with Claude AI" \
      org.opencontainers.image.source="https://github.com/yourusername/auto-service-auto-service-bot" \
      org.opencontainers.image.licenses="MIT"