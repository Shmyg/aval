-- Added 26.11.2003
CREATE	TABLE &owner..file_statuses
	(
	file_status	VARCHAR2(2) NOT NULL,
	description	VARCHAR2(40) NOT NULL,
	CONSTRAINT	pkfile_statuses
	PRIMARY	KEY ( file_status )
	)
PCTFREE    5
PCTUSED    40
INITRANS   1
MAXTRANS   255
/

COMMENT	ON TABLE &owner..file_statuses IS 'Autopayment file statuses'
/

INSERT	INTO &owner..file_statuses
VALUES	(
	'00',
	'Just loaded'
	)
/

INSERT	INTO &owner..file_statuses
VALUES	(
	'01',
	'Checked'
	)
/

INSERT	INTO &owner..file_statuses
VALUES	(
	'02',
	'Processed'
	)
/

INSERT	INTO &owner..file_statuses
VALUES	(
	'10',
	'Duplicate file'
	)
/

CREATE	TABLE &owner..umc_payment_files
	(
	file_id		NUMBER NOT NULL,
	file_name	VARCHAR(15) NOT NULL,
	entdate		DATE NOT NULL,
	gl_code		VARCHAR2(30) NOT NULL,
	file_status	VARCHAR2(2) NOT NULL DEFAULT '00',
	CONSTRAINT	pk_umc_pay_files
	PRIMARY	KEY ( file_id ),
	CONSTRAINT	fk_file_status
	FOREIGN	KEY ( file_status )
	REFERENCES	file_statuses
	)
PCTFREE    5
PCTUSED    40
INITRANS   1
MAXTRANS   255
/

COMMENT ON TABLE &owner..umc_payment_files
IS	'Autopayment files'
/

COMMENT ON COLUMN &owner..umc_payment_files.file_id
IS	'File ID - PK'
/

COMMENT ON COLUMN &owner..umc_payment_files.file_status
IS	'Current status - FK to FILE_STATUSES'
/

CREATE	TABLE &owner..umc_customer_payments
	(
	file_id		NUMBER NOT NULL,
	line_num	NUMBER NOT NULL,
	amount		NUMBER NOT NULL,
	phone_number	VARCHAR2(7),
	custcode	VARCHAR2(24),
	customer_id	NUMBER,
	processed	VARCHAR2(1),
	err_message	VARCHAR2(200)
	CONSTRAINT	pk_umc_cust_pay
	PRIMARY	KEY ( file_id, line_num )
	)
PCTFREE    10
PCTUSED    40
INITRANS   1
MAXTRANS   255
/


ALTER	TABLE &owner..umc_customer_payments
ADD	CONSTRAINT fk_file_id
FOREIGN	KEY ( file_id )
REFERENCES	&owner..umc_payment_files ( file_id )
/

GRANT	EXECUTE ON donor.payment_t TO &owner.
/
GRANT	EXECUTE ON donor.cashdetail_tab TO &owner.
/
GRANT	EXECUTE ON donor.order_t TO &owner.
/
GRANT	EXECUTE ON donor.order_tab TO &owner.
/
