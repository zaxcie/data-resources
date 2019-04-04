
-- Duplicate Users: BigQuery

WITH a AS
  (
  SELECT
  c.entity_id AS user_id,
  MIN(c.created_at) AS earliest_block
    FROM lemonade.comments AS c
        JOIN lemonade.users AS u
        ON c.entity_id = u.id
      WHERE type = 'block' 
      AND entity_type = 'users'
    GROUP BY 1 
  ),

b AS
  (
  SELECT 
  l.suspicionType, 
  l.user_1, 
  l.user_2,
  a.earliest_block AS earliest_block,
  MIN(l.created_at) AS earliest_duplicate
    FROM risk.account_links AS l
      JOIN lemonade.users AS u1
      ON l.user_1 = u1.id
      JOIN a
      ON a.user_id = l.user_1
        WHERE u1.blocked = 1
   GROUP BY 1,2,3,4
     -- Remove entries where block happened after match was identified
     HAVING earliest_block < earliest_duplicate
  ),

user_1 AS 
(
SELECT 
user_1 AS user,
suspicionType,
COUNT(*) AS num_times
  FROM b
    -- WHERE suspicionType NOT LIKE '%Addr'
  GROUP BY 1,2
  ORDER BY 3 DESC
)

SELECT
suspicionType AS suspicion_type,
COUNT(DISTINCT user) AS num_blocked_users 
  FROM user_1
  GROUP BY 1
  ORDER BY 2 DESC;
