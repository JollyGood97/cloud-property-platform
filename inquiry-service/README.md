# Inquiry Service

Microservice for managing customer inquiries about properties.

## APIs

- `POST /inquiries` - Create inquiry
- `GET /inquiries` - Get all inquiries (filter by plot_id optional)
- `GET /health` - Health check

## Quick Start

```bash
# Install dependencies
pip install -r requirements.txt

# Run tests
pytest test_main.py -v

# Start service
uvicorn main:app --reload --port 8001

# Test API
chmod +x test_api.sh
./test_api.sh

# View docs
http://localhost:8001/docs
```

## Database Schema

**Table: inquiries**

| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER (PK) | Auto-increment ID |
| plot_id | VARCHAR | Property being inquired about |
| name | VARCHAR | Customer name |
| email | VARCHAR | Customer email |
| phone | VARCHAR | Customer phone |
| message | VARCHAR | Inquiry message |
| created_at | TIMESTAMP | Creation time |

## Example Request

```bash
curl -X POST http://localhost:8001/inquiries \
  -H "Content-Type: application/json" \
  -d '{
    "plot_id": "PLOT001",
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "+94771234567",
    "message": "I am interested in this property."
  }'
```

## Environment Variables

- `DATABASE_URL` - Database connection (default: SQLite)
