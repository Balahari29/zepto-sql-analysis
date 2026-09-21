# Zepto Product & Inventory SQL Analysis

## Project Overview

This project analyzes a Zepto product/catalog dataset using MySQL.

The project focuses on data cleaning, data quality validation, product discounts, category-level inventory, stock availability, and advanced SQL analysis.

## Dataset

The dataset contains product-level information including:

- Category
- Product name
- MRP
- Discount percentage
- Available quantity
- Discounted selling price
- Weight
- Stock status
- Quantity

The staging table contained **3,728 records**.

After removing exact duplicate records and applying data-cleaning transformations, the final table contained **3,726 records**.

## Data Cleaning

The project includes:

- Missing-value checks
- Duplicate detection
- Price anomaly detection
- `TRIM()` for text cleaning
- `CASE` for stock-status transformation
- `DISTINCT` for removing exact duplicate records
- `INSERT INTO ... SELECT` for loading cleaned data
- Final data reconciliation

### Stock Status Transformation

The raw staging data stored stock status as text:

```text
TRUE
FALSE
