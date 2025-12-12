
# Python Async HTTP App – Architecture, CI/CD, and Deployment

This application provides a high-performance HTTP API that returns the current UTC timestamp and the visitor's IP address. It is designed for scalability, security, and production-readiness.

---

## Architecture Overview

**Core Components:**

- **FastAPI**: Handles async HTTP requests and business logic.
- **Uvicorn (Gunicorn Worker)**: Serves the FastAPI app using an ASGI server for high concurrency.
- **Nginx**: Acts as a reverse proxy, handling incoming HTTP traffic, static files, and forwarding requests to the Uvicorn server via a Unix socket.
- **Docker**: Multi-stage build creates a minimal, secure, and reproducible container image.
- **GitHub Actions**: Automated CI/CD pipeline for quality, security, and deployment.

**Containerized Flow:**

1. **Nginx** listens on port 8080 and proxies requests to Uvicorn via a Unix domain socket for optimal performance.
2. **Uvicorn (via Gunicorn worker)** runs the FastAPI app, handling async requests efficiently.
3. **Entrypoint script** supervises both Nginx and Gunicorn/Uvicorn, ensuring graceful startup and shutdown.
4. **Non-root user**: The app runs as a non-root user for enhanced security.

---

## Development Usage

1. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```
2. **Run the app (development mode):**
   ```bash
   uvicorn main:app --reload --host 0.0.0.0 --port 8000
   ```

---

## Production Usage

For production, use multiple workers for concurrency:

```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4
```

---

## Dockerized Deployment

The provided Dockerfile implements a **multi-stage build** for security and efficiency:

- **Builder stage**: Installs build dependencies and Python packages in a virtual environment.
- **Final stage**: Copies only the virtual environment and app code, installs only runtime packages (Nginx, dumb-init), and removes build tools.
- **Non-root user**: The container runs as a dedicated non-root user (`appuser`).
- **Nginx reverse proxy**: Handles HTTP traffic and proxies to Uvicorn via a Unix socket.
- **Entrypoint script**: Supervises Nginx and Gunicorn/Uvicorn, manages signals, and ensures graceful shutdown.
- **Minimal image size**: Cleans up caches and unnecessary files.

**Build and run the app with Docker:**

```bash
docker build -t fastapi-ip-timestamp .
docker run -d -p 8080:8080 --name fastapi-ip-timestamp fastapi-ip-timestamp
```

**Inspect the image size:**

```bash
docker images fastapi-ip-timestamp
```

---

## Continuous Integration & Deployment (CI/CD)

This project uses **GitHub Actions** for a robust, automated CI/CD pipeline:

- **Lint & Style**: Runs `ruff` and `black` to enforce code quality and formatting.
- **Unit Tests**: Executes all tests with `pytest` (with coverage) across multiple Python versions (3.11–3.14).
- **Secret Scanning**: Uses `gitleaks` to detect accidental secrets in code or history.
- **Docker Build & Publish**: Builds and pushes a multi-architecture Docker image to GitHub Container Registry (GHCR) on every push to `main` or version tag.
- **Artifact Uploads**: Test reports, coverage, and scan results are uploaded for traceability.

**Pipeline Triggers:**
- Runs on every pull request and push to `main` or version tag.
- Ensures code is always production-ready.

> See `.github/workflows/app-ci-cd.yml` for full workflow details.

---

## Example API Response

```
{
  "timestamp": "2025-12-12T12:34:56.789+00:00",
  "ip": "127.0.0.1"
}
```

---

## Notes

- Timestamp is in UTC, ISO 8601 format.
- For best performance, use the provided Docker/Nginx setup in production.
- Logging, error handling, and CI/CD are enabled by default.
- The app is designed for high concurrency and security.
