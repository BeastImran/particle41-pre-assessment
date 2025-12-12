from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse
from datetime import datetime, timezone
import logging

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger(__name__)

app = FastAPI()


@app.get("/")
async def index(request: Request):
    try:
        # read about the header here
        # https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/X-Forwarded-For
        client_ip = request.headers.get("x-forwarded-for")

        if client_ip:
            # In case of multiple IPs, take the very first one
            client_ip = client_ip.split(",")[0].strip()
        else:
            client_ip = request.client.host if request.client else "unknown"

        timestamp = datetime.now(timezone.utc).isoformat()
        logger.info(f"Request from IP: {client_ip} at {timestamp}")

        return JSONResponse({"timestamp": timestamp, "ip": client_ip})
    except Exception as e:
        logger.exception("Unhandled error in index endpoint, {}".format(e))
        raise HTTPException(status_code=500, detail="Internal server error")
