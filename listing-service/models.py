"""
Database models for Listing Service
"""
from sqlalchemy import Column, String, Float, Boolean, DateTime
from sqlalchemy.sql import func
from database import Base


class Listing(Base):
    """
    Listing model representing a property/plot listing
    
    Attributes:
        plot_id: Unique identifier for the plot (Primary Key)
        title: Title/name of the property
        location: Location/address of the property
        category: Category - either 'Sale' or 'Rent'
        price: Price of the property
        available: Availability status (default: True)
        created_at: Timestamp when listing was created
        updated_at: Timestamp when listing was last updated
    """
    __tablename__ = "listings"

    plot_id = Column(String, primary_key=True, index=True)
    title = Column(String, nullable=False)
    location = Column(String, nullable=False)
    category = Column(String, nullable=False)  # 'Sale' or 'Rent'
    price = Column(Float, nullable=False)
    available = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    def to_dict(self):
        """Convert model to dictionary"""
        return {
            "plot_id": self.plot_id,
            "title": self.title,
            "location": self.location,
            "category": self.category,
            "price": self.price,
            "available": self.available,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }
