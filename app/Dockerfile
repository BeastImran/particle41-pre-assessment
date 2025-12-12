# syntax=docker/dockerfile:1
#
# Multi-stage build:
#  - builder: install build deps & create venv with application dependencies
#  - final: lightweight runtime with python venv + nginx + dumb-init, non-root user
#
# This mirrors the structure you provided while adding a secure nginx reverse-proxy
# in the final image. The container runs nginx (listening on 8080) and the ASGI app
# served by uvicorn via a unix domain socket.

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

# Basic cleanup & install runtime packages: nginx and dumb-init
RUN apt-get update && \
    apt-get install -y --no-install-recommends nginx dumb-init bash && \
    # remove build tools if present (they are not in this stage) and clean apt
    apt-get purge -y --auto-remove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Re-declare runtime envs
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    GUNICORN_WORKERS=3 \
    UDS_PATH=/run/uvicorn/uvicorn.sock \
    LISTEN_PORT=8080 \
    PYTHONPATH=./ \
    GUNICORN_APP=main:app \
    FORCE_COLOR=1

WORKDIR /app

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv

# Copy application source (owned by root for now, will chown below)
COPY --from=builder /app /app

# Create non-root user and socket directories, set ownership
RUN groupadd -r appgroup && useradd -r -g appgroup -m -d /nonexistent -s /sbin/nologin appuser \
    && mkdir -p /run/uvicorn \
    && chown -R appuser:appgroup /run/uvicorn /app /var/lib/nginx /var/log/nginx

# Copy nginx configs (assumes you provide nginx/nginx.conf and nginx/app.conf)
# If you keep different paths, adjust accordingly.
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/app.conf /etc/nginx/conf.d/app.conf

# Copy entrypoint script that starts uvicorn & nginx and handles signals.
# Ensure you create docker-entrypoint.sh in repo root (see earlier example).
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Ensure runtime dirs exist and are writable by appuser (run as root)
# RUN mkdir -p /run/gunicorn /var/run/nginx /var/log/nginx \
#     && chown -R appuser:appgroup /run/gunicorn /var/run/nginx /var/log/nginx /app

RUN mkdir -p /run/gunicorn /var/run/nginx /var/log/nginx /run/nginx \
    && touch /run/nginx/nginx.pid \
    && chown -R appuser:appgroup /run/nginx /var/run/nginx /var/log/nginx /run/gunicorn /app

# Switch to non-root user
USER appuser

# Expose the port nginx will listen on
EXPOSE 8080

# Use dumb-init as PID 1 via entrypoint to handle reaping & signals
ENTRYPOINT ["/usr/bin/dumb-init", "--", "/usr/local/bin/docker-entrypoint.sh"]

# No CMD here because the entrypoint will start processes.
# If you prefer CMD to be explicit, you can set:
# CMD ["nginx", "-g", "daemon off;"]
