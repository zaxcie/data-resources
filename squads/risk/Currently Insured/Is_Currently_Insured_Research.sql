-- Buckets - Currently Insured

WITH a AS
  (
  SELECT DISTINCT 
  se.mixpanel_anonymous_id, 
  se.user_id AS mixpanel_user_id,
  se.traits_email AS user_email,
  u.id AS user_id,
  u.created_at AS user_created_at
      FROM segment_events AS se
          JOIN users AS u
          ON u.email = se.traits_email
  ),

b AS
  (
  SELECT DISTINCT
  COALESCE(raw:properties:currently_insured, raw:context:traits:l_currently_insured) AS is_currently_insured, 
  TRIM(raw:anonymousId, '"') AS anonymous_id,
  a.user_email,
  a.user_id,
  a.user_created_at
      FROM a
          LEFT JOIN segment
          ON (a.mixpanel_anonymous_id = TRIM(raw:anonymousId, '"')
          AND raw:event = 'switching_question_answered')
              WHERE a.user_created_at BETWEEN CURRENT_DATE() - INTERVAL '3 Months' AND CURRENT_DATE()
  ),

buckets AS
  (
  SELECT 
  f.user_id, 
  f.bucket
      FROM scores_flat AS f
          WHERE f.endpoint IN ('pre_quote')
  ),
  
final AS
(
SELECT 
CASE WHEN b.is_currently_insured IS NULL THEN 'n/a' ELSE b.is_currently_insured END AS is_currently_insured,
bu.bucket,
COUNT(DISTINCT b.user_id) AS num_users,
SUM(v.paid_losses_and_expenses_net) AS paid_net,
SUM(v.reserves_losses_and_expenses) AS reserves_net,
SUM(v.loss_and_lae_final) AS gross_loss_and_lae,
SUM(v.daily_earned_premium) AS earned_premium,
ROUND(100.0 * paid_net / earned_premium, 2) AS paid_loss_ratio,
ROUND(100.0 * reserves_net / earned_premium, 2) AS reserves_loss_ratio,
ROUND(100.0 * gross_loss_and_lae / earned_premium, 2) AS total_loss_ratio
  FROM b
      LEFT JOIN loss_ratio_view AS v
      ON b.user_id = v.user_id
      LEFT JOIN buckets AS bu
      ON b.user_id = bu.user_id
        WHERE CASE WHEN b.is_currently_insured IS NULL THEN NULL ELSE b.is_currently_insured END IS NOT NULL
  GROUP BY 1,2
)

SELECT
is_currently_insured,
bucket,
num_users,
ROUND(100.0 * num_users / SUM(num_users) OVER(PARTITION BY bucket ORDER BY is_currently_insured ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING), 2) AS pct_per_bucket,
total_loss_ratio,
gross_loss_and_lae,
earned_premium
    FROM final AS f
    ORDER BY 2,1 DESC;
    
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --


















-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

-- Compare Loss Ratios & Paid Frequencies based on Currently Insured
-- Mixpanel link: http://bit.ly/2WMuUhl

//WITH a AS
//  (
//  SELECT DISTINCT 
//  se.mixpanel_anonymous_id, 
//  se.user_id AS mixpanel_user_id,
//  se.traits_email AS user_email,
//  u.id AS user_id,
//  u.created_at AS user_created_at
//      FROM segment_events AS se
//          JOIN users AS u
//          ON u.email = se.traits_email
//  ),
//
//b AS
//  (
//  SELECT DISTINCT
//  COALESCE(raw:properties:currently_insured, raw:context:traits:l_currently_insured) AS is_currently_insured, 
//  TRIM(raw:anonymousId, '"') AS anonymous_id,
//  a.user_email,
//  a.user_id,
//  a.user_created_at
//      FROM a
//          LEFT JOIN segment
//          ON (a.mixpanel_anonymous_id = TRIM(raw:anonymousId, '"')
//          AND raw:event = 'switching_question_answered')
//              WHERE a.user_created_at BETWEEN CURRENT_DATE() - INTERVAL '7 Months' AND CURRENT_DATE() - INTERVAL '1 Months'
//  ),
//  
//-- select * from b;
//
//num_claims AS
//  (
//    WITH zip AS
//      (
//      SELECT 
//      b.user_id,
//      b.is_currently_insured,
//      COUNT(DISTINCT t.claim_id) AS num_submitted_claim,
//      COUNT(DISTINCT CASE WHEN c.paid = 'yes' THEN t.claim_id ELSE NULL END) AS num_paid_claim,
//      SUM(CASE WHEN c.paid = 'yes' THEN t.amount_in_cents / 100.0 ELSE 0 END) AS total_paid_claim
//        FROM b
//            LEFT JOIN policies AS p
//            ON b.user_id = p.user_id
//            LEFT JOIN claims AS c
//            ON (c.policy_id = p.id
//            AND c.status != 'pending'
//            AND c.test = 0)
//            LEFT JOIN transactions AS t
//            ON c.id = t.claim_id
//       GROUP BY 1,2
//       )
//
//    SELECT CASE WHEN is_currently_insured IS NULL THEN 'n/a' ELSE is_currently_insured END AS is_currently_insured,
//    SUM(num_submitted_claim) AS num_submitted_claims,
//    SUM(num_paid_claim) AS num_paid_claims,
//    SUM(total_paid_claim) AS total_paid_claims
//      FROM zip
//      GROUP BY 1
//  ),
//
//buckets AS
//  (
//  SELECT 
//  f.user_id, 
//  f.bucket
//      FROM scores_flat AS f
//          WHERE f.endpoint = 'pre_quote'
//  ),
//
//final AS
//  (
//  SELECT 
//  CASE WHEN b.is_currently_insured IS NULL THEN 'n/a' ELSE b.is_currently_insured END AS is_currently_insured,
//  -- bu.bucket,
//  COUNT(DISTINCT b.user_id) AS num_users,
//  SUM(v.paid_losses_and_expenses_net) AS paid_net,
//  SUM(v.reserves_losses_and_expenses) AS reserves_net,
//  SUM(v.loss_and_lae_final) AS gross_loss_and_lae,
//  SUM(v.daily_earned_premium) AS earned_premium,
//  ROUND(100.0 * paid_net / earned_premium, 2) AS paid_loss_ratio,
//  ROUND(100.0 * reserves_net / earned_premium, 2) AS reserves_loss_ratio,
//  ROUND(100.0 * gross_loss_and_lae / earned_premium, 2) AS total_loss_ratio
//    FROM b
//        LEFT JOIN loss_ratio_view AS v
//        ON b.user_id = v.user_id
//        LEFT JOIN buckets AS bu
//        ON b.user_id = bu.user_id
//    GROUP BY 1 -- ,2
//  )
//
//SELECT f.*,
//c.num_submitted_claims,
//c.num_paid_claims,
//c.total_paid_claims,
//total_paid_claims / num_paid_claims AS avg_amt_per_claim,
//ROUND(100.0 * num_paid_claims / (num_submitted_claims + 0.0001), 2) AS pct_paid_claims
//    FROM final AS f         
//      JOIN num_claims AS c
//      ON f.is_currently_insured = c.is_currently_insured
//    ORDER BY num_users ASC
//;
//
//-- select avg(amount_in_cents/ 100.0) from transactions join claims on claims.id = transactions.claim_id where paid = 'yes';
//-- select * from transactions as t join policies as p on p.id = t.policy_id where p.user_id = '511104' and t.type != 'policy';
//-- select min(timestamp) from scores_flat where endpoint = 'pre_quote';
//
//select count(case when paid = 'yes' then c.id else null end) as paid,
//count(c.id) as total
//    from claims as c
//    where c.submitted_at BETWEEN CURRENT_DATE() - INTERVAL '7 Months' AND CURRENT_DATE() - INTERVAL '1 Months';
//    
//    select paid, count(*) from transactions where status != 'policy' and status != 'pending' group by 1;