"""
Inquiry Service - Microservice for managing customer inquiries

APIs:
- Create new inquiry
- Retrieve all inquiries
- Health check
"""
from fastapi import FastAPI, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
import logging

from database import engine, get_db, Base
from models import Inquiry
from schemas import InquiryCreate, InquiryResponse

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Create FastAPI app
app = FastAPI(
    title="Inquiry Service",
    description="Microservice for managing customer inquiries",
    version="1.0.0"
)

# Create database tables
Base.metadata.create_all(bind=engine)
logger.info("Database tables created successfully")


@app.get("/health", tags=["Health"])
def health_check():
    """Health check endpoint for Kubernetes"""
    return {
        "status": "healthy",
        "service": "inquiry-service",
        "version": "1.0.0"
    }


@app.post(
    "/inquiries",
    response_model=InquiryResponse,
    status_code=status.HTTP_201_CREATED,
    tags=["Inquiries"]
)
def create_inquiry(
    inquiry_data: InquiryCreate,
    db: Session = Depends(get_db)
):
    """
    Create a new customer inquiry
    
    Args:
        inquiry_data: Inquiry details (plot_id, name, email, phone, message)
        db: Database session
    
    Returns:
        Created inquiry with ID and timestamp
    """
    new_inquiry = Inquiry(**inquiry_data.model_dump())
    
    try:
        db.add(new_inquiry)
        db.commit()
        db.refresh(new_inquiry)
        logger.info(f"Created inquiry #{new_inquiry.id} for plot {new_inquiry.plot_id}")
        return new_inquiry
    except Exception as e:
        db.rollback()
        logger.error(f"Error creating inquiry: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create inquiry"
        )


@app.get(
    "/inquiries",
    response_model=List[InquiryResponse],
    tags=["Inquiries"]
)
def get_all_inquiries(
    skip: int = 0,
    limit: int = 100,
    plot_id: str = None,
    db: Session = Depends(get_db)
):
    """
    Retrieve all inquiries with optional filtering
    
    Args:
        skip: Number of records to skip (default: 0)
        limit: Maximum records to return (default: 100)
        plot_id: Optional filter by plot_id
        db: Database session
    
    Returns:
        List of inquiries
    """
    try:
        query = db.query(Inquiry)
        
        # Filter by plot_id if provided
        if plot_id:
            query = query.filter(Inquiry.plot_id == plot_id)
        
        inquiries = query.offset(skip).limit(limit).all()
        logger.info(f"Retrieved {len(inquiries)} inquiries")
        return inquiries
    except Exception as e:
        logger.error(f"Error retrieving inquiries: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve inquiries"
        )


@app.get("/", tags=["Root"])
def root():
    """Root endpoint with service information"""
    return {
        "service": "Inquiry Service",
        "version": "1.0.0",
        "endpoints": {
            "health": "/health",
            "create_inquiry": "POST /inquiries",
            "get_inquiries": "GET /inquiries",
            "docs": "/docs"
        }
    }
