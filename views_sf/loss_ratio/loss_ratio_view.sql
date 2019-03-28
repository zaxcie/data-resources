-- Final Loss Ratio Agg Table

SELECT
COALESCE(e.user_id, l.user_id) AS user_id,
COALESCE(e.policy_id, l.policy_id) AS policy_id,
COALESCE(e.date, l.date) AS date,
CASE WHEN e.daily_earned_premium IS NULL THEN 0 ELSE e.daily_earned_premium END AS daily_earned_premium,
CASE WHEN l.loss_ratio_lae_calc IS NULL THEN 0 ELSE l.loss_ratio_lae_calc END AS loss_and_lae,
CASE WHEN e.daily_earned_premium IS NULL THEN 0 ELSE (e.daily_earned_premium * 0.03) END AS allocation_from_the_parent,
CASE WHEN (loss_and_lae + allocation_from_the_parent) IS NULL THEN 0 ELSE (loss_and_lae + allocation_from_the_parent) END AS loss_and_lae_final,
COALESCE(ROUND(1.0 * loss_and_lae / e.daily_earned_premium, 6),0) AS loss_ratio_pct,
COALESCE(l.paid_losses_net,0) AS paid_losses_net,
COALESCE(l.paid_expenses_net,0) AS paid_expenses_net,
COALESCE(l.paid_losses_and_expenses_net,0) AS paid_losses_and_expenses_net,
COALESCE(l.reserves_losses,0) AS reserves_losses,
COALESCE(l.reserves_expenses,0) AS reserves_expenses,
COALESCE(l.reserves_losses_and_expenses,0) AS reserves_losses_and_expenses,
COALESCE(l.claim_fees_tpa,0) AS claim_fees_tpa,
COALESCE(l.claim_fees_adjuster,0) AS claim_fees_adjuster,
COALESCE(l.lae_total_claim_fees,0) AS lae_total_claim_fees,
COALESCE(l.subro_change_net,0) AS subro_change_net,
COALESCE(l.loss_ibnr_est,0) AS loss_ibnr_est,
COALESCE(l.expense_ibnr_est,0) AS expense_ibnr_est,
COALESCE(l.total_ibnr_est,0) AS total_ibnr_est,
l.claim_ids
    FROM daily_earned_premium AS e
        FULL OUTER JOIN daily_lae AS l
        ON (e.policy_id = l.policy_id 
        AND e.date = l.date);