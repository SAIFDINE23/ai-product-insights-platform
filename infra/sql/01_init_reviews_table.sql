-- Reviews Table Schema for AI Product Insights Platform
-- Stores customer feedback with metadata

CREATE TABLE IF NOT EXISTS reviews (
    id SERIAL PRIMARY KEY,
    
    -- Product & Content
    product_name VARCHAR(255) NOT NULL,
    review_text TEXT NOT NULL,
    
    -- Rating: 1 (very bad) to 5 (excellent)
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    
    -- Channel: how the review was collected
    channel VARCHAR(50) NOT NULL,
    
    -- Timestamps
    created_at TIMESTAMP NOT NULL,          -- When review was created
    inserted_at TIMESTAMP DEFAULT NOW()    -- When inserted into DB
);

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_reviews_product ON reviews(product_name);
CREATE INDEX IF NOT EXISTS idx_reviews_channel ON reviews(channel);
CREATE INDEX IF NOT EXISTS idx_reviews_rating ON reviews(rating);
CREATE INDEX IF NOT EXISTS idx_reviews_created_at ON reviews(created_at);
