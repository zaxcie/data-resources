-- NOTE: There are small discrepancies vs. existing BigQuery table due to rounding decimals

WITH summary AS
(
SELECT
p.user_id,
pv.policy_id,
d.date,
pv.id AS policy_version_id,
(pv.annual_premium / 365) AS daily_earned_premium,
-- p.effective_date AS policy_effective_date,
-- CASE WHEN p.canceled_date < p.renewal_date AND p.canceled_date < DATEADD('day', 365, p.effective_date) AND p.canceled_date IS NOT NULL THEN p.canceled_date
-- WHEN p.renewal_date < p.canceled_date AND p.renewal_date < DATEADD('day', 365, p.effective_date) AND p.renewal_date IS NOT NULL THEN p.renewal_date
-- ELSE DATEADD('day', 365, p.effective_date) END AS policy_end_date,
ROW_NUMBER() OVER(PARTITION BY pv.policy_id, d.date ORDER BY pv.created_at DESC) AS ord
    FROM policy_versions as pv
        JOIN policies AS p
        ON pv.policy_id = p.id
        CROSS JOIN
            (
            SELECT date FROM dates WHERE date BETWEEN '2016-09-15' AND CURRENT_DATE()) AS d
            WHERE p.status NOT IN ('pending', 'archived')
            AND COALESCE(p.test, 0) = 0
            AND p.effective_date <= d.date
            AND DATEADD('day', 365, p.effective_date) > d.date
            AND COALESCE(p.canceled_date, '2030-12-31') > d.date
            AND COALESCE(p.renewal_date, '2030-12-31') > d.date
            AND COALESCE(p.canceled_date, '2030-12-31') != p.created_at
            AND pv.start_date < COALESCE(pv.end_date, '2030-12-31')
)

SELECT 
s.user_id,
s.policy_id,
s.date,
s.policy_version_id,
s.daily_earned_premium
    FROM summary AS s
        WHERE s.ord = 1;