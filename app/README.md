# Python Async HTTP App (FastAPI)

This app returns a JSON response with the current UTC timestamp and the visitor's IP address. It is optimized for high concurrency and production use.

## Features
- **Async**: Built with FastAPI for high concurrency.
- **Logging**: All requests and errors are logged with timestamps and details.
- **Error Handling**: Graceful error responses for HTTP and validation errors.

## Usage (Development)

1. Install dependencies:
   
   ```bash
   pip install -r requirements.txt
   ```

2. Run the app (development):
   
   ```bash
   uvicorn main:app --reload --host 0.0.0.0 --port 8000
   ```

## Usage (Production)

For production, use multiple workers:

```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4
```

You can adjust the number of workers based on your server's CPU cores.


## Docker Usage

The provided Dockerfile is multi-stage and optimized for production:
- Build dependencies are only present during build, not in the final image.
- Cleans up package manager and pip cache to minimize image size.
- Runs as a non-root user for security.

Build and run the app with Docker:

```bash
docker build -t fastapi-ip-timestamp .
docker run -d -p 8000:8000 --name fastapi-ip-timestamp fastapi-ip-timestamp
```

You can inspect the image size with:

```bash
docker images fastapi-ip-timestamp
```

## Response Example

```
{
  "timestamp": "2025-12-12T12:34:56.789+00:00",
  "ip": "127.0.0.1"
}
```

## Notes
- The timestamp is in UTC and ISO 8601 format.
- The app uses FastAPI and Uvicorn for async, high-performance serving.
- For best performance, use a reverse proxy (e.g., Nginx) in front of Uvicorn in production.
- Logging and error handling are enabled by default.
