WITH a AS
    (
    SELECT DISTINCT
    user_id,
    email,
    SPLIT_PART(email, '@', -1) AS domain
        FROM users AS u
            JOIN policies AS p
            ON u.id = p.user_id
    ),

b AS
    (
    SELECT
    user_id,
    email,
    CASE WHEN domain ILIKE '%edu' THEN 'edu' ELSE domain END AS domain
        FROM a
    )
    
    SELECT
    CAST(user_id AS string) AS user_id,
    CAST(email AS string) AS email,
    CAST(SPLIT_PART(domain, '.', 1) AS string) AS domain
        FROM b
        ORDER BY 3,2;