import uuid
from datetime import datetime, timezone
from sqlalchemy import (
    Column,
    String,
    Integer,
    Float,
    DateTime,
    ForeignKey,
    JSON,
    Index,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from db.session import Base


class WorkloadForecastSnapshot(Base):
    """
    Stores time-series workload prediction snapshots for capacity planning.
    """
    __tablename__ = "workload_forecast_snapshots"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    forecast_date = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    horizon_days = Column(Integer, nullable=False, default=7)  # 7 or 30 days
    predicted_total_cases = Column(Integer, nullable=False)
    predicted_p1_cases = Column(Integer, nullable=False, default=0)
    predicted_p2_cases = Column(Integer, nullable=False, default=0)
    predicted_p3_p4_cases = Column(Integer, nullable=False, default=0)
    category_breakdown = Column(JSON, nullable=False, default=dict)
    confidence_interval = Column(JSON, nullable=False, default=dict)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)

    __table_args__ = (
        Index("ix_workload_forecast_date_horizon", "forecast_date", "horizon_days"),
    )


class TeamCapacitySnapshot(Base):
    """
    Tracks team-level workload capacity, operator load, and burnout risk index.
    """
    __tablename__ = "team_capacity_snapshots"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    team_id = Column(UUID(as_uuid=True), ForeignKey("teams.id", ondelete="CASCADE"), nullable=False, index=True)
    active_operator_count = Column(Integer, nullable=False, default=1)
    open_cases_count = Column(Integer, nullable=False, default=0)
    avg_cases_per_operator = Column(Float, nullable=False, default=0.0)
    capacity_utilization_pct = Column(Float, nullable=False, default=0.0)
    burnout_risk = Column(String(50), nullable=False, default="low")  # low, moderate, high, critical
    estimated_closure_velocity_per_day = Column(Float, nullable=False, default=5.0)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)

    team = relationship("Team", foreign_keys=[team_id], lazy="joined")
