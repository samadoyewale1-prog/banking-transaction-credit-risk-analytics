-- PostgreSQL: run after importing the three CSVs into tables with matching columns.
-- Use numeric for amounts/rates, integer for age/days_past_due, date for dates.
-- 1. Monthly completed transaction volume and fees
SELECT date_trunc('month', transaction_date)::date AS month, COUNT(*) AS transactions,
       ROUND(SUM(amount),2) AS transaction_volume, ROUND(SUM(fee_revenue),2) AS fee_revenue
FROM transactions WHERE status='Completed' GROUP BY 1 ORDER BY 1;

-- 2. Loan portfolio by product and delinquency exposure
SELECT loan_product, COUNT(*) AS loan_count, ROUND(SUM(outstanding_balance),2) AS exposure,
 ROUND(SUM(CASE WHEN days_past_due>=30 THEN outstanding_balance ELSE 0 END),2) AS delinquent_exposure,
 ROUND(100.0*SUM(CASE WHEN days_past_due>=30 THEN outstanding_balance ELSE 0 END)/NULLIF(SUM(outstanding_balance),0),2) AS delinquency_pct
FROM loans GROUP BY loan_product ORDER BY exposure DESC;

-- 3. Customer segment transaction activity (LEFT JOIN retains customers with no transactions)
SELECT c.segment, COUNT(DISTINCT c.customer_id) AS customers, COUNT(t.transaction_id) AS completed_transactions,
 ROUND(COALESCE(SUM(t.fee_revenue),0),2) AS fee_revenue
FROM customers c LEFT JOIN transactions t ON c.customer_id=t.customer_id AND t.status='Completed'
GROUP BY c.segment ORDER BY fee_revenue DESC;

-- 4. Flag transaction patterns for manual review; NOT a fraud prediction
WITH customer_daily AS (
 SELECT customer_id, transaction_date, COUNT(*) AS transaction_count, SUM(amount) AS total_amount
 FROM transactions WHERE status='Completed' GROUP BY 1,2
) SELECT * FROM customer_daily WHERE transaction_count>=5 OR total_amount>=20000 ORDER BY total_amount DESC;

-- 5. Rank loans by exposure within each risk tier
SELECT loan_id, risk_tier, outstanding_balance, days_past_due,
 DENSE_RANK() OVER(PARTITION BY risk_tier ORDER BY outstanding_balance DESC) AS exposure_rank
FROM loans;
