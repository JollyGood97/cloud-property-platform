"""
Tests for Inquiry Service
"""
import pytest
import os
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from main import app
from database import Base, get_db

# Use file-based SQLite for testing but delete it first
TEST_DB = "test_inquiries_temp.db"
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


def test_create_inquiry():
    """Test creating a new inquiry"""
    inquiry_data = {
        "plot_id": "PLOT001",
        "name": "John Doe",
        "email": "john@example.com",
        "phone": "+94771234567",
        "message": "I'm interested in this property."
    }
    
    response = client.post("/inquiries", json=inquiry_data)
    assert response.status_code == 201
    data = response.json()
    assert data["plot_id"] == "PLOT001"
    assert data["name"] == "John Doe"
    assert "id" in data


def test_get_inquiries():
    """Test retrieving all inquiries"""
    response = client.get("/inquiries")
    assert response.status_code == 200
    assert isinstance(response.json(), list)


def test_filter_by_plot_id():
    """Test filtering inquiries by plot_id"""
    # Create inquiry for specific plot
    inquiry_data = {
        "plot_id": "PLOT999",
        "name": "Jane Smith",
        "email": "jane@example.com",
        "phone": "+94771234568",
        "message": "Test inquiry"
    }
    client.post("/inquiries", json=inquiry_data)
    
    # Filter by plot_id
    response = client.get("/inquiries?plot_id=PLOT999")
    assert response.status_code == 200
    data = response.json()
    assert len(data) > 0
    assert all(item["plot_id"] == "PLOT999" for item in data)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
