#!/usr/bin/env bash
set -euo pipefail

#############################################
# Logging Helpers
#############################################

COLOR_GREEN="\033[1;32m"
COLOR_YELLOW="\033[1;33m"
COLOR_RED="\033[1;31m"
COLOR_CYAN="\033[1;36m"
COLOR_RESET="\033[0m"

LOG_TIME() { date +"%Y-%m-%d %H:%M:%S"; }

log_info()  { echo -e "${FORCE_COLOR:+$COLOR_GREEN}[$(LOG_TIME)] [INFO]${FORCE_COLOR:+$COLOR_RESET}  $*"; }
log_warn()  { echo -e "${FORCE_COLOR:+$COLOR_YELLOW}[$(LOG_TIME)] [WARN]${FORCE_COLOR:+$COLOR_RESET}  $*"; }
log_error() { echo -e "${FORCE_COLOR:+$COLOR_RED}[$(LOG_TIME)] [ERROR]${FORCE_COLOR:+$COLOR_RESET} $*" >&2; }
log_debug() { echo -e "${FORCE_COLOR:+$COLOR_CYAN}[$(LOG_TIME)] [DEBUG]${FORCE_COLOR:+$COLOR_RESET} $*"; }


#############################################
# Environment Defaults
#############################################
GUNICORN_BIND=${GUNICORN_BIND:-unix:/run/gunicorn/gunicorn.sock}
GUNICORN_WORKERS=${GUNICORN_WORKERS:-3}
GUNICORN_THREADS=${GUNICORN_THREADS:-4}


#############################################
# Setup Runtime Directories
#############################################
log_info "Preparing runtime directories..."

mkdir -p /run/gunicorn || log_warn "Could not create /run/gunicorn"
mkdir -p /var/log/nginx /var/lib/nginx || true

chown -R "$(id -u):$(id -g)" /run/gunicorn /var/log/nginx || true

log_debug "Using socket: $GUNICORN_BIND"
log_debug "Gunicorn workers: $GUNICORN_WORKERS, threads: $GUNICORN_THREADS"


#############################################
# Start Gunicorn
#############################################
start_gunicorn() {
    log_info "Starting Gunicorn (Uvicorn worker) → ${GUNICORN_APP}"

    gunicorn \
        --chdir /app \
        --bind "${GUNICORN_BIND}" \
        --workers "${GUNICORN_WORKERS}" \
        --worker-class uvicorn.workers.UvicornWorker \
        --timeout 30 \
        --log-level info \
        --access-logfile - \
        --error-logfile - \
        --pid /run/gunicorn/gunicorn.pid \
        "${GUNICORN_APP}" &

    GUNICORN_PID=$!
    log_info "Gunicorn (UvicornWorker) started with PID: ${GUNICORN_PID}"
}


#############################################
# Start Nginx
#############################################
start_nginx() {
    log_info "Starting Nginx reverse proxy..."
    nginx -g "daemon off;" &
    NGINX_PID=$!

    log_info "Nginx started with PID: ${NGINX_PID}"
}


#############################################
# Graceful Shutdown Handler
#############################################
graceful_shutdown() {
    log_warn "Received shutdown signal, stopping services gracefully..."

    if [[ -n "${GUNICORN_PID:-}" ]]; then
        log_info "Stopping Gunicorn (PID ${GUNICORN_PID})..."
        kill -TERM "${GUNICORN_PID}" 2>/dev/null || true
    fi

    if [[ -n "${NGINX_PID:-}" ]]; then
        log_info "Stopping Nginx (PID ${NGINX_PID})..."
        nginx -s quit || kill -TERM "${NGINX_PID}" 2>/dev/null || true
    fi

    log_info "Waiting for processes to exit..."
    wait

    log_info "Shutdown complete."
    exit 0
}


#############################################
# Signal Traps
#############################################
trap graceful_shutdown SIGTERM SIGINT


#############################################
# Start Services
#############################################
start_gunicorn
start_nginx


#############################################
# Process Watcher (supervision)
#############################################
log_info "Entrypoint initialized. Watching child processes..."

# If either Gunicorn or Nginx stops, shutdown gracefully
while true; do
    if ! kill -0 "$GUNICORN_PID" 2>/dev/null; then
        log_error "Gunicorn process exited unexpectedly!"
        graceful_shutdown
    fi

    if ! kill -0 "$NGINX_PID" 2>/dev/null; then
        log_error "Nginx process exited unexpectedly!"
        graceful_shutdown
    fi

    sleep 2
done
