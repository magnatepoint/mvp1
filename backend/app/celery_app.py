from celery import Celery

from app.core.config import get_settings

settings = get_settings()

celery_app = Celery(
    "mvp",
    broker=str(settings.redis_url),
    backend=str(settings.redis_url),
)

celery_app.conf.update(
    task_default_queue="spendsense",
    task_ignore_result=True,
    task_serializer="json",
    result_serializer="json",
    beat_schedule_filename="/app/data/celerybeat-schedule",
    beat_schedule={
        "renew-gmail-watches": {
            "task": "gmail.renew_watches",
            "schedule": 3600.0,  # Run every hour to check for expiring watches
        },
        "retrain-global-ml-model": {
            "task": "spendsense.ml.retrain_global_model",
            "schedule": 86400.0,  # Run daily to retrain global model
        },
        "apply-merchant-feedback": {
            "task": "spendsense.ml.apply_merchant_feedback",
            "schedule": 1800.0,  # Run every 30 minutes
        },
        "train-category-model": {
            "task": "spendsense.ml.train_category_model",
            "schedule": 86400.0,  # Run daily to train category prediction model
        },
    },
)

# Automatically discover task modules inside these packages.
# Celery will look for a "tasks" module in each package.
celery_app.autodiscover_tasks(
    packages=[
        "app.gmail",
        "app.spendsense.etl",
        "app.spendsense.ml",
    ]
)

# Explicitly import watch_renewal to register the gmail.renew_watches task
# This is needed because autodiscover only finds "tasks" modules, not other modules
# Import must happen after autodiscover_tasks for proper registration
import logging
_logger = logging.getLogger(__name__)

try:
    from app.gmail import watch_renewal  # noqa: F401
    # Force registration by accessing the task function
    # The @celery_app.task decorator registers it when the module is imported
    if hasattr(watch_renewal, 'renew_gmail_watches_task'):
        _logger.info("Registered gmail.renew_watches task from watch_renewal module")
        # Explicitly register the task to ensure it's available
        celery_app.tasks.register(watch_renewal.renew_gmail_watches_task)
    else:
        _logger.warning("watch_renewal module imported but renew_gmail_watches_task not found")
except ImportError as e:
    _logger.warning(f"Failed to import gmail.watch_renewal: {e}")
except Exception as e:
    _logger.warning(f"Unexpected error importing gmail.watch_renewal: {e}")

# Ensure gmail tasks are imported for worker discovery
try:
    from app.gmail import tasks  # noqa: F401
    _logger.info("Imported app.gmail.tasks for task discovery")
except ImportError as e:
    _logger.warning(f"Failed to import app.gmail.tasks: {e}")

