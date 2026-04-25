# 🏗️ Data Warehouse Project
**Building a Modern Data Warehouse Using Medallion Architecture**

A complete, end-to-end data warehousing project built with **SQL Server** and **T-SQL** —  
from raw CSV ingestion to a business-ready star schema optimized for analytics.

---

## 📐 Architecture

This project follows the **Medallion Architecture** — an industry-standard pattern that organizes data into three progressive layers, each adding quality and structure:

```
CSV Files (CRM + ERP)
        │
        ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│    BRONZE    │────▶│    SILVER    │────▶│     GOLD     │
│  Raw Ingest  │     │  Clean & STD │     │  Star Schema │
│  (6 tables)  │     │  (6 tables)  │     │  (3 views)   │
└──────────────┘     └──────────────┘     └──────────────┘
        │                   │                    │
   As-is copy          Transformed          Analytics-ready
   of source           & validated          dim + fact model
```

| Layer | Schema | What happens here |
|-------|--------|-------------------|
| **Bronze** | `bronze` | Raw CSV data loaded as-is — no transformations, faithful source copy |
| **Silver** | `silver` | All data quality issues resolved — dedup, normalize, fix dates, align keys |
| **Gold** | `gold` | Star schema SQL views — joins CRM + ERP into `dim_customers`, `dim_products`, `fact_sales` |

---

## 🎯 Project Goals

Consolidate sales data from two disconnected systems — a **CRM** and an **ERP** — into a single unified analytical model that answers real business questions:

- Which country generates the most revenue?
- What are the best-performing product categories?
- How does monthly revenue trend over time?
- What is the average order value by customer demographics?
- Which products have the highest profit margin?

---

## 📂 Repository Structure

```
DataWarehouse/
│
├── datasets/
│   ├── source_crm/
│   │   ├── cust_info.csv          # Customer profiles
│   │   ├── prd_info.csv           # Product catalog
│   │   └── sales_details.csv      # Sales transactions
│   └── source_erp/
│       ├── CUST_AZ12.csv          # Customer birthdate & gender
│       ├── LOC_A101.csv           # Customer country / location
│       └── PX_CAT_G1V2.csv        # Product category hierarchy
│
├── src/
│   ├── init_database.sql          # ① Create database + schemas
│   ├── bronze/
│   │   ├── ddl_bronze.sql         # ② Create Bronze tables
│   │   └── proc_load_bronze.sql   # ③ Load CSVs into Bronze
│   ├── silver/
│   │   ├── ddl_silver.sql         # ④ Create Silver tables
│   │   └── proc_load_silver.sql   # ⑤ Transform & load Silver
│   └── gold/
│       └── ddl_gold.sql           # ⑥ Create Gold star schema views
│
└── tests/
    ├── quality_checks_silver.sql  # Validate Silver layer
    └── quality_checks_gold.sql    # Validate Gold layer
```

---

## 🚀 Getting Started

### Prerequisites

| Tool | Purpose | Cost |
|------|---------|------|
| [SQL Server Express](https://www.microsoft.com/en-us/sql-server/sql-server-downloads) | Database engine | Free |
| [SSMS](https://learn.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms) | SQL GUI client | Free |

### Run Order

Execute the scripts **in this exact order**:

```
① src/init_database.sql
② src/bronze/ddl_bronze.sql
③ src/bronze/proc_load_bronze.sql   →   EXEC bronze.load_bronze;
④ src/silver/ddl_silver.sql
⑤ src/silver/proc_load_silver.sql   →   EXEC silver.load_silver;
⑥ src/gold/ddl_gold.sql
```

> ⚠️ `init_database.sql` will **drop and recreate** the `DataWarehouse` database if it already exists. Make sure you have no data you want to keep before running it.

### Validate

After loading each layer, run the quality check scripts:

```sql
-- After step ⑤
tests/quality_checks_silver.sql

-- After step ⑥
tests/quality_checks_gold.sql
```

Every check is a `SELECT` query. **Zero rows returned = pass.** Any rows indicate a problem to investigate.

---

## 📊 Data Model (Gold Layer)

The Gold layer implements a **star schema** — the industry standard for analytical models:

```
                    ┌─────────────────┐
                    │  dim_customers  │
                    │─────────────────│
                    │ customer_key PK │
                    │ first_name      │
                    │ last_name       │
                    │ country         │
                    │ gender          │
                    │ marital_status  │
                    │ birthdate       │
                    └────────┬────────┘
                             │ FK
              ┌──────────────▼──────────────┐
              │          fact_sales          │
              │──────────────────────────────│
              │ order_number                 │
              │ customer_key  FK             │
              │ product_key   FK             │
              │ order_date                   │
              │ shipping_date                │
              │ due_date                     │
              │ sales_amount                 │
              │ quantity                     │
              │ price                        │
              └──────────────┬───────────────┘
                             │ FK
                    ┌────────▼────────┐
                    │  dim_products   │
                    │─────────────────│
                    │ product_key  PK │
                    │ product_name    │
                    │ category        │
                    │ subcategory     │
                    │ product_line    │
                    │ cost            │
                    │ maintenance     │
                    │ start_date      │
                    └─────────────────┘
```

### Sample Queries

```sql
-- Revenue by country
SELECT c.country, SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
JOIN gold.dim_customers c ON f.customer_key = c.customer_key
GROUP BY c.country
ORDER BY total_revenue DESC;

-- Top product categories
SELECT p.category, SUM(f.sales_amount) AS revenue
FROM gold.fact_sales f
JOIN gold.dim_products p ON f.product_key = p.product_key
GROUP BY p.category
ORDER BY revenue DESC;

-- Monthly sales trend
SELECT FORMAT(order_date, 'yyyy-MM') AS month,
       SUM(sales_amount) AS monthly_revenue
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY FORMAT(order_date, 'yyyy-MM')
ORDER BY month;

-- Profit margin by product
SELECT p.product_name, p.cost,
       AVG(f.price) AS avg_price,
       AVG(f.price) - p.cost AS avg_margin
FROM gold.fact_sales f
JOIN gold.dim_products p ON f.product_key = p.product_key
GROUP BY p.product_name, p.cost
ORDER BY avg_margin DESC;
```

---

## 🔍 Key Transformations (Silver Layer)

| Source Problem | Transformation Applied |
|----------------|----------------------|
| Duplicate customer records | `ROW_NUMBER()` deduplication — keeps most recent record per `cst_id` |
| Dates stored as integers | Cast `INT → VARCHAR → DATE` with validity checks (0 or wrong length → `NULL`) |
| Coded gender (`M`/`F`) | Normalized to `'Male'` / `'Female'` / `'n/a'` |
| Coded marital status (`M`/`S`) | Normalized to `'Married'` / `'Single'` / `'n/a'` |
| Coded product line (`M`/`R`/`S`/`T`) | Normalized to `'Mountain'` / `'Road'` / `'Touring'` / `'Other Sales'` |
| Country abbreviations (`DE`, `US`, `USA`) | Expanded to full country names |
| ERP key prefix mismatch (`NAS...`) | `SUBSTRING()` strips the `NAS` prefix |
| Location table hyphenated IDs | `REPLACE(cid, '-', '')` removes hyphens |
| Invalid future birthdates | Set to `NULL` where `bdate > GETDATE()` |
| Inconsistent sales amounts | Recomputed as `quantity × ABS(price)` where `sales ≠ qty × price` |
| Product end dates missing | Derived using `LEAD()` window function over product versions |
| Product category only in ERP | Category ID extracted from CRM product key prefix, joined to ERP |

---

## ✅ Quality Checks

### Silver Layer

| Table | Checks |
|-------|--------|
| `silver.crm_cust_info` | No duplicate/NULL `cst_id` · No whitespace in `cst_key` · Standardized marital status values |
| `silver.crm_prd_info` | No duplicate/NULL `prd_id` · No whitespace in `prd_nm` · No negative/NULL cost · Standardized product line · No invalid date ordering |
| `silver.crm_sales_details` | Valid date formats in source · No invalid date ordering · `sales = quantity × price` |
| `silver.erp_cust_az12` | Birthdates in range 1924–today · Standardized gender values |
| `silver.erp_loc_a101` | No country abbreviations remain |
| `silver.erp_px_cat_g1v2` | No whitespace in category fields · Standardized maintenance flag |

### Gold Layer

| Check | What it verifies |
|-------|-----------------|
| `customer_key` uniqueness | No duplicate surrogate keys in `dim_customers` |
| `product_key` uniqueness | No duplicate surrogate keys in `dim_products` |
| Referential integrity | Every `fact_sales` row joins to a valid customer and product |

---

## 🛠️ Tech Stack

| Tool | Role |
|------|------|
| SQL Server Express | Database engine |
| T-SQL | ETL logic — stored procedures, window functions, views |
| SSMS | Query and database management interface |
| Git / GitHub | Version control |

---

## 📜 Credits & Acknowledgements

This project is based on the **SQL Data Warehouse Project** originally created by **Baraa Khatib Salkini** ([@DataWithBaraa](https://github.com/DataWithBaraa)).

The original project — including the datasets, Medallion Architecture design, ETL methodology, and SQL scripts — was developed as part of a free educational course series. All credit for the original concept, data, and teaching materials belongs to the author.

| | |
|--|--|
| 🌐 Website | [datawithbaraa.com](https://www.datawithbaraa.com) |
| 📺 YouTube | [@datawithbaraa](https://www.youtube.com/@datawithbaraa) |
| 💼 LinkedIn | [baraa-khatib-salkini](https://linkedin.com/in/baraa-khatib-salkini) |
| 📦 Original repo | [github.com/DataWithBaraa/sql-data-warehouse-project](https://github.com/DataWithBaraa/sql-data-warehouse-project) |

> This repository is a student adaptation of the original work, built and extended for a university class project on database systems and data engineering.

---

## 🛡️ License

This project is licensed under the [MIT License](LICENSE).  
Original work © Baraa Khatib Salkini — adapted for academic use.
