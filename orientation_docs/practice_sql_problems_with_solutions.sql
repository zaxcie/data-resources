// SQL EXERCISES FROM ELLEN (ONBOARDING)

-- Count the number of policies created on Mar 1 in the state of Georgia.

SELECT COUNT(*)
    FROM policies AS p
        WHERE CAST(created_at AS DATE) = '2018-03-01'
        AND state = 'GA'
        AND test != TRUE;;

-- Count the number of homeowners policies that went into effect on 1/31/19.

SELECT COUNT(*)
    FROM policies AS p
        WHERE CAST(effective_date AS DATE) = '2019-01-31'
        AND form IN ('ho3', 'ho6')
        AND test != TRUE;;
        
-- What is the average replacement cost of a home that we currently cover (e.g., policy is in effect) in the state of Texas?

SELECT form, AVG(replacement_cost), MEDIAN(replacement_cost)
    FROM policies AS p
        WHERE state = 'TX'
        AND status = 'active'
        AND replacement_cost IS NOT NULL
        AND form IN ('ho3', 'ho6')
        AND test != TRUE
        GROUP BY 1
        ORDER BY 2 DESC;;
        
-- What is the current average policy value (APV) of Lemonade's book of business by form? 

SELECT form, AVG(annual_premium), MEDIAN(annual_premium)
    FROM policies AS p
        WHERE status IN ('active', 'future')
        AND test != TRUE
        GROUP BY 1
        ORDER BY 2 DESC;;
        
-- Count the number of users who had a same-day cancellation policy in February.

SELECT COUNT(DISTINCT user_id)
    FROM policies AS p
        WHERE CAST(canceled_date AS DATE) = CAST(created_at AS DATE)
        AND CAST(created_at AS DATE) BETWEEN '2019-02-01' AND '2019-02-28'
        AND test != TRUE;;
        
-- Which state had the most declined quotes in Feburary?

SELECT state, COUNT(*)
    FROM quotes AS q
        WHERE CAST(created_at AS DATE) BETWEEN '2019-02-01' AND '2019-02-28'
        AND status = 'uw_declined'
    GROUP BY 1
    ORDER BY 2 DESC
    LIMIT 1;;
    
-- What is the average value of a bindable quote created in 2019 by form?

SELECT form, AVG(premium)
    FROM quotes AS q
        WHERE CAST(created_at AS DATE) >= '2019-01-01'
        AND status IN ('bindable', 'canceled', 'future', 'paid', 'active')
    GROUP BY 1
    ORDER BY 2 DESC;;
    
-- What is the average number of days between when a quote is created and a homeowner purchased his or her policy? 

SELECT q.id AS quote_id, p.id AS policy_id, q.created_at AS quote_created_at, p.created_at AS policy_created_at, p.status AS policy_status, 
TIMESTAMPDIFF(day, q.created_at, p.created_at) AS days_to_policy
    FROM quotes AS q
        JOIN policies AS p
        ON p.quote_id = q.id
            WHERE p.form IN ('ho4')
            AND p.test != TRUE
            AND p.status NOT IN ('renewal', 'expired', 'renewed', 'canceled_renewal')
            AND p.years_insured = 0
            AND p.created_at >= q.created_at
            ORDER BY 6 DESC;;

-- What was the most common UW decline reason last month?

-- CODE NEEDS TWEAKING B/C OF THE SQUARE BRACKETS IN JSON
SELECT uw_filter:message::string AS decline_reason, COUNT(*)
    FROM quotes AS q
        WHERE status = 'uw_declined'
        AND CAST(created_at AS DATE) > DATEADD(day, -30, CURRENT_TIMESTAMP())
        AND uw_filter:enforced::boolean = true
        GROUP BY 1
        ORDER BY 2 DESC;;
        
-- What types of claims (loss type) are most likely to be declined (i.e., closed without payment?)

SELECT loss_type, COUNT(*)
    FROM claims AS c 
        WHERE status = 'closed'
        AND paid = TRUE
    GROUP BY 1 
    ORDER BY 2 DESC
    LIMIT 1;;
 
-- What was the median number of days from policy effective to claim submitted date by loss type for all claims submitted in 2018?

WITH summary AS 
(
SELECT c.loss_type AS claim_loss_type, p.effective_date AS policy_effective_date, c.created_at AS claim_submitted_date,
TIMESTAMPDIFF(day, p.effective_date, c.created_at) AS days_to_claim
    FROM claims AS c
        JOIN policies AS p
        ON c.policy_id = p.id
            WHERE CAST(c.created_at AS DATE) BETWEEN '2018-01-01' AND '2018-12-31'
)

SELECT claim_loss_type, MEDIAN(days_to_claim) AS median_days_to_claim, COUNT(*) AS num_claims
    FROM summary
    GROUP BY 1
    ORDER BY 2 DESC;;

-- What was the average age of a user with a reported claim by loss type last year?

WITH summary AS
(
SELECT c.loss_type, u.date_of_birth, TIMESTAMPDIFF(year, u.date_of_birth, c.submitted_at) AS user_age
    FROM claims AS c
        JOIN users AS u
        ON c.user_id = u.id
            WHERE CAST(c.submitted_at AS DATE) > DATEADD(day, -365, CURRENT_TIMESTAMP())
            AND c.status != 'pending'
            AND c.test != TRUE
            AND c.submitted_at IS NOT NULL
)

SELECT loss_type, AVG(user_age) AS average_age, COUNT(*) AS num_claims
    FROM summary
    GROUP BY 1
    ORDER BY 2 DESC;;

-- Count the number of users who entered dunning in January 2019.

SELECT COUNT(DISTINCT user_id) AS num_users
    FROM dunning AS d
        WHERE CAST(created_at AS DATE) BETWEEN '2019-01-01' AND '2019-01-31';;

-- How many users failed dunning in January 2019? 

SELECT COUNT(DISTINCT s.user_id) AS num_users
    FROM dunning AS d
            WHERE CAST(d.last_attempt AS DATE) BETWEEN '2019-01-01' AND '2019-01-31'
            AND d.status = 'failed';;

-- What is the dunning "success rate" by state in 2019?

SELECT s.state,
COUNT(CASE WHEN s.status != 'canceled' THEN s.user_id ELSE NULL END) AS successes,
COUNT(s.user_id) AS total,
ROUND(100.0 * successes / total, 2) AS success_rate
    FROM dunning AS d
        JOIN policies_user_status_changes AS s
        ON d.user_id = s.user_id
            WHERE CAST(d.created_at AS DATE) >= '2019-01-01'
            -- CLARIFY HOW MANY DAYS AFTER LAST ATTEMPT POLICY GET CANCELED
            AND TIMESTAMPDIFF(day, d.last_attempt, CURRENT_TIMESTAMP()) >= 30
    GROUP BY 1
    ORDER BY 4 DESC;;

-- What was the most commonly added scheduled item in 2018? 

SELECT type, COUNT(*)
    FROM scheduled_items AS i
        WHERE CAST(i.created_at AS DATE) BETWEEN '2018-01-01' AND '2018-12-31'
        AND status NOT IN ('draft', 'rejected', 'archived', 'pending', 'expired')
        AND blanket = FALSE
    GROUP BY 1
    ORDER BY 2 DESC
    LIMIT 1;;

-- What was the average value of a scheduled item added in January? (Excluding blankets...)

SELECT AVG(value) AS average_value
    FROM scheduled_items AS i
        WHERE CAST(i.created_at AS DATE) BETWEEN '2019-01-01' AND '2019-01-31'
        AND status NOT IN ('draft', 'rejected', 'archived', 'pending', 'expired')
        AND blanket = FALSE;;

-- What percent of scheduled items are added to policy the day the policy goes into effect?

-- NEED TO UPDATE THIS ONE!
SELECT 
COUNT(CASE WHEN pc.action = 'add' AND CAST(pc.change_date AS DATE) = CAST(i.created_at AS DATE) THEN i.id ELSE NULL END) AS successes,
COUNT(i.id) AS total,
ROUND(100.0 * successes / total, 2) AS success_rate
    FROM scheduled_items AS i
        LEFT JOIN policy_changes AS pc
        ON i.id = pc.scheduled_item_id;;

