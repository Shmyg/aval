OPTIONS( ROWS=1)
LOAD	DATA
CHARACTERSET RU8PC866
INTO	TABLE umc_payment_files
APPEND
WHEN	 (1)='Í' AND (2)='è'
TRAILING NULLCOLS
	(
	file_id		SEQUENCE(MAX, 1),
	file_name	POSITION(71:85) CHAR,
	entdate		SYSDATE,
	gl_code		CONSTANT '2252010'
	)
INTO	TABLE umc_customer_payments
APPEND
WHEN	(4)!='È' AND (4)!='0' AND (30)!=' ' AND (67)='.'
	(
	file_id		CONSTANT 1,
	line_num	RECNUM,
	custcode	POSITION(35:44) CHAR,
	phone_number	POSITION(49:55) CHAR,
	amount		POSITION(62:69) "TO_NUMBER( :amount, '99999.99' )"
	)