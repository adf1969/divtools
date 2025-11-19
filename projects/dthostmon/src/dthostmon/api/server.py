"""
REST API server for dthostmon
Last Updated: 11/14/2025 12:00:00 PM CDT

FastAPI server exposing read-only endpoints for monitoring results.
"""

from fastapi import FastAPI, HTTPException, Depends, Security
from fastapi.security import APIKeyHeader
from typing import List, Optional
from datetime import datetime, timedelta
from pydantic import BaseModel
import logging

from ..models.database import Host, MonitoringRun, DetectedChange, LogEntry
from ..models import DatabaseManager

logger = logging.getLogger(__name__)

# API Key security
api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)


class HealthResponse(BaseModel):
    """Health check response"""
    status: str
    database: str
    timestamp: str


class HostResponse(BaseModel):
    """Host information response"""
    id: int
    name: str
    hostname: str
    enabled: bool
    last_seen: Optional[str]
    tags: List[str]


class MonitoringRunResponse(BaseModel):
    """Monitoring run response"""
    id: int
    host_name: str
    run_date: str
    status: str
    health_score: Optional[int]
    anomalies_detected: int
    changes_detected: int
    alert_level: str
    execution_time: float


class ChangeResponse(BaseModel):
    """Detected change response"""
    id: int
    change_type: str
    severity: str
    description: str
    detected_at: str


class HostRegistrationRequest(BaseModel):
    """Host self-registration request"""
    name: str
    hostname: str
    port: int = 22
    user: str = "monitoring"
    site: Optional[str] = None
    tags: List[str] = []
    enabled: bool = True


class HostRegistrationResponse(BaseModel):
    """Host registration response"""
    id: int
    name: str
    hostname: str
    status: str
    message: str


def create_app(db_manager: DatabaseManager, api_key: str) -> FastAPI:
    """
    Create FastAPI application
    
    Args:
        db_manager: Database manager instance
        api_key: API key for authentication
    
    Returns:
        Configured FastAPI app
    """
    app = FastAPI(
        title="dthostmon API",
        description="System monitoring and analysis API",
        version="1.0.0"
    )
    
    def verify_api_key(api_key_value: str = Security(api_key_header)):
        """Verify API key"""
        if api_key_value != api_key:
            raise HTTPException(status_code=403, detail="Invalid API key")
        return api_key_value
    
    @app.get("/health", response_model=HealthResponse, tags=["Health"])
    async def health_check():
        """Health check endpoint"""
        db_healthy = db_manager.health_check()
        
        return HealthResponse(
            status="healthy" if db_healthy else "degraded",
            database="connected" if db_healthy else "disconnected",
            timestamp=datetime.utcnow().isoformat()
        )
    
    @app.get("/hosts", response_model=List[HostResponse], tags=["Hosts"])
    async def list_hosts(api_key_value: str = Depends(verify_api_key)):
        """List all monitored hosts"""
        with db_manager.get_session() as session:
            hosts = session.query(Host).filter(Host.enabled == True).all()
            
            return [
                HostResponse(
                    id=host.id,
                    name=host.name,
                    hostname=host.hostname,
                    enabled=host.enabled,
                    last_seen=host.last_seen.isoformat() if host.last_seen else None,
                    tags=host.tags or []
                )
                for host in hosts
            ]
    
    @app.get("/hosts/{host_id}", response_model=HostResponse, tags=["Hosts"])
    async def get_host(host_id: int, api_key_value: str = Depends(verify_api_key)):
        """Get specific host information"""
        with db_manager.get_session() as session:
            host = session.query(Host).filter(Host.id == host_id).first()
            
            if not host:
                raise HTTPException(status_code=404, detail="Host not found")
            
            return HostResponse(
                id=host.id,
                name=host.name,
                hostname=host.hostname,
                enabled=host.enabled,
                last_seen=host.last_seen.isoformat() if host.last_seen else None,
                tags=host.tags or []
            )
    
    @app.get("/results/{host_id}", response_model=List[MonitoringRunResponse], tags=["Results"])
    async def get_monitoring_results(
        host_id: int,
        limit: int = 10,
        api_key_value: str = Depends(verify_api_key)
    ):
        """Get monitoring results for a host"""
        with db_manager.get_session() as session:
            # Verify host exists
            host = session.query(Host).filter(Host.id == host_id).first()
            if not host:
                raise HTTPException(status_code=404, detail="Host not found")
            
            # Get monitoring runs
            runs = (
                session.query(MonitoringRun)
                .filter(MonitoringRun.host_id == host_id)
                .order_by(MonitoringRun.run_date.desc())
                .limit(limit)
                .all()
            )
            
            return [
                MonitoringRunResponse(
                    id=run.id,
                    host_name=host.name,
                    run_date=run.run_date.isoformat(),
                    status=run.status,
                    health_score=run.health_score,
                    anomalies_detected=run.anomalies_detected,
                    changes_detected=run.changes_detected,
                    alert_level=run.alert_level or "INFO",
                    execution_time=run.execution_time or 0.0
                )
                for run in runs
            ]
    
    @app.get("/results/{host_id}/latest", response_model=MonitoringRunResponse, tags=["Results"])
    async def get_latest_result(host_id: int, api_key_value: str = Depends(verify_api_key)):
        """Get latest monitoring result for a host"""
        with db_manager.get_session() as session:
            host = session.query(Host).filter(Host.id == host_id).first()
            if not host:
                raise HTTPException(status_code=404, detail="Host not found")
            
            run = (
                session.query(MonitoringRun)
                .filter(MonitoringRun.host_id == host_id)
                .order_by(MonitoringRun.run_date.desc())
                .first()
            )
            
            if not run:
                raise HTTPException(status_code=404, detail="No monitoring results found")
            
            return MonitoringRunResponse(
                id=run.id,
                host_name=host.name,
                run_date=run.run_date.isoformat(),
                status=run.status,
                health_score=run.health_score,
                anomalies_detected=run.anomalies_detected,
                changes_detected=run.changes_detected,
                alert_level=run.alert_level or "INFO",
                execution_time=run.execution_time or 0.0
            )
    
    @app.get("/changes/{run_id}", response_model=List[ChangeResponse], tags=["Changes"])
    async def get_changes(run_id: int, api_key_value: str = Depends(verify_api_key)):
        """Get detected changes for a monitoring run"""
        with db_manager.get_session() as session:
            run = session.query(MonitoringRun).filter(MonitoringRun.id == run_id).first()
            if not run:
                raise HTTPException(status_code=404, detail="Monitoring run not found")
            
            changes = (
                session.query(DetectedChange)
                .filter(DetectedChange.monitoring_run_id == run_id)
                .order_by(DetectedChange.detected_at.desc())
                .all()
            )
            
            return [
                ChangeResponse(
                    id=change.id,
                    change_type=change.change_type,
                    severity=change.severity,
                    description=change.description,
                    detected_at=change.detected_at.isoformat()
                )
                for change in changes
            ]
    
    @app.get("/logs/{run_id}", tags=["Logs"])
    async def get_logs(run_id: int, api_key_value: str = Depends(verify_api_key)):
        """Get log entries for a monitoring run"""
        with db_manager.get_session() as session:
            run = session.query(MonitoringRun).filter(MonitoringRun.id == run_id).first()
            if not run:
                raise HTTPException(status_code=404, detail="Monitoring run not found")
            
            logs = (
                session.query(LogEntry)
                .filter(LogEntry.monitoring_run_id == run_id)
                .all()
            )
            
            return [
                {
                    "id": log.id,
                    "path": log.log_file_path,
                    "line_count": log.line_count,
                    "file_size": log.file_size,
                    "hash": log.content_hash,
                    "retrieved_at": log.retrieved_at.isoformat()
                }
                for log in logs
            ]
    
    @app.get("/history/{host_id}", tags=["History"])
    async def get_history(
        host_id: int,
        days: int = 7,
        api_key_value: str = Depends(verify_api_key)
    ):
        """Get monitoring history for a host"""
        with db_manager.get_session() as session:
            host = session.query(Host).filter(Host.id == host_id).first()
            if not host:
                raise HTTPException(status_code=404, detail="Host not found")
            
            cutoff_date = datetime.utcnow() - timedelta(days=days)
            
            runs = (
                session.query(MonitoringRun)
                .filter(
                    MonitoringRun.host_id == host_id,
                    MonitoringRun.run_date >= cutoff_date
                )
                .order_by(MonitoringRun.run_date.asc())
                .all()
            )
            
            return {
                "host_id": host_id,
                "host_name": host.name,
                "period_days": days,
                "total_runs": len(runs),
                "runs": [
                    {
                        "run_date": run.run_date.isoformat(),
                        "health_score": run.health_score,
                        "status": run.status,
                        "anomalies": run.anomalies_detected,
                        "changes": run.changes_detected
                    }
                    for run in runs
                ]
            }
    
    @app.post("/hosts/register", response_model=HostRegistrationResponse, tags=["Hosts"])
    async def register_host(
        registration: HostRegistrationRequest,
        api_key_value: str = Depends(verify_api_key)
    ):
        """
        Register a new host for monitoring (self-registration endpoint)
        
        This endpoint allows remote hosts to self-register in the monitoring system.
        Implements FR-CONFIG-002 requirement.
        """
        with db_manager.get_session() as session:
            # Check if host already exists
            existing_host = session.query(Host).filter(
                (Host.name == registration.name) | (Host.hostname == registration.hostname)
            ).first()
            
            if existing_host:
                logger.warning(f"Host registration attempt for existing host: {registration.name}")
                return HostRegistrationResponse(
                    id=existing_host.id,
                    name=existing_host.name,
                    hostname=existing_host.hostname,
                    status="already_exists",
                    message=f"Host {registration.name} is already registered (ID: {existing_host.id})"
                )
            
            # Create new host
            new_host = Host(
                name=registration.name,
                hostname=registration.hostname,
                port=registration.port,
                user=registration.user,
                site=registration.site,
                tags=registration.tags if registration.tags else [],
                enabled=registration.enabled,
                created_at=datetime.utcnow(),
                updated_at=datetime.utcnow()
            )
            
            session.add(new_host)
            session.commit()
            session.refresh(new_host)
            
            logger.info(f"New host registered: {registration.name} (ID: {new_host.id})")
            
            return HostRegistrationResponse(
                id=new_host.id,
                name=new_host.name,
                hostname=new_host.hostname,
                status="registered",
                message=f"Host {registration.name} successfully registered for monitoring"
            )
    
    logger.info("FastAPI application initialized")
    return app
