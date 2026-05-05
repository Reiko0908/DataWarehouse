/*
===============================================================================
Stored Procedure: Load Gold Layer (Silver -> Gold)
===============================================================================
Script Purpose:
    This stored procedure orchestrates the refresh of the Gold layer views.
    In this architecture, the Gold layer consists of business-ready views 
    that represent the final Dimension and Fact tables (Star Schema).

    Actions Performed:
    - Calculates the total duration of the Gold layer refresh.
    - Refreshes metadata for the Gold views to ensure they reflect any 
      schema changes in the underlying Silver tables.
    - Prints status updates for monitoring purposes.

Usage Example:
    SELECT TOP 10 * FROM gold.dim_customers;
    SELECT TOP 10 * FROM gold.dim_products;
    SELECT TOP 10 * FROM gold.fact_sales;
    EXEC gold.load_gold;
===============================================================================
*/

USE DataWarehouse;
GO

CREATE OR ALTER PROCEDURE gold.load_gold AS
BEGIN
    DECLARE @batch_start_time DATETIME, @batch_end_time DATETIME;
    
    BEGIN TRY
        SET @batch_start_time = GETDATE();
        PRINT '================================================';
        PRINT 'Loading Gold Layer';
        PRINT '================================================';

        -- =============================================================================
        -- Refreshing Views
        -- =============================================================================

        PRINT '>> Refreshing View: gold.dim_customers';
        EXEC sp_refreshview 'gold.dim_customers';

        PRINT '>> Refreshing View: gold.dim_products';
        EXEC sp_refreshview 'gold.dim_products';

        PRINT '>> Refreshing View: gold.fact_sales';
        EXEC sp_refreshview 'gold.fact_sales';

        SET @batch_end_time = GETDATE();
        PRINT '================================================';
        PRINT 'Completed loading Gold Layer';
        PRINT 'Total Load Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
        PRINT '================================================';
        
    END TRY
    BEGIN CATCH
        PRINT '=========================================='
        PRINT 'ERROR OCCURRED DURING LOADING GOLD LAYER'
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Error State: ' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '=========================================='
    END CATCH
END;