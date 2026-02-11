# AI Product Insights — Data Seeding Guide

## 📊 Dataset Overview

**File**: `data/reviews_dataset.csv`  
**Rows**: 100 customer reviews  
**Products**: Laptop Pro 15, Wireless Mouse, USB-C Cable, Monitor 4K, Mechanical Keyboard, USB Hub, External SSD, Wireless Charger

**Columns**:
- `id`: Unique identifier
- `product_name`: Product being reviewed
- `review_text`: Customer feedback text
- `rating`: 1-5 stars
- `channel`: Collection method (email, sms, qr)
- `created_at`: Review timestamp

---

## 🗄️ Database Schema

See `infra/sql/01_init_reviews_table.sql` for full schema.

**Table**: `reviews`

| Column | Type | Constraints |
|--------|------|-------------|
| id | SERIAL | PRIMARY KEY |
| product_name | VARCHAR(255) | NOT NULL |
| review_text | TEXT | NOT NULL |
| rating | INTEGER | NOT NULL, CHECK (1-5) |
| channel | VARCHAR(50) | NOT NULL |
| created_at | TIMESTAMP | NOT NULL |
| inserted_at | TIMESTAMP | DEFAULT NOW() |

**Indexes**: product_name, channel, rating, created_at for fast queries.

---

## 🚀 Seeding Instructions

### Option 1: Run Locally (Python)

#### Prerequisites
```bash
pip install -r scripts/requirements.txt
```

#### Setup Environment Variables
```bash
export DB_HOST=localhost
export DB_PORT=5433
export DB_NAME=product_insights
export DB_USER=app_user
export DB_PASSWORD=app_password
export REVIEWS_CSV=/path/to/data/reviews_dataset.csv
```

#### Execute Seed Script
```bash
python scripts/seed_reviews.py
```

**Expected Output**:
```
🌱 Starting AI Product Insights seeding...

✅ Connected to PostgreSQL

✅ Reviews table created or already exists
✅ Loaded 100 reviews from CSV
✅ Inserted 100 reviews into database
📊 Total reviews in database: 100

✅ Seeding complete!
```

---

### Option 2: Run Inside Docker Container

#### Setup Environment (from project root)
```bash
cd /home/saif/projects/Product_Insights
```

#### Install Dependencies in Container
```bash
docker exec scraper-service pip install psycopg2 pandas
```

#### Copy Dataset to Container
```bash
docker cp data/reviews_dataset.csv scraper-service:/app/
```

#### Run Seed Script
```bash
docker exec -e DB_HOST=postgres -e DB_PORT=5432 -e DB_NAME=product_insights -e DB_USER=app_user -e DB_PASSWORD=app_password -e REVIEWS_CSV=/app/reviews_dataset.csv scraper-service python /path/to/scripts/seed_reviews.py
```

---

### Option 3: Integrated into Docker Compose (Recommended)

Update `docker-compose.yml` to include a seed service:

```yaml
seed-reviews:
  image: python:3.11-slim
  container_name: seed-reviews
  working_dir: /app
  environment:
    DB_HOST: postgres
    DB_PORT: 5432
    DB_NAME: product_insights
    DB_USER: app_user
    DB_PASSWORD: app_password
    REVIEWS_CSV: /app/data/reviews_dataset.csv
  volumes:
    - ./scripts:/app/scripts
    - ./data:/app/data
  command: >
    sh -c "pip install psycopg2 pandas &&
           python scripts/seed_reviews.py"
  depends_on:
    - postgres
  networks:
    - app-net
```

Then run:
```bash
docker compose run --rm seed-reviews
```

---

## ✅ Verify Data

### Check Total Review Count
```bash
psql -h localhost -p 5433 -U app_user -d product_insights -c "SELECT COUNT(*) FROM reviews;"
```

### View Sample Reviews
```bash
psql -h localhost -p 5433 -U app_user -d product_insights -c "SELECT id, product_name, rating, channel, created_at FROM reviews LIMIT 5;"
```

### Get Statistics by Product
```bash
psql -h localhost -p 5433 -U app_user -d product_insights -c "
SELECT product_name, COUNT(*) as review_count, AVG(rating)::numeric(3,2) as avg_rating 
FROM reviews 
GROUP BY product_name 
ORDER BY review_count DESC;"
```

### Get Statistics by Channel
```bash
psql -h localhost -p 5433 -U app_user -d product_insights -c "
SELECT channel, COUNT(*) as count, AVG(rating)::numeric(3,2) as avg_rating 
FROM reviews 
GROUP BY channel;"
```

### Get Statistics by Rating
```bash
psql -h localhost -p 5433 -U app_user -d product_insights -c "
SELECT rating, COUNT(*) as count 
FROM reviews 
GROUP BY rating 
ORDER BY rating;"
```

---

## 📋 Commands Summary

| Task | Command |
|------|---------|
| Install deps | `pip install -r scripts/requirements.txt` |
| Seed locally | `python scripts/seed_reviews.py` |
| Count reviews | `psql -h localhost -p 5433 -U app_user -d product_insights -c "SELECT COUNT(*) FROM reviews;"` |
| View samples | `psql -h localhost -p 5433 -U app_user -d product_insights -c "SELECT * FROM reviews LIMIT 5;"` |

---

## 🔧 Troubleshooting

**Connection Refused**
- Check if PostgreSQL container is running: `docker compose ps`
- Verify port: Should be `5433` on host (internal: `5432`)

**CSV File Not Found**
- Verify path: `ls data/reviews_dataset.csv`
- Update `REVIEWS_CSV` env var if needed

**psycopg2 Import Error**
- Install: `pip install psycopg2`
- Or use `psycopg2-binary`: `pip install psycopg2-binary`

---

## 📈 Next Steps

1. ✅ Seed reviews into PostgreSQL
2. 🔄 Build AI Analysis Service to process reviews
3. 📊 Build Stats Service to aggregate insights
4. 🎨 Display in React Dashboard
