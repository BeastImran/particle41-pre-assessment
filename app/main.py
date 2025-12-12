from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError as FastAPIRequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException
from datetime import datetime, timezone
import logging

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger(__name__)

app = FastAPI()

# Optional: Add CORS middleware for production if needed
# app.add_middleware(
#     CORSMiddleware,
#     allow_origins=["*"],
#     allow_credentials=True,
#     allow_methods=["*"],
#     allow_headers=["*"],
# )

@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request, exc):
    logger.error(f"HTTP error: {exc.detail}")
    return JSONResponse(status_code=exc.status_code, content={"error": exc.detail})

@app.exception_handler(FastAPIRequestValidationError)
async def validation_exception_handler(request, exc):
    logger.error(f"Validation error: {exc.errors()}")
    return JSONResponse(status_code=422, content={"error": "Validation error", "details": exc.errors()})

@app.get("/")
async def index(request: Request):
    try:
        client_ip = request.headers.get("x-forwarded-for")
        if client_ip:
            # In case of multiple IPs, take the first one
            client_ip = client_ip.split(",")[0].strip()
        else:
            client_ip = request.client.host if request.client else "unknown"
        timestamp = datetime.now(timezone.utc).isoformat()
        logger.info(f"Request from IP: {client_ip} at {timestamp}")
        return JSONResponse({
            "timestamp": timestamp,
            "ip": client_ip
        })
    except Exception as e:
        logger.exception("Unhandled error in index endpoint")
        raise HTTPException(status_code=500, detail="Internal server error")
