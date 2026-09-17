import logging
from typing import Optional
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.interval import IntervalTrigger

from core.config import settings
from db.session import AsyncSessionLocal
from services.sweep_service import SweepService
from scheduler.keepalive import ping_self_health

logger = logging.getLogger("helpdesk.scheduler.manager")


async def run_sweep_job() -> None:
    """Scheduled task executing The Sweep iteration."""
    try:
        async with AsyncSessionLocal() as db:
            sweep = SweepService(db)
            await sweep.run_sweep()
    except Exception as exc:
        logger.error(f"Error during scheduled Sweep iteration: {exc}", exc_info=True)


class SweepSchedulerManager:
    """
    In-process scheduler manager utilizing APScheduler AsyncIOScheduler per SRS §3.5.
    Runs strictly within the FastAPI application instance; no external queues required.
    """

    def __init__(self):
        self.scheduler: Optional[AsyncIOScheduler] = None

    def start(self) -> None:
        """Initialize and start the background scheduler."""
        if not settings.ENABLE_SCHEDULER:
            logger.info("Background scheduler is disabled (ENABLE_SCHEDULER=False).")
            return

        if self.scheduler and self.scheduler.running:
            logger.warning("Scheduler is already running.")
            return

        self.scheduler = AsyncIOScheduler()

        # Add The Sweep job
        self.scheduler.add_job(
            run_sweep_job,
            trigger=IntervalTrigger(minutes=settings.SWEEP_INTERVAL_MINUTES),
            id="the_sweep_periodic_job",
            name="The Sweep Periodic SLA & Risk Engine",
            replace_existing=True,
            max_instances=1,
            coalesce=True,
        )
        logger.info(f"The Sweep scheduled every {settings.SWEEP_INTERVAL_MINUTES} minutes.")

        # Add Keepalive ping job if enabled per SRS §3.1
        if settings.ENABLE_KEEPALIVE_PING:
            self.scheduler.add_job(
                ping_self_health,
                trigger=IntervalTrigger(minutes=settings.KEEPALIVE_PING_INTERVAL_MINUTES),
                id="render_keepalive_ping_job",
                name="Render Free-Tier Keepalive Pinger",
                replace_existing=True,
                max_instances=1,
                coalesce=True,
            )
            logger.info(f"Keepalive pinger scheduled every {settings.KEEPALIVE_PING_INTERVAL_MINUTES} minutes.")

        self.scheduler.start()
        logger.info("SweepSchedulerManager started successfully.")

    def shutdown(self) -> None:
        """Gracefully shut down the scheduler."""
        if self.scheduler and self.scheduler.running:
            logger.info("Shutting down SweepSchedulerManager...")
            self.scheduler.shutdown(wait=False)
            self.scheduler = None
            logger.info("SweepSchedulerManager shut down successfully.")


scheduler_manager = SweepSchedulerManager()
