"""
Pydantic schemas for request/response validation
"""
from pydantic import BaseModel, Field, ConfigDict, EmailStr
from typing import Optional
from datetime import datetime


class InquiryCreate(BaseModel):
    """Schema for creating a new inquiry"""
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "plot_id": "PLOT001",
                "name": "John Doe",
                "email": "john@example.com",
                "phone": "+94771234567",
                "message": "I'm interested in this property. Please contact me."
            }
        }
    )
    
    plot_id: str = Field(..., description="Plot ID being inquired about")
    name: str = Field(..., min_length=1, description="Customer name")
    email: str = Field(..., description="Customer email")
    phone: str = Field(..., min_length=1, description="Customer phone")
    message: str = Field(..., min_length=1, description="Inquiry message")


class InquiryResponse(BaseModel):
    """Schema for inquiry response"""
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    plot_id: str
    name: str
    email: str
    phone: str
    message: str
    created_at: Optional[datetime] = None
