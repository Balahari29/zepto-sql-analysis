-- Zepto Product & Inventory SQL Analysis
-- MySQL | Cleaned product/catalog snapshot

CREATE DATABASE IF NOT EXISTS zepto_analysis;
USE zepto_analysis;

-- 1. Staging table
CREATE TABLE IF NOT EXISTS zepto_staging (
    Category VARCHAR(100),
    name VARCHAR(255),
    mrp INT,
    discountPercent INT,
    availableQuantity INT,
    discountedSellingPrice INT,
    weightInGms INT,
    outOfStock VARCHAR(10),
    quantity INT
);

-- 2. Data quality checks
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT name) AS unique_products
FROM zepto_staging;

SELECT
    SUM(Category IS NULL OR Category = '') AS missing_category,
    SUM(name IS NULL OR name = '') AS missing_name,
    SUM(mrp IS NULL) AS missing_mrp,
    SUM(discountPercent IS NULL) AS missing_discount,
    SUM(availableQuantity IS NULL) AS missing_available_quantity,
    SUM(discountedSellingPrice IS NULL) AS missing_selling_price,
    SUM(weightInGms IS NULL) AS missing_weight,
    SUM(outOfStock IS NULL OR outOfStock = '') AS missing_stock_status,
    SUM(quantity IS NULL) AS missing_quantity
FROM zepto_staging;

-- Exact duplicates
SELECT Category, name, mrp, discountPercent, availableQuantity,
       discountedSellingPrice, weightInGms, outOfStock, quantity,
       COUNT(*) AS duplicate_count
FROM zepto_staging
GROUP BY Category, name, mrp, discountPercent, availableQuantity,
         discountedSellingPrice, weightInGms, outOfStock, quantity
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- Pricing anomalies
SELECT name, Category, mrp, discountPercent, discountedSellingPrice
FROM zepto_staging
WHERE mrp <= 0 OR discountedSellingPrice <= 0;

-- 3. Final cleaned table
CREATE TABLE IF NOT EXISTS zepto_products (
    prod_id INT AUTO_INCREMENT PRIMARY KEY,
    Category VARCHAR(100),
    name VARCHAR(255),
    mrp INT,
    discountPercent INT,
    availableQuantity INT,
    discountedSellingPrice INT,
    weightInGms INT,
    outOfStock BOOLEAN,
    quantity INT
);

-- Use TRUNCATE only when rebuilding the final table from staging.
TRUNCATE TABLE zepto_products;

INSERT INTO zepto_products (
    Category, name, mrp, discountPercent, availableQuantity,
    discountedSellingPrice, weightInGms, outOfStock, quantity
)
SELECT DISTINCT
    TRIM(Category),
    TRIM(name),
    mrp,
    discountPercent,
    availableQuantity,
    discountedSellingPrice,
    weightInGms,
    CASE WHEN outOfStock = 'TRUE' THEN 1 ELSE 0 END,
    quantity
FROM zepto_staging;

-- Validate final table
SELECT COUNT(*) AS total_products FROM zepto_products;

SELECT outOfStock, COUNT(*) AS product_count
FROM zepto_products
GROUP BY outOfStock;

-- 4. Business analysis: discount bands
SELECT
    CASE
        WHEN discountPercent = 0 THEN 'No Discount'
        WHEN discountPercent <= 20 THEN 'Low Discount'
        WHEN discountPercent <= 40 THEN 'Medium Discount'
        ELSE 'High Discount'
    END AS discount_band,
    COUNT(*) AS product_count,
    ROUND(COUNT(*) / (SELECT COUNT(*) FROM zepto_products) * 100, 2) AS percentage
FROM zepto_products
GROUP BY discount_band
ORDER BY product_count DESC;

-- Category inventory and out-of-stock rate
SELECT
    Category,
    COUNT(*) AS total_products,
    ROUND(AVG(discountPercent), 2) AS avg_discount,
    SUM(CASE WHEN outOfStock = 1 THEN 1 ELSE 0 END) AS out_of_stock,
    ROUND(
        SUM(CASE WHEN outOfStock = 1 THEN 1 ELSE 0 END) / COUNT(*) * 100,
        2
    ) AS out_of_stock_rate
FROM zepto_products
GROUP BY Category
ORDER BY out_of_stock_rate DESC;

-- Categories above the overall average discount
WITH category_avg AS (
    SELECT Category, AVG(discountPercent) AS avg_discount
    FROM zepto_products
    GROUP BY Category
)
SELECT Category, ROUND(avg_discount, 2) AS avg_discount
FROM category_avg
WHERE avg_discount > (SELECT AVG(discountPercent) FROM zepto_products)
ORDER BY avg_discount DESC;

-- Highest-discounted products in each category; ties preserved
WITH ranked_products AS (
    SELECT
        name, Category, discountPercent,
        RANK() OVER (
            PARTITION BY Category
            ORDER BY discountPercent DESC
        ) AS discount_rank
    FROM zepto_products
)
SELECT name, Category, discountPercent, discount_rank
FROM ranked_products
WHERE discount_rank = 1
ORDER BY Category, name;

-- Exactly one highest-discounted product per category
WITH ranked_products AS (
    SELECT
        name, Category, discountPercent,
        ROW_NUMBER() OVER (
            PARTITION BY Category
            ORDER BY discountPercent DESC
        ) AS row_num
    FROM zepto_products
)
SELECT name, Category, discountPercent, row_num
FROM ranked_products
WHERE row_num = 1
ORDER BY Category;

-- Largest absolute price reductions
SELECT
    name,
    Category,
    mrp,
    discountedSellingPrice,
    mrp - discountedSellingPrice AS price_reduction
FROM zepto_products
WHERE mrp > 0 AND discountedSellingPrice > 0
ORDER BY price_reduction DESC
LIMIT 10;

-- Pricing anomalies
SELECT name, Category, mrp, discountedSellingPrice, discountPercent
FROM zepto_products
WHERE mrp <= 0 OR discountedSellingPrice <= 0;
