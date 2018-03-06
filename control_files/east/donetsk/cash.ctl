LOAD	DATA
INTO	TABLE umc_payment_files
APPEND
WHEN	 (55)='3' AND (56)='3'
TRAILING NULLCOLS
	(
	file_id		SEQUENCE(MAX, 1),
	entdate		SYSDATE,
	gl_code		CONSTANT '2062010',
	file_name	POSITION(77:91) --CONSTANT 'AAA'
	)
INTO	TABLE umc_customer_payments
APPEND
WHEN	(7)=':' AND (8)=' '
	(
	file_id		CONSTANT 1,
	line_num	POSITION(03:05) INTEGER EXTERNAL,
	custcode	POSITION(37:46) CHAR,
	phone_number	POSITION(48:73) CHAR TERMINATED BY WHITESPACE,
	amount		POSITION(91:97) "TO_NUMBER( :amount, '99999.99' )"
	)