-- Loss Ratio: Paid L&E, Reserves L&E, Subro, TPA & Adjuster Claims, IBNR Estimate

WITH loss_expense AS
    (
    SELECT
    p.user_id,
    t.policy_id,  
    CAST(COALESCE(t.date, t.created_at) AS date) AS date,
    LISTAGG(DISTINCT t.claim_id, ', ') WITHIN GROUP (ORDER BY t.claim_id DESC) AS claim_id,
    SUM(CASE WHEN (t.type = 'loss' AND t.status IN ('successful')) OR (t.type = 'reissue' AND t.status IN ('successful') AND tf.previous_transaction_type = 'loss') 
    THEN t.amount_in_cents / 100.0 ELSE 0 END) AS paid_loss_gross,
    SUM(CASE WHEN (t.type = 'refund' AND t.status = 'successful' AND tf.previous_transaction_status = 'successful') 
    THEN t.amount_in_cents / 100.0 ELSE 0 END) AS paid_loss_refund_gross,
    paid_loss_gross - paid_loss_refund_gross AS paid_loss_net,
    SUM(CASE WHEN ((t.type = 'expense' AND t.status = 'successful')
    OR (t.type = 'reissue' AND t.status = 'successful' AND tf.previous_transaction_type = 'expense')) 
    THEN t.amount_in_cents / 100.0 ELSE 0 END) AS paid_expense_gross,
    SUM(CASE WHEN (t.type = 'expense_refund' AND t.status = 'successful' AND tf.previous_transaction_status = 'successful') 
    THEN t.amount_in_cents / 100.0 ELSE 0 END) AS paid_expense_refund_gross,
    paid_expense_gross - paid_expense_refund_gross AS paid_expense_net,
    paid_loss_gross + paid_expense_gross AS paid_lae_gross,
    paid_loss_refund_gross + paid_expense_refund_gross AS paid_lae_refund_gross,
    paid_loss_net + paid_expense_net AS paid_lae_net
        FROM transactions AS t
            LEFT JOIN policies AS p
            ON p.id = t.policy_id
            LEFT JOIN transaction_facts AS tf 
            ON t.id = tf.transaction_id
                WHERE t.claim_id IS NOT NULL
                AND t.type != 'archived'
        GROUP BY 1,2,3
    ),
  
subro AS
    (
    SELECT
    p.user_id,
    c.policy_id,
    CAST(COALESCE(sc.time, sc.created_at) AS date) AS date,
    LISTAGG(DISTINCT c.id, ', ') WITHIN GROUP (ORDER BY c.id DESC) AS claim_id,
    SUM(sc.estimation_change_in_cents) / 100.0 AS anticipated_subro,
    SUM(sc.recovery_change_in_cents) / 100.0 AS received_subro,
    anticipated_subro + received_subro AS net_change_subro
        FROM subrogation AS s
            LEFT JOIN claims AS c
            ON s.claim_id = c.id
            LEFT JOIN features AS f
            ON c.id = f.claim_id
            LEFT JOIN subrogation_changes AS sc 
            ON f.id = sc.feature_id
            LEFT JOIN policies AS p
            ON c.policy_id = p.id
                WHERE sc.type IN ('remaining_recovery_estimation', 'recovery_received')
        GROUP BY 1,2,3
    ),

reserves AS
    (
    SELECT
    p.user_id,
    c.policy_id,
    CAST(rc.change_date AS date) AS date,
    LISTAGG(DISTINCT c.id, ', ') WITHIN GROUP (ORDER BY c.id DESC) AS claim_id,
    SUM(CASE WHEN i.type = 'loss' THEN rc.change_in_cents / 100.0 ELSE 0 END) AS reserves_loss,
    SUM(CASE WHEN (i.type = 'expense' AND c.status NOT IN ('pending', 'archived')) THEN rc.change_in_cents / 100.0 ELSE 0 END) AS reserves_expense,
    reserves_loss + reserves_expense AS reserves_lae
        FROM reserve_changes AS rc
            LEFT JOIN items AS i
            ON rc.claim_item_id = i.id
            LEFT JOIN claims AS c
            ON c.id = rc.claim_id
            LEFT JOIN policies AS p 
            ON c.policy_id = p.id
                WHERE c.test = 0
                AND rc.type != 'archived'
                AND i.status != 'archived'
        GROUP BY 1,2,3
    ),
 
claim_fees AS
    (
    SELECT
    p.user_id,
    c.policy_id,
    CAST(COALESCE(cf.date, cf.created_at) AS date) AS date,
    LISTAGG(DISTINCT c.id, ', ') WITHIN GROUP (ORDER BY c.id DESC) AS claim_id,
    SUM(CASE WHEN cf.type = 'tpa' AND cf.fee_type = 'fee_allocation' THEN cf.change_in_cents / 100.0 ELSE 0 END) AS tpa_fee,
    SUM(CASE WHEN cf.type = 'adjuster' AND cf.fee_type = 'fee_payment' THEN cf.change_in_cents / 100.0 ELSE 0 END) AS adjuster_fee,
    tpa_fee + adjuster_fee AS lae_total_claim_fees
        FROM claim_fee_changes AS cf
            LEFT JOIN claims AS c
            ON c.id = cf.claim_id
            LEFT JOIN policies AS p
            ON c.policy_id = p.id
        GROUP BY 1,2,3
    ), 
 
ibnr AS
    (
      
    WITH ibnr_est AS
        (
        SELECT
        d.date,
          CASE WHEN d.date BETWEEN '2016-09-15' AND '2030-12-31' THEN 0.4 ELSE 0.4 END AS loss_ibnr,
          CASE WHEN d.date BETWEEN '2016-09-15' AND '2030-12-31' THEN 0.2 ELSE 0.2 END AS expense_ibnr
            FROM dates AS d
        ),

    loss_exp AS
        (    
    SELECT
    pl.user_id,
    pl.policy_id,      
    pl.date,
    pl.paid_loss_net * ie.loss_ibnr AS loss_ibnr_est,
    pl.paid_expense_net * ie.expense_ibnr AS expense_ibnr_est,
    loss_ibnr_est + expense_ibnr_est AS total_ibnr_est
        FROM loss_expense AS pl
            LEFT JOIN ibnr_est AS ie
            ON pl.date = ie.date
        ),

    exp_exp AS
        (
        SELECT 
        r.user_id,
        r.policy_id,
        r.date,
        r.reserves_loss * ie.loss_ibnr AS loss_ibnr_est,
        r.reserves_expense * ie.expense_ibnr AS expense_ibnr_est,
        loss_ibnr_est + expense_ibnr_est AS total_ibnr_est
            FROM reserves AS r
                LEFT JOIN ibnr_est AS ie
                ON r.date = ie.date
            ),

    all_ibnr AS
        (
        SELECT * FROM loss_exp UNION ALL SELECT * FROM exp_exp
        )           

    SELECT user_id, policy_id, date, SUM(loss_ibnr_est) AS loss_ibnr_est, SUM(expense_ibnr_est) AS expense_ibnr_est, SUM(total_ibnr_est) AS total_ibnr_est
        FROM all_ibnr
        GROUP BY 1,2,3
    ),
    
unique_date_policy AS
    (
    SELECT
    d.date, 
    x.policy_id
        FROM dates AS d
            CROSS JOIN (
                SELECT policy_id FROM loss_expense UNION 
                SELECT policy_id FROM subro UNION 
                SELECT policy_id FROM reserves UNION
                SELECT policy_id FROM claim_fees UNION 
                SELECT policy_id FROM ibnr
                ) AS x
            JOIN policies AS p
            ON x.policy_id = p.id
                WHERE d.date >= '2016-09-15'
                AND DATEADD(day, 1, d.date) >= p.effective_date
                AND d.date <= DATEADD(year, 3, TO_DATE(COALESCE(p.canceled_date, '2030-12-31')))
    )
    
SELECT 
COALESCE(p.user_id, le.user_id, sb.user_id, re.user_id, cf.user_id, ib.user_id) AS user_id,
COALESCE(udp.policy_id, le.policy_id, sb.policy_id, re.policy_id, cf.policy_id, ib.policy_id) AS policy_id,
COALESCE(udp.date, le.date, sb.date, re.date, cf.date, ib.date) AS date,
COALESCE(le.paid_loss_net,0) AS paid_losses_net,
COALESCE(le.paid_expense_net,0) AS paid_expenses_net,
COALESCE(le.paid_lae_net,0) AS paid_losses_and_expenses_net,
COALESCE(re.reserves_loss,0) AS reserves_losses,
COALESCE(re.reserves_expense,0) AS reserves_expenses,
COALESCE(re.reserves_lae,0) AS reserves_losses_and_expenses,
COALESCE(cf.tpa_fee,0) AS claim_fees_tpa,
COALESCE(cf.adjuster_fee,0) AS claim_fees_adjuster,
COALESCE(cf.lae_total_claim_fees,0) AS lae_total_claim_fees,
COALESCE(sb.net_change_subro,0) AS subro_change_net,
COALESCE(ib.loss_ibnr_est,0) AS loss_ibnr_est,
COALESCE(ib.expense_ibnr_est,0) AS expense_ibnr_est,
COALESCE(ib.total_ibnr_est,0) AS total_ibnr_est,
COALESCE(le.paid_lae_net,0) - COALESCE(sb.net_change_subro,0) + COALESCE(re.reserves_lae,0) + COALESCE(cf.lae_total_claim_fees,0) + COALESCE(ib.total_ibnr_est,0) AS loss_ratio_lae_calc,
TRIM(TRIM(TRIM(REPLACE(CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(CONCAT(COALESCE(le.claim_id,''),', '),COALESCE(sb.claim_id,'')),', '),COALESCE(re.claim_id,'')),', '),COALESCE(cf.claim_id,'')),' ,'),','),' '),',') as claim_ids
    FROM unique_date_policy AS udp
        JOIN policies AS p
        ON p.id = udp.policy_id
        FULL OUTER JOIN loss_expense AS le
        ON (udp.policy_id = le.policy_id
        AND udp.date = le.date)
        FULL OUTER JOIN subro AS sb
        ON (udp.policy_id = sb.policy_id
        AND udp.date = sb.date)
        FULL OUTER JOIN reserves AS re
        ON (udp.policy_id = re.policy_id
        AND udp.date = re.date)
        FULL OUTER JOIN claim_fees AS cf
        ON (udp.policy_id = cf.policy_id
        AND udp.date = cf.date)
        FULL OUTER JOIN ibnr AS ib
        ON (udp.policy_id = ib.policy_id
        AND udp.date = ib.date)
            WHERE (le.paid_lae_net != 0 OR le.paid_expense_net != 0 OR re.reserves_loss != 0 OR re.reserves_expense != 0 OR cf.tpa_fee != 0 OR cf.adjuster_fee != 0 OR sb.net_change_subro != 0);