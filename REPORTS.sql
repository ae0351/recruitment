#RANK ORDER REPORT BY TRANSLATION
DROP TEMPORARY TABLE IF EXISTS translation_rank_count;
CREATE TEMPORARY TABLE translation_rank_count
SELECT `TRANSLATION`,COUNT(`TRANSLATION`) AS 'TRANSLATION_COUNT' FROM 
( 
SELECT * FROM co_offender_charges
LEFT JOIN 
(
SELECT 
	`RECRUITER_PIN` AS 'R_PIN',
 	`NUM_CHARGES` 
FROM recruiter_rank_list
) AS recruiter_rank_list
ON co_offender_charges.`RECRUITER_PIN`=recruiter_rank_list.`R_PIN` 

WHERE recruiter_rank_list.`NUM_CHARGES` >=1 AND recruiter_rank_list.`NUM_CHARGES` <=10000
) AS rank_count
GROUP BY `TRANSLATION`
ORDER BY `NUM_CHARGES` DESC;


SELECT @total := SUM(`TRANSLATION_COUNT`) FROM translation_rank_count ;

DROP TABLE IF EXISTS translation_rank;
CREATE TABLE translation_rank
SELECT * , ((`TRANSLATION_COUNT`)*100)/@total AS '%' FROM translation_rank_count;


#RANK ORDER REPORT BY EXP TRANSLATION
DROP TEMPORARY TABLE IF EXISTS exp_rank_count;
CREATE TEMPORARY TABLE exp_rank_count
SELECT `EXP_TRANSLATION`,COUNT(`EXP_TRANSLATION`) AS 'EXP_TRANSLATION_COUNT' FROM 
( 

SELECT * FROM co_offender_charges
LEFT JOIN 
(
SELECT 
	`RECRUITER_PIN` AS 'R_PIN',
 	`NUM_CHARGES` 
FROM recruiter_rank_list
) AS recruiter_rank_list
ON co_offender_charges.`RECRUITER_PIN`=recruiter_rank_list.`R_PIN` 

WHERE recruiter_rank_list.`NUM_CHARGES` >=1 AND recruiter_rank_list.`NUM_CHARGES` <=10000
) AS rank_count
GROUP BY `EXP_TRANSLATION`
ORDER BY `NUM_CHARGES` DESC;

SELECT @total := SUM(`EXP_TRANSLATION_COUNT`) FROM exp_rank_count ;

DROP TABLE IF EXISTS exp_translation_rank;
CREATE TABLE exp_translation_rank
SELECT * , ((`EXP_TRANSLATION_COUNT`)*100)/@total AS '%' FROM exp_rank_count;






SELECT COUNT(*) FROM 
(
SELECT 
`RECRUITER_PIN`,
COUNT(DISTINCT `OFF_PIN`) AS 'NUM_OFF'
FROM co_offender_charges 
WHERE `TRANSLATION`='ASSAULT          ' 
GROUP BY `RECRUITER_PIN`
ORDER BY `NUM_OFF` DESC
) AS co_offender_charges_translation
WHERE `NUM_OFF`=1;


SELECT 
`RECRUITER_PIN`,
COUNT(DISTINCT `OFF_PIN`) AS 'NUM_OFF'
FROM co_offender_charges 
WHERE `EXP_TRANSLATION`='484 PC PETTY THEFT            '
GROUP BY `RECRUITER_PIN`;