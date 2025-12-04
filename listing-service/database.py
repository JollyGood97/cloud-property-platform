"""
Database configuration and session management
"""
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
import os

# Database URL from environment variable with fallback for local dev
# Default: SQLite (zero setup, perfect for local testing)
# Production: Set DATABASE_URL to PostgreSQL connection string
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "sqlite:///./listings.db"  # Local SQLite file
)

# Create SQLAlchemy engine
# For SQLite, add check_same_thread=False to allow FastAPI async
if DATABASE_URL.startswith("sqlite"):
    engine = create_engine(
        DATABASE_URL,
        connect_args={"check_same_thread": False}
    )
else:
    # PostgreSQL or other databases
    engine = create_engine(DATABASE_URL)

# Create SessionLocal class for database sessions
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base class for models
Base = declarative_base()


def get_db():
    """
    Dependency function to get database session
    Yields a database session and closes it after use
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
