"""
Database seed script for AI Product Insights Platform.
Inserts sample reviews from CSV into PostgreSQL.
"""

import os
import csv
from datetime import datetime
import psycopg2
from psycopg2.extras import execute_values


def get_db_connection():
    """Connect to PostgreSQL using environment variables."""
    try:
        conn = psycopg2.connect(
            host=os.getenv("DB_HOST", "localhost"),
            port=os.getenv("DB_PORT", "5432"),
            database=os.getenv("DB_NAME", "product_insights"),
            user=os.getenv("DB_USER", "app_user"),
            password=os.getenv("DB_PASSWORD", "app_password"),
        )
        return conn
    except psycopg2.Error as e:
        print(f"❌ Database connection error: {e}")
        raise


def create_reviews_table(conn):
    """Create the reviews table if it doesn't exist."""
    query = """
    CREATE TABLE IF NOT EXISTS reviews (
        id SERIAL PRIMARY KEY,
        product_name VARCHAR(255) NOT NULL,
        review_text TEXT NOT NULL,
        rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
        channel VARCHAR(50) NOT NULL,
        created_at TIMESTAMP NOT NULL,
        inserted_at TIMESTAMP DEFAULT NOW()
    );
    """
    try:
        with conn.cursor() as cur:
            cur.execute(query)
        conn.commit()
        print("✅ Reviews table created or already exists")
    except psycopg2.Error as e:
        print(f"❌ Error creating table: {e}")
        conn.rollback()
        raise


def load_reviews_from_csv(filepath):
    """Load reviews from CSV file."""
    reviews = []
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                reviews.append((
                    row["product_name"],
                    row["review_text"],
                    int(row["rating"]),
                    row["channel"],
                    row["created_at"],
                ))
        print(f"✅ Loaded {len(reviews)} reviews from CSV")
        return reviews
    except FileNotFoundError:
        print(f"❌ CSV file not found: {filepath}")
        raise
    except Exception as e:
        print(f"❌ Error reading CSV: {e}")
        raise


def insert_reviews(conn, reviews):
    """Insert reviews into the database using batch insert."""
    query = """
    INSERT INTO reviews (product_name, review_text, rating, channel, created_at)
    VALUES %s
    ON CONFLICT DO NOTHING;
    """
    try:
        with conn.cursor() as cur:
            execute_values(cur, query, reviews, page_size=100)
        conn.commit()
        print(f"✅ Inserted {len(reviews)} reviews into database")
    except psycopg2.Error as e:
        print(f"❌ Error inserting reviews: {e}")
        conn.rollback()
        raise


def count_reviews(conn):
    """Count total reviews in the database."""
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM reviews;")
            count = cur.fetchone()[0]
        print(f"📊 Total reviews in database: {count}")
        return count
    except psycopg2.Error as e:
        print(f"❌ Error counting reviews: {e}")
        raise


def main():
    """Main seed function."""
    print("🌱 Starting AI Product Insights seeding...\n")

    # Get CSV path
    csv_path = os.getenv(
        "REVIEWS_CSV",
        "/home/saif/projects/Product_Insights/data/reviews_dataset.csv"
    )

    # Connect to database
    conn = get_db_connection()
    print("✅ Connected to PostgreSQL\n")

    # Create table
    create_reviews_table(conn)

    # Load and insert reviews
    reviews = load_reviews_from_csv(csv_path)
    insert_reviews(conn, reviews)

    # Verify
    count_reviews(conn)

    # Close connection
    conn.close()
    print("\n✅ Seeding complete!")


if __name__ == "__main__":
    main()
