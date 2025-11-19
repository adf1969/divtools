"""
Database connection and session management
Last Updated: 11/14/2025 12:00:00 PM CDT

Handles SQLAlchemy engine creation and session management for dthostmon.
"""

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import QueuePool
from contextlib import contextmanager
from typing import Generator
import logging

from .database import Base

logger = logging.getLogger(__name__)


class DatabaseManager:
    """Manages database connections and sessions"""
    
    def __init__(self, db_url: str, echo: bool = False):
        """
        Initialize database manager
        
        Args:
            db_url: PostgreSQL connection URL (format: postgresql://user:pass@host:port/dbname)
            echo: Enable SQLAlchemy query logging
        """
        self.engine = create_engine(
            db_url,
            poolclass=QueuePool,
            pool_size=5,
            max_overflow=10,
            pool_pre_ping=True,  # Verify connections before using
            echo=echo
        )
        self.SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=self.engine)
        logger.info(f"Database engine created: {db_url.split('@')[1] if '@' in db_url else 'local'}")
    
    def create_tables(self):
        """Create all database tables if they don't exist"""
        Base.metadata.create_all(bind=self.engine)
        logger.info("Database tables created/verified")
    
    def drop_tables(self):
        """Drop all database tables (use with caution!)"""
        Base.metadata.drop_all(bind=self.engine)
        logger.warning("All database tables dropped")
    
    @contextmanager
    def get_session(self) -> Generator[Session, None, None]:
        """
        Context manager for database sessions
        
        Usage:
            with db_manager.get_session() as session:
                session.query(Host).all()
        """
        session = self.SessionLocal()
        try:
            yield session
            session.commit()
        except Exception as e:
            session.rollback()
            logger.error(f"Database session error: {e}")
            raise
        finally:
            session.close()
    
    def get_session_direct(self) -> Session:
        """Get a session directly (caller must manage commit/rollback/close)"""
        return self.SessionLocal()
    
    def health_check(self) -> bool:
        """
        Verify database connectivity
        
        Returns:
            True if database is reachable and responsive
        """
        try:
            with self.get_session() as session:
                session.execute("SELECT 1")
            logger.debug("Database health check: OK")
            return True
        except Exception as e:
            logger.error(f"Database health check failed: {e}")
            return False


def build_db_url(host: str, port: int, dbname: str, user: str, password: str) -> str:
    """
    Build PostgreSQL connection URL
    
    Args:
        host: Database hostname
        port: Database port
        dbname: Database name
        user: Database user
        password: Database password
    
    Returns:
        PostgreSQL connection URL string
    """
    return f"postgresql://{user}:{password}@{host}:{port}/{dbname}"
