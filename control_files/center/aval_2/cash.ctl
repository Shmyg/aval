OPTIONS( ROWS=1)
LOAD DATA
CHARACTERSET RU8PC866
INTO TABLE umc_payment_files
APPEND
WHEN (7)='U' AND (11)='3'
TRAILING NULLCOLS
	(
	file_id		SEQUENCE(MAX, 1),
	file_name	POSITION(74:88) CHAR,
	entdate		SYSDATE,
	gl_code		CONSTANT '2012050'
	)
INTO TABLE umc_customer_payments
APPEND
WHEN (1)='|' AND (51)!='0' AND (62)= ' ' AND (7)!=' '
	(
	file_id		CONSTANT '1',
	line_num	POSITION(03:05) INTEGER EXTERNAL,
	custcode	POSITION(28:47) CHAR,
	phone_number	POSITION(54:60) CHAR,
	amount		POSITION(62:71) "TO_NUMBER(:amount, '99999.99')"
	)
