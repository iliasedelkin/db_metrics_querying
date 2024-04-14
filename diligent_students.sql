-- Description: retrieve the number of diligent students with an optimal query

SELECT COUNT(DISTINCT st_id) AS num_diligent
FROM 
	(SELECT 
		MONTH(timest), 
		st_id
	FROM peas
	GROUP BY MONTH(timest), st_id
	HAVING COUNT(correct) >= 20)