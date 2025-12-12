# Multi-stage build:
#  - builder: install build deps & create venv with application dependencies
#  - final: lightweight runtime with python venv + dumb-init, non-root user
#
# This is a simplified version running Gunicorn with Uvicorn workers directly.

################################
# Builder stage (build artifacts)
################################
FROM python:3.14-slim AS builder

# Set environment variables for security & reproducibility
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_DEFAULT_TIMEOUT=100

WORKDIR /app

# Install build dependencies only for build stage
RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential gcc && \
    rm -rf /var/lib/apt/lists/*

# Install Python dependencies in a virtual environment
COPY requirements.txt .
RUN python -m venv /opt/venv \
    && /opt/venv/bin/pip install --upgrade pip setuptools wheel \
    && /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

# Copy application source
COPY . /app

######################
# Final runtime image
######################
FROM python:3.14-slim

# keep metadata about build
LABEL org.opencontainers.image.source=$GITHUB_REPOSITORY
LABEL org.opencontainers.image.licenses=MIT


# Basic cleanup & install runtime packages: dumb-init only
RUN apt-get update && \
    apt-get install -y --no-install-recommends dumb-init bash && \
    apt-get purge -y --auto-remove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Re-declare runtime envs
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    GUNICORN_WORKERS=3 \
    LISTEN_PORT=8080 \
    PYTHONPATH=./ \
    GUNICORN_APP=main:app \
    FORCE_COLOR=1

WORKDIR /app

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv

# Copy application source (owned by root for now, will chown below)
COPY --from=builder /app /app


# Create non-root user and runtime directories, set ownership
RUN groupadd -r appgroup && useradd -r -g appgroup -m -d /nonexistent -s /sbin/nologin appuser \
    && mkdir -p /run/gunicorn \
    && chown -R appuser:appgroup /run/gunicorn /app


# Copy entrypoint script that starts Gunicorn/Uvicorn and handles signals.
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh


# Ensure runtime dirs exist and are writable by appuser (run as root)
RUN mkdir -p /run/gunicorn \
    && chown -R appuser:appgroup /run/gunicorn /app

# Switch to non-root user
USER appuser

# Use dumb-init as PID 1 via entrypoint to handle reaping & signals
ENTRYPOINT ["/usr/bin/dumb-init", "--", "/usr/local/bin/docker-entrypoint.sh"]

# No CMD here because the entrypoint will start Gunicorn/Uvicorn.
