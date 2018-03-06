LOAD	DATA
CHARACTERSET RU8PC866
INTO	TABLE umc_payment_files
APPEND
WHEN	 (8)='Ð' AND (9)='Å'
TRAILING NULLCOLS
	(
	file_id		SEQUENCE(MAX, 1),
	entdate		SYSDATE,
	gl_code		CONSTANT '2042010'
	)
INTO	TABLE umc_customer_payments
APPEND
WHEN	(1)='|' AND (2)!='N'
	(
	file_id		CONSTANT 1,
	line_num	POSITION(03:05) INTEGER EXTERNAL,
	custcode	POSITION(37:46) CHAR,
	phone_number	POSITION(48:56) "REPLACE( :phone_number, '-', '' )",
	amount		POSITION(77:84) "TO_NUMBER( REPLACE(:amount, '''', ''), '99999.99' )"
	)