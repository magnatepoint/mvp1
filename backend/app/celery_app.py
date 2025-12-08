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

