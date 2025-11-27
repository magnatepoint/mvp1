from datetime import datetime
from pydantic import BaseModel


class GmailJobStatus(BaseModel):
    job_id: str
    status: str
    progress: int
    error: str | None = None
    created_at: datetime
    updated_at: datetime


