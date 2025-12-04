"""
Pydantic schemas for request/response validation
"""
from pydantic import BaseModel, Field, ConfigDict
from typing import Optional
from datetime import datetime


class ListingCreate(BaseModel):
    """Schema for creating a new listing"""
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "plot_id": "PLOT001",
                "title": "Luxury Villa in Colombo",
                "location": "Colombo 07",
                "category": "Sale",
                "price": 50000000.00,
                "available": True
            }
        }
    )
    
    plot_id: str = Field(..., description="Unique plot identifier")
    title: str = Field(..., min_length=1, description="Property title")
    location: str = Field(..., min_length=1, description="Property location")
    category: str = Field(..., pattern="^(Sale|Rent)$", description="Category: Sale or Rent")
    price: float = Field(..., gt=0, description="Price must be positive")
    available: bool = Field(default=True, description="Availability status")


class ListingResponse(BaseModel):
    """Schema for listing response"""
    model_config = ConfigDict(from_attributes=True)
    
    plot_id: str
    title: str
    location: str
    category: str
    price: float
    available: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
