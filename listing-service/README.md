# Listing Service

Microservice for managing property listings in the Plot Listing platform.

## Features

- ✅ Create new property listings
- ✅ Retrieve all listings with pagination
- ✅ PostgreSQL database integration
- ✅ Health check endpoint for Kubernetes
- ✅ Dockerized for easy deployment

## API Endpoints

### 1. Health Check
```
GET /health
```
Returns service health status.

### 2. Create Listing
```
POST /listings
Content-Type: application/json

{
  "plot_id": "PLOT001",
  "title": "Luxury Villa in Colombo",
  "location": "Colombo 07",
  "category": "Sale",
  "price": 50000000.00,
  "available": true
}
```

### 3. Get All Listings
```
GET /listings?skip=0&limit=100
```

### 4. API Documentation
```
GET /docs  (Swagger UI)
GET /redoc (ReDoc)
```

## Local Development

### Prerequisites
- Python 3.11+
- PostgreSQL 14+

### Setup

1. **Install dependencies:**
```bash
pip install -r requirements.txt
```

2. **Set up PostgreSQL:**
```bash
# Create database and user
sudo -u postgres psql
CREATE DATABASE listings_db;
CREATE USER plotuser WITH PASSWORD 'plotpass';
GRANT ALL PRIVILEGES ON DATABASE listings_db TO plotuser;
\q
```

3. **Set environment variable:**
```bash
export DATABASE_URL="postgresql://plotuser:plotpass@localhost:5432/listings_db"
```

4. **Run the service:**
```bash
uvicorn main:app --reload --port 8000
```

5. **Test the API:**
```bash
# Health check
curl http://localhost:8000/health

# Create a listing
curl -X POST http://localhost:8000/listings \
  -H "Content-Type: application/json" \
  -d '{
    "plot_id": "PLOT001",
    "title": "Luxury Villa",
    "location": "Colombo 07",
    "category": "Sale",
    "price": 50000000,
    "available": true
  }'

# Get all listings
curl http://localhost:8000/listings
```

## Docker

### Build Image
```bash
docker build -t listing-service:latest .
```

### Run Container
```bash
docker run -d \
  --name listing-service \
  -p 8000:8000 \
  -e DATABASE_URL="postgresql://plotuser:plotpass@host.docker.internal:5432/listings_db" \
  listing-service:latest
```

## Database Schema

**Table: listings**

| Column | Type | Description |
|--------|------|-------------|
| plot_id | VARCHAR (PK) | Unique plot identifier |
| title | VARCHAR | Property title |
| location | VARCHAR | Property location |
| category | VARCHAR | Sale or Rent |
| price | FLOAT | Property price |
| available | BOOLEAN | Availability status |
| created_at | TIMESTAMP | Creation timestamp |
| updated_at | TIMESTAMP | Last update timestamp |

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| DATABASE_URL | PostgreSQL connection string | postgresql://plotuser:plotpass@localhost:5432/listings_db |

## Next Steps

- Deploy to Kubernetes (see k8s/ directory)
- Set up CI/CD pipeline
- Add integration tests
