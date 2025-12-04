"""
Listing Service - Microservice for managing property listings

This service provides APIs to:
- Create new property listings
- Retrieve all listings
- Health check endpoint

Database: PostgreSQL
"""
from fastapi import FastAPI, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
import logging

from database import engine, get_db, Base
from models import Listing
from schemas import ListingCreate, ListingResponse

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Create FastAPI app
app = FastAPI(
    title="Listing Service",
    description="Microservice for managing property listings",
    version="1.0.0"
)

# Create database tables
Base.metadata.create_all(bind=engine)
logger.info("Database tables created successfully")


@app.get("/health", tags=["Health"])
def health_check():
    """
    Health check endpoint for Kubernetes liveness/readiness probes
    """
    return {
        "status": "healthy",
        "service": "listing-service",
        "version": "1.0.0"
    }


@app.post(
    "/listings",
    response_model=ListingResponse,
    status_code=status.HTTP_201_CREATED,
    tags=["Listings"]
)
def create_listing(
    listing_data: ListingCreate,
    db: Session = Depends(get_db)
):
    """
    Create a new property listing
    
    Args:
        listing_data: Listing details (plot_id, title, location, category, price, available)
        db: Database session
    
    Returns:
        Created listing with timestamps
    
    Raises:
        HTTPException: If plot_id already exists
    """
    # Check if plot_id already exists
    existing = db.query(Listing).filter(Listing.plot_id == listing_data.plot_id).first()
    if existing:
        logger.warning(f"Duplicate plot_id attempted: {listing_data.plot_id}")
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Listing with plot_id '{listing_data.plot_id}' already exists"
        )
    
    # Create new listing
    new_listing = Listing(**listing_data.model_dump())
    
    try:
        db.add(new_listing)
        db.commit()
        db.refresh(new_listing)
        logger.info(f"Created listing: {new_listing.plot_id}")
        return new_listing
    except Exception as e:
        db.rollback()
        logger.error(f"Error creating listing: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create listing"
        )


@app.get(
    "/listings",
    response_model=List[ListingResponse],
    tags=["Listings"]
)
def get_all_listings(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db)
):
    """
    Retrieve all property listings with pagination
    
    Args:
        skip: Number of records to skip (default: 0)
        limit: Maximum number of records to return (default: 100)
        db: Database session
    
    Returns:
        List of all listings
    """
    try:
        listings = db.query(Listing).offset(skip).limit(limit).all()
        logger.info(f"Retrieved {len(listings)} listings")
        return listings
    except Exception as e:
        logger.error(f"Error retrieving listings: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve listings"
        )


@app.get("/", tags=["Root"])
def root():
    """
    Root endpoint with service information
    """
    return {
        "service": "Listing Service",
        "version": "1.0.0",
        "endpoints": {
            "health": "/health",
            "create_listing": "POST /listings",
            "get_listings": "GET /listings",
            "docs": "/docs"
        }
    }
