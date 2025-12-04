"""
Simple integration tests for Listing Service
Run with: pytest test_main.py -v
"""
import pytest
import os
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from main import app
from database import Base, get_db

# Use file-based SQLite for testing but delete it first
TEST_DB = "test_listings_temp.db"
if os.path.exists(TEST_DB):
    os.remove(TEST_DB)

SQLALCHEMY_DATABASE_URL = f"sqlite:///./{TEST_DB}"
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=None  # Disable connection pooling for SQLite
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Create test database tables
Base.metadata.create_all(bind=engine)


def override_get_db():
    """Override database dependency for testing"""
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db
client = TestClient(app)


@pytest.fixture(scope="session", autouse=True)
def cleanup():
    """Cleanup test database after all tests"""
    yield
    if os.path.exists(TEST_DB):
        os.remove(TEST_DB)


def test_health_check():
    """Test health check endpoint"""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"


def test_create_listing():
    """Test creating a new listing"""
    listing_data = {
        "plot_id": "TEST001",
        "title": "Test Property",
        "location": "Test Location",
        "category": "Sale",
        "price": 1000000.0,
        "available": True
    }
    
    response = client.post("/listings", json=listing_data)
    assert response.status_code == 201
    data = response.json()
    assert data["plot_id"] == "TEST001"
    assert data["title"] == "Test Property"


def test_create_duplicate_listing():
    """Test creating a duplicate listing should fail"""
    listing_data = {
        "plot_id": "TEST002",
        "title": "Test Property 2",
        "location": "Test Location",
        "category": "Rent",
        "price": 50000.0,
        "available": True
    }
    
    # Create first listing
    response1 = client.post("/listings", json=listing_data)
    assert response1.status_code == 201
    
    # Try to create duplicate
    response2 = client.post("/listings", json=listing_data)
    assert response2.status_code == 409  # Conflict


def test_get_listings():
    """Test retrieving all listings"""
    response = client.get("/listings")
    assert response.status_code == 200
    assert isinstance(response.json(), list)
    assert len(response.json()) >= 0


def test_invalid_category():
    """Test creating listing with invalid category"""
    listing_data = {
        "plot_id": "TEST003",
        "title": "Test Property",
        "location": "Test Location",
        "category": "Invalid",  # Should be 'Sale' or 'Rent'
        "price": 1000000.0,
        "available": True
    }
    
    response = client.post("/listings", json=listing_data)
    assert response.status_code == 422  # Validation error


def test_negative_price():
    """Test creating listing with negative price"""
    listing_data = {
        "plot_id": "TEST004",
        "title": "Test Property",
        "location": "Test Location",
        "category": "Sale",
        "price": -1000.0,  # Negative price
        "available": True
    }
    
    response = client.post("/listings", json=listing_data)
    assert response.status_code == 422  # Validation error


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
