"""
Database models for Inquiry Service
"""
from sqlalchemy import Column, String, Integer, DateTime
from sqlalchemy.sql import func
from database import Base


class Inquiry(Base):
    """
    Inquiry model for customer inquiries about properties
    
    Attributes:
        id: Auto-increment primary key
        plot_id: Reference to the property/plot
        name: Customer name
        email: Customer email
        phone: Customer phone number
        message: Inquiry message
        created_at: Timestamp when inquiry was created
    """
    __tablename__ = "inquiries"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    plot_id = Column(String, nullable=False, index=True)
    name = Column(String, nullable=False)
    email = Column(String, nullable=False)
    phone = Column(String, nullable=False)
    message = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    def to_dict(self):
        """Convert model to dictionary"""
        return {
            "id": self.id,
            "plot_id": self.plot_id,
            "name": self.name,
            "email": self.email,
            "phone": self.phone,
            "message": self.message,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
