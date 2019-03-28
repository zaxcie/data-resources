SELECT
u.id AS user_id,
p.id AS policy_id,
DATEDIFF(year, u.date_of_birth, CURRENT_DATE) as user_age,
ed.email,
ed.domain,
p.state AS policy_state,
p.form AS policy_form,
p.status AS policy_status,
p.source AS policy_source,
p.credit_score AS policy_credit_score,
p.base_deductible AS policy_base_deductible,
p.tier AS policy_tier,
DATEDIFF(day, q.created_at, p.created_at) as days_quote_to_policy_created,
DATEDIFF(day, q.created_at, p.effective_date) as days_quote_to_policy_effective,
DATEDIFF(day, p.created_at, p.effective_date) as days_policy_created_to_policy_effective,
u.date_of_birth AS user_dob,
q.created_at AS quote_created_at,
p.created_at AS policy_created_at,
p.effective_date AS policy_effective_date
    FROM users AS u
        JOIN policies AS p
        ON u.id = p.user_id
        JOIN quotes AS q
        ON p.quote_id = q.id
LEFT JOIN user_email_domains AS ed
ON u.id = ed.user_id
            WHERE p.status != 'pending'
            AND q.status IN ('bindable', 'paid')
            AND p.country = 'US';