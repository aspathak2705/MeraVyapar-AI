import logging
import sys
from app.core.config import settings


def setup_logging() -> None:
    logging_level = getattr(logging, settings.LOG_LEVEL.upper(), logging.INFO)

    log_format = "%(asctime)s - [%(levelname)s] - [request_id=%(request_id)s] - %(name)s - %(message)s"

    class RequestIdFilter(logging.Filter):
        def filter(self, record):
            if not hasattr(record, "request_id"):
                record.request_id = "N/A"
            return True

    logger = logging.getLogger()
    logger.setLevel(logging_level)

    handler = logging.StreamHandler(sys.stdout)
    handler.setLevel(logging_level)
    handler.addFilter(RequestIdFilter())
    formatter = logging.Formatter(log_format)
    handler.setFormatter(formatter)

    # Avoid duplicate handlers
    if not logger.handlers:
        logger.addHandler(handler)


logger = logging.getLogger("meravyapar")
