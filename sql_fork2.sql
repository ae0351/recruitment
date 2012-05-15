#####################################
#THE ORIGINAL UNMODIFIED RMS_ARRESTS TABLE ~349,345 ROWS.
#COUNTING THE NUMBER OF GO'S WITH TWO CO-OFFENDERS ~12,452 ROWS.
#AFTER JOINING THIS (~12K) WITH THE ORIGINAL RMS_ARRESTS TABLE ~ ROWS. 
#####################################


#####################################

# QUERY #1
DROP TEMPORARY TABLE IF EXISTS go_key_count;

# QUERY #2
#CREATE THE TEMPORARY TABLE THAT WILL LIST ALL GO_KEYS WITH THE TOTAL NUMBER OF 
#OFFENDERS PER, BY PIN.
CREATE TEMPORARY TABLE go_key_count
SELECT rms_arrests_org.`GO_KEY` AS 'TWO_GO_KEY', COUNT(DISTINCT rms_arrests_org.`PIN`) AS 'PIN_COUNT' FROM rms_arrests_org GROUP BY `GO_KEY`;
#####################################

# QUERY #3
DROP TEMPORARY TABLE IF EXISTS two_off_go;

# QUERY #4
#CREATE THE TABLE THAT LISTS JUST THE GO_KEYS WITH ONLY TWO PERSONS INVOLVED.
CREATE TEMPORARY TABLE two_off_go
SELECT * FROM go_key_count WHERE go_key_count.`PIN_COUNT` =2;
#####################################

# QUERY #5
DROP TABLE IF EXISTS rms_arrests;

# QUERY #6
#JOIN THE PREVIOUS TABLE TOGETHER WITH THE RMS_ARRESTS_ORG TABLE TO GET DETAILS FOR ALL 
#CRIMES WITH JUST TWO PERSONS ARRESTED. ADJUST DATES AS NECESSARY.
CREATE TABLE rms_arrests
SELECT * FROM rms_arrests_org,two_off_go
WHERE rms_arrests_org.`GO_KEY`=two_off_go.`TWO_GO_KEY`;
#####################################

#CLEAN UP THE TABLES THAT HAVE BEEN CREATED SO FOR. REMOVE REDUNDANT COLUMN NAMES.
# QUERY #7
#REMOVE THE PIN COUNT COLUMN FROM THE RMS_ARRESTS TABLE
ALTER TABLE rms_arrests DROP COLUMN `PIN_COUNT`;

# QUERY #8
#REMOVE THE REDUNDANT GO KEY FROM THE RMS_ARRESTS TABLE
ALTER TABLE rms_arrests DROP COLUMN `TWO_GO_KEY`;
#####################################

# QUERY #9
DROP TEMPORARY TABLE IF EXISTS temp_arrests_list;

# QUERY #10
#THIS WILL CREATE AN RMS_ARRESTS TABLE WITH THE PROPER DOB FOR EVERY PIN IN THE TABLE.
CREATE TEMPORARY TABLE temp_arrests_list 
SELECT * FROM 
(
SELECT `PIN` AS 'CON_PIN',MIN(`DOB`) AS 'MIN_DOB' 
FROM rms_arrests
GROUP BY `CON_PIN` 
)AS min_dob_table
RIGHT JOIN rms_arrests
ON
min_dob_table.`CON_PIN`=rms_arrests.`PIN`;

#####################################

# QUERY #11
DROP TEMPORARY TABLE IF EXISTS temp_arrests;

# QUERY #12
CREATE TEMPORARY TABLE temp_arrests
SELECT * FROM temp_arrests_list;
#####################################

# QUERY #13
ALTER TABLE temp_arrests DROP COLUMN `DOB`;

# QUERY #14
ALTER TABLE temp_arrests DROP COLUMN `CON_PIN`;

# QUERY #15
ALTER TABLE temp_arrests CHANGE `MIN_DOB` `DOB` date;

#####################################

# QUERY #16
DROP TABLE rms_arrests;

# QUERY #17
CREATE TABLE rms_arrests
SELECT * FROM temp_arrests
GROUP BY
	`DOB`,
	`PIN`,
	`XREF`,
	`GO_KEY`,
	`CLASS`,
	`STATUTE`;

# QUERY #18
DROP TEMPORARY TABLE temp_arrests;

#####################################

# QUERY #19 DROP THE TABLE IF IT ALREADY EXISTS.
DROP TABLE IF EXISTS temp_first_offense ;

# QUERY #20
#CREATE A TEMPORARY TABLE OF FIRST OFFENSE DATES FOR EACH PERSON ARRESTED.
CREATE TABLE temp_offender
SELECT 
	DISTINCT rms_arrests.`PIN` AS 'OFF_PIN', 
	rms_arrests.`DOB` AS 'OFF_DOB',
	MIN(rms_arrests.`OCC_DATE`) AS 'OFF_OCC_DATE',
	rms_arrests.`GO_KEY` AS 'OFF_GO_KEY'
FROM rms_arrests 
GROUP BY rms_arrests.`PIN`;


# QUERY #21
DROP TABLE IF EXISTS temp_recruiter ;

# QUERY #22
CREATE TABLE  temp_recruiter
SELECT 
	DISTINCT rms_arrests.`PIN` AS 'RECRUITER_PIN', 
	rms_arrests.`DOB` AS 'RECRUITER_DOB',
	MIN(rms_arrests.`OCC_DATE`) AS 'RECRUITER_OCC_DATE',
	rms_arrests.`GO_KEY` AS 'RECRUITER_GO_KEY'
FROM rms_arrests 
GROUP BY rms_arrests.`PIN`;

# QUERY #23
DROP TABLE  IF EXISTS temp_co_offender_instance_no_age;

# QUERY #24
#JOIN THE FIRST OFFENSE TABLE BACK TO ITSELF TO DETERMINE WHO THE RECRUITER WAS FOR EACH NEW OFFENSE IF ANY AND CREATE THE BASE TABLE. 
CREATE TABLE temp_co_offender_instance_no_age
SELECT * FROM temp_offender
LEFT JOIN temp_recruiter
ON 
	temp_recruiter.`RECRUITER_GO_KEY`=temp_offender.`OFF_GO_KEY` 
	WHERE temp_offender.`OFF_PIN`!=temp_recruiter.`RECRUITER_PIN`
	AND temp_offender.`OFF_DOB`>temp_recruiter.`RECRUITER_DOB`;
	#AND temp_recruiter.`RECRUITER_OCC_DATE`<temp_offender.`OFF_OCC_DATE`;

# QUERY #25
DROP TABLE IF EXISTS co_offender_instance;

# QUERY #26
#THIS IS EACH INSTANCE OF CO-OFFENDING, BY CASE NUMBER. ONE CASE NUMBER=ONE INSTANCE OF CO-OFFENDING IN ORDER TO DETERMINE WHO THE 
#RECRUITER IS, AND THE AGE DIFFERENCES BETWEEN THE RECUITER AND THE RECRUIT(CO_OFF).
CREATE TABLE co_offender_instance
SELECT 
	temp_co_offender_instance_no_age.`OFF_PIN`,
	temp_co_offender_instance_no_age.`OFF_DOB`,
	temp_co_offender_instance_no_age.`OFF_OCC_DATE`,
	temp_co_offender_instance_no_age.`OFF_GO_KEY`,
	temp_co_offender_instance_no_age.`RECRUITER_PIN`,
	temp_co_offender_instance_no_age.`RECRUITER_GO_KEY`,
	temp_co_offender_instance_no_age.`RECRUITER_DOB`,
	TIMESTAMPDIFF(DAY,temp_co_offender_instance_no_age.`OFF_DOB`,temp_co_offender_instance_no_age.`RECRUITER_DOB`) AS 'AGE_DIFF_DAYS' ,
	TIMESTAMPDIFF(WEEK,temp_co_offender_instance_no_age.`OFF_DOB`,temp_co_offender_instance_no_age.`RECRUITER_DOB`) AS 'AGE_DIFF_WEEKS',
	TIMESTAMPDIFF(YEAR,temp_co_offender_instance_no_age.`OFF_DOB`,temp_co_offender_instance_no_age.`RECRUITER_DOB`) AS 'AGE_DIFF_YEARS' 
 	FROM  temp_co_offender_instance_no_age;

# QUERY #27
DROP TABLE  IF EXISTS rank_list_stat;

# QUERY #28
CREATE TABLE rank_list_stat
SELECT 
	co_offender_instance.`RECRUITER_PIN`,
	COUNT(*) AS 'INSTANCES OF CO-OFFENDING',
	AVG(co_offender_instance.`AGE_DIFF_DAYS`) AS 'AVG-DAYS',
	MIN(co_offender_instance.`AGE_DIFF_DAYS`) AS 'MIN-DAYS',
	MAX(co_offender_instance.`AGE_DIFF_DAYS`) AS 'MAX-DAYS',
	STDDEV_SAMP(co_offender_instance.`AGE_DIFF_DAYS`) AS 'SD_DAYS',
	(STDDEV_SAMP(co_offender_instance.`AGE_DIFF_DAYS`)/365) AS 'SD-YEARS'
	FROM  co_offender_instance
	GROUP BY `RECRUITER_PIN`;

# QUERY #29
DROP TABLE IF EXISTS co_offender_data;

# QUERY #30
CREATE TABLE co_offender_data
SELECT 
`RECRUITER_PIN`,
`PIN` AS 'OFF_PIN',
`OCC_DATE`,
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



# QUERY #31
#CREATE THE TEMPORARY RANK ORDERED LIST OF CO-OFFENDING PER RECRUITER
DROP TABLE IF EXISTS  recruiter_rank_list;

# QUERY #32
CREATE TABLE recruiter_rank_list
SELECT 
`RECRUITER_PIN`,
COUNT(*) AS 'NUMBER OF RECRUITS'
FROM co_offender_data 
GROUP BY `RECRUITER_PIN`;