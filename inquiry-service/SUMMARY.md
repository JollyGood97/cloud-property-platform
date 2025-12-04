# ✅ INQUIRY SERVICE - DONE!

## What's Built:

```
📦 Inquiry Service (Port 8001)
├── ✅ POST /inquiries - Create inquiry
├── ✅ GET /inquiries - View all (with optional plot_id filter)
├── ✅ GET /health - Health check
├── ✅ Tests passing (4/4)
└── ✅ Dockerized
```

## Quick Test:

```bash
cd /home/semini/Documents/iit/plot-services/inquiry-service

# Run tests
pytest test_main.py -v

# Start service
uvicorn main:app --reload --port 8001

# Test API (in another terminal)
./test_api.sh

# Or view docs
http://localhost:8001/docs
```

## Database Schema:

| Field | Type | Description |
|-------|------|-------------|
| id | INT (PK) | Auto-increment |
| plot_id | VARCHAR | Property reference |
| name | VARCHAR | Customer name |
| email | VARCHAR | Customer email |
| phone | VARCHAR | Customer phone |
| message | VARCHAR | Inquiry message |
| created_at | TIMESTAMP | Created time |

## Files Created:

- `main.py` - FastAPI app
- `models.py` - Database model
- `schemas.py` - Validation
- `database.py` - DB connection
- `test_main.py` - Tests
- `test_api.sh` - Manual testing
- `Dockerfile` - Container
- `README.md` - Docs

**Time taken: ~10 minutes** ⚡
