OPTIONS( ROWS=1)
LOAD	DATA
INTO	TABLE umc_payment_files
APPEND
WHEN	 (1)='Õ' AND (2)='å'
TRAILING NULLCOLS
	(
	file_id		SEQUENCE(MAX, 1),
	file_name	POSITION(32:46) CHAR,
	entdate		SYSDATE,
	gl_code		CONSTANT '2262010'
	)
INTO	TABLE umc_customer_payments
APPEND
WHEN	(1)=':' AND (49)!='8' AND (49)!='0' AND (71)!=' ' 
	(
	file_id		CONSTANT 1,
	line_num	POSITION(02:04) INTEGER EXTERNAL,
	custcode	POSITION(27:47) CHAR TERMINATED BY WHITESPACE,
	phone_number	POSITION(49:57) "REPLACE( :phone_number, '-', '' )",
	amount		POSITION(66:72) "TO_NUMBER( :amount, '99999.99' )"
	)