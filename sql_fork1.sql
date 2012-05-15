#QUERY #1 DROP THE TABLE IF IT ALREADY EXISTS.
DROP TEMPORARY TABLE IF EXISTS first_offense ;

#QUERY #2
#CREATE A TEMPORARY TABLE OF FIRST OFFENSE DATES FOR EACH PERSON ARRESTED.
CREATE TEMPORARY TABLE first_offense
SELECT 
	DISTINCT rms_arrests.`PIN` AS 'OFF_PIN', 
	MIN(rms_arrests.`DOB`) AS 'OFF_DOB',
	MIN(rms_arrests.`OCC_DATE`) AS 'OFF_OCC_DATE',
	rms_arrests.`GO_KEY` AS 'OFF_GO_KEY'
FROM rms_arrests 
GROUP BY rms_arrests.`PIN`;

#QUERY #3
DROP TEMPORARY TABLE IF EXISTS temp_recruiter ;

# QUERY #4
#CREATE A TABLE FOR JOINING BACK TO THE FIRST OFFENSE TABLE THAT DEALS WITH THE PROBLEM OF MULTIPLE BIRTHDATES FOR SOME INDIVIDUALS.
#THIS CREATES A TABLE OF ALL PERSONS WITH THEIR EARLIEST RECORDED DOB. THIS TABLE WLL BE USED TO MATCH UP THE FIRST OFFENSE DATE FOR
#EACH PERSON ARRESTED WITH A RECRUITER IF THEY WERE NOT ARRESTED ALONE. 
CREATE TEMPORARY TABLE  temp_recruiter
SELECT 
	DISTINCT rms_arrests.`PIN` AS 'RECRUITER_PIN',
	rms_arrests.`GO_KEY` AS 'RECRUITER_GO_KEY',
	MIN(rms_arrests.`DOB`) AS 'RECRUITER_DOB'
FROM rms_arrests 
GROUP BY rms_arrests.`PIN`;

# QUERY #5
DROP TEMPORARY TABLE  IF EXISTS co_offender_instance_no_age;

# QUERY #6
#JOIN THE FIRST OFFENSE TABLE BACK TO ITSELF TO DETERMINE WHO THE RECRUITER WAS FOR EACH NEW OFFENSE IF ANY AND CREATE THE BASE TABLE. 
CREATE TEMPORARY TABLE co_offender_instance_no_age
SELECT * FROM first_offense
LEFT JOIN temp_recruiter
ON 
	temp_recruiter.`RECRUITER_GO_KEY`=first_offense.`OFF_GO_KEY` 
	WHERE first_offense.`OFF_PIN`!=temp_recruiter.`RECRUITER_PIN`
	AND first_offense.`OFF_DOB`>temp_recruiter.`RECRUITER_DOB`
	AND first_offense.`OFF_OCC_DATE`>'2003-01-01';

# QUERY #7
DROP TABLE IF EXISTS co_offender_instance;

# QUERY #8
#THIS IS EACH INSTANCE OF CO-OFFENDING, BY CASE NUMBER. ONE CASE NUMBER=ONE INSTANCE OF CO-OFFENDING IN ORDER TO DETERMINE WHO THE 
#RECUITER IS, AND THE AGE DIFFERENCES BETWEEN THE RECUITER AND THE RECRUIT(CO_OFF).
CREATE TABLE co_offender_instance
SELECT 
	co_offender_instance_no_age.`OFF_PIN`,
	co_offender_instance_no_age.`OFF_DOB`,
	co_offender_instance_no_age.`OFF_OCC_DATE`,
	co_offender_instance_no_age.`OFF_GO_KEY`,
	co_offender_instance_no_age.`RECRUITER_PIN`,
	co_offender_instance_no_age.`RECRUITER_GO_KEY`,
	co_offender_instance_no_age.`RECRUITER_DOB`,
	TIMESTAMPDIFF(DAY,co_offender_instance_no_age.`OFF_DOB`,co_offender_instance_no_age.`RECRUITER_DOB`) AS 'AGE_DIFF_DAYS' ,
	TIMESTAMPDIFF(WEEK,co_offender_instance_no_age.`OFF_DOB`,co_offender_instance_no_age.`RECRUITER_DOB`) AS 'AGE_DIFF_WEEKS',
	TIMESTAMPDIFF(YEAR,co_offender_instance_no_age.`OFF_DOB`,co_offender_instance_no_age.`RECRUITER_DOB`) AS 'AGE_DIFF_YEARS' 
 	FROM  co_offender_instance_no_age;

###################################################################
#EVERYTHING UP TO THIS POINT CREATES THE CO_OFFENDER_INSTANCE TABLE ~23,552 ROWS
###################################################################

DROP TEMPORARY TABLE IF EXISTS temp_two_count; 
CREATE TEMPORARY TABLE temp_two_count
#CREATES A TEMP TABLE THAT STORES THE ARREST GO NUMBER FOR ONLY THOSE ARRESTS
#THAT HAVE ONLY TWO PINS ARRESTED.
SELECT * FROM 
(
SELECT 
rms_arrests.`GO_KEY` AS 'TWO_GO_KEY', 
COUNT(DISTINCT rms_arrests.`PIN`) AS 'PIN_COUNT' 
FROM rms_arrests GROUP BY `GO_KEY`
) AS rms_arrests
WHERE `PIN_COUNT`=2
;

DROP TEMPORARY TABLE IF EXISTS temp_rms_two; 
CREATE TEMPORARY TABLE temp_rms_two
SELECT * FROM rms_arrests
LEFT JOIN temp_two_count
ON temp_two_count.`TWO_GO_KEY`=rms_arrests.`GO_KEY`
WHERE temp_two_count.`PIN_COUNT` IS NOT NULL;










###################################################################
###################################################################
###################################################################
###################################################################

# QUERY #9
DROP TABLE  IF EXISTS rank_list_stat;

# QUERY #10
CREATE TABLE rank_list_stat
SELECT 
	co_offender_instance.`RECRUITER_PIN`,
	COUNT(DISTINCT co_offender_instance.`OFF_PIN`) AS 'NUM_OFFENDERS',
	AVG(co_offender_instance.`AGE_DIFF_DAYS`) AS 'AVG-DAYS',
	MIN(co_offender_instance.`AGE_DIFF_DAYS`) AS 'MIN-DAYS',
	MAX(co_offender_instance.`AGE_DIFF_DAYS`) AS 'MAX-DAYS',
	STDDEV_SAMP(co_offender_instance.`AGE_DIFF_DAYS`) AS 'SD_DAYS',
	(STDDEV_SAMP(co_offender_instance.`AGE_DIFF_DAYS`)/365) AS 'SD-YEARS'
	FROM  co_offender_instance
	GROUP BY `RECRUITER_PIN`;


#QUERY #11
DROP TEMPORARY TABLE IF EXISTS temp_co_offender_list;

#QUERY #12
CREATE TEMPORARY TABLE temp_co_offender_list
SELECT 
`RECRUITER_PIN`,
`PIN` AS 'OFF_PIN',
`OCC_DATE`,
`OFF_DOB`,
 TIMESTAMPDIFF(YEAR,`OCC_DATE`,`OFF_DOB`)AS 'OFF_AGE_AT',
`GO_KEY`,
`CLASS`,
`STATUTE`,
`TRANSLATION`,
`EXP_TRANSLATION`,
`FELONY_MISDEMEANOR`,
`GANG_INVOLVEMENT`
FROM rms_arrests
LEFT JOIN co_offender_instance
ON co_offender_instance.`OFF_GO_KEY`=rms_arrests.`GO_KEY` 
WHERE 
co_offender_instance.`OFF_PIN`=rms_arrests.`PIN`;

#QUERY #13
DROP TABLE IF EXISTS co_offender_data;

#QUERY#14
#THE TEMPORARY CO_OFFENDER_LIST TABLE HAS DUPLICATES. IGNORE THE DUPLICATES AND CREATE A TABLE THAT HAS THE 
#DETAILS FOR EACH OFFENSE, THIS WILL BE THE TABLE THAT THE STATS ARE RUN ON, AND BE THE TRUE BASE TABLE.
CREATE TABLE co_offender_data 
SELECT * FROM temp_co_offender_list
GROUP BY 
	`RECRUITER_PIN`,
	`OFF_PIN`,
	`OCC_DATE`,
	`GO_KEY`,
	`CLASS`,
	`STATUTE`,
	MIN(`OFF_DOB`) AS 'OFF_DOB'
ORDER BY `OFF_PIN`,`RECRUITER_PIN`;


DROP TEMPORARY TABLE IF EXISTS temp_two_count; 
CREATE TEMPORARY TABLE temp_two_count
SELECT * FROM 
(
SELECT 
co_offender_data.`GO_KEY` AS 'TWO_GO_KEY', 
COUNT(DISTINCT co_offender_data.`OFF_PIN`) AS 'PIN_COUNT' 
FROM co_offender_data GROUP BY `GO_KEY`
) AS co_offender_data
WHERE `PIN_COUNT`=2
;

DROP TEMPORARY TABLE IF EXISTS temp_co_offender_data_two; 
CREATE TEMPORARY TABLE temp_co_offender_data_two
SELECT * FROM co_offender_data
LEFT JOIN temp_two_count
ON temp_two_count.`TWO_GO_KEY`=co_offender_data.`GO_KEY`
WHERE temp_two_count.`PIN_COUNT` IS NOT NULL;

DROP TABLE IF EXISTS co_offender_data;
CREATE TABLE co_offender_data
SELECT * FROM temp_co_offender_data_two;



#QUERY #XX
DROP TABLE IF EXISTS  recruiter_rank_list;

# QUERY #XX
#CREATE THE TEMPORARY RANK ORDERED LIST OF CO-OFFENDING PER RECRUITER
CREATE TABLE recruiter_rank_list
SELECT 
`RECRUITER_PIN`,
COUNT(*) AS 'NUM_CHARGES'
FROM co_offender_data
GROUP BY `RECRUITER_PIN`;








