-- Description: The metrics that needed to be calculated were ARPU, ARPAU, Conversion Rate, 
-- CR of Active Users, CR of Users Active in one of the subjects into buying a course 
-- for that subject


-- Prepare subqueries

WITH rev_per_stud AS (
    SELECT 
    	st_id, 
    	SUM(money) AS revenue
    FROM final_project_check
    GROUP BY st_id
	),

active_studs AS (
	SELECT 
		a.st_id AS st_id,
		a.act_status AS act_status,
		b.math_act_status AS math_act_status
	FROM (
		SELECT 
			st_id,
			COUNT(correct) > 10 AS act_status
		FROM peas 
		GROUP BY st_id
		) AS a
	LEFT JOIN (
		SELECT 
			st_id, 
			True AS math_act_status
		FROM peas 
		GROUP BY st_id, subject
		HAVING COUNT(correct) >= 2 AND subject = 'Math'
		) AS b
	ON a.st_id = b.st_id
	),

buying_studs AS (
	SELECT 
		a.st_id AS st_id,
		a.test_grp AS test_grp,
		a.buy_status AS buy_status,
		b.math_buy_status AS math_buy_status
	FROM (
		SELECT 
			p.st_id AS st_id,
			s.test_grp AS test_grp,
			SUM(fpc.money) > 0 AS buy_status
		FROM peas p
		LEFT JOIN studs s ON p.st_id = s.st_id
		LEFT JOIN final_project_check fpc ON p.st_id = fpc.st_id
		GROUP BY p.st_id, s.test_grp
	) AS a
	LEFT JOIN (
		SELECT 
			st_id,
			SUM(money) > 0 AS math_buy_status
		FROM final_project_check
		WHERE subject = 'Math'
		GROUP BY st_id, subject
		) AS b
	ON a.st_id = b.st_id
	),
	
act_buing_studs AS (
	SELECT 
		a.st_id AS st_id,
		a.act_status,
		b.buy_status AS buy_status
	FROM active_studs a 
	JOIN (
		SELECT st_id, test_grp, buy_status
		FROM buying_studs
		) b 
	ON a.st_id = b.st_id
	AND a.act_status = True
	),
	
math_act_buying_studs AS (
	SELECT 
		a.st_id AS st_id,
		a.math_act_status AS act_status,
		b.math_buy_status AS buy_status
	FROM active_studs a 
	JOIN (
		SELECT st_id, test_grp, math_buy_status
		FROM buying_studs
		) b 
	ON a.st_id = b.st_id
	AND a.math_act_status = True
	),

--	Calculate ARPU and ARPAU
	
arpu_table AS (
	SELECT 
		s.test_grp AS test_grp, 
		ROUND(SUM(rps.revenue) / COUNT(DISTINCT s.st_id), 2) AS arpu
	FROM studs s 
	LEFT JOIN rev_per_stud rps ON s.st_id = rps.st_id
	GROUP BY s.test_grp
	),
	
arpau_table AS (
	SELECT 
		s.test_grp AS test_grp, 
		ROUND(SUM(rps.revenue) / SUM(a_s.act_status), 2) AS arpau
	FROM studs s
	LEFT JOIN rev_per_stud rps ON s.st_id = rps.st_id
	LEFT JOIN active_studs a_s ON rps.st_id = a_s.st_id
	GROUP BY s.test_grp
	),
	
--	Calculate 3 variants of CR
	
cr_table AS (
	SELECT 
		a.test_grp AS test_grp,
		ROUND(SUM(a.buy_status) / COUNT(a.st_id) * 100, 1) AS cr_percent,
		ROUND(SUM(b.buy_status) / SUM(b.act_status) * 100, 1) AS act_cr_percent,
		ROUND(SUM(c.buy_status) / SUM(c.act_status) *100, 1) AS math_act_cr_percent
	FROM buying_studs a
	LEFT JOIN act_buing_studs b ON a.st_id = b.st_id
	LEFT JOIN math_act_buying_studs c ON a.st_id = c.st_id
	GROUP BY test_grp
	)
	
--	Join the results together for display with the main query

SELECT 
	a.test_grp AS "Test Group",
	arpu AS ARPU,
	arpau AS ARPAU,
	cr_percent AS "CR (%)",
	act_cr_percent AS "Active CR (%)",
	math_act_cr_percent AS "Math Active CR (%)"
FROM arpu_table a 
JOIN arpau_table b ON a.test_grp = b.test_grp
JOIN cr_table c ON a.test_grp = c.test_grp;