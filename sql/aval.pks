/*
|| Package for payment requests file
|| creation for customers having creadir cards in AVAL
|| and payment loading into BSCS
|| Created by Shmyg
|| Last modified by Shmyg 22.01.2002
*/

/*
Contents:

check_customers - procedure for check correspondence
credit card perfix - BSCS pricegroup and vice versa
CRUD Matrix for check_customers
--+---------------------------------+---+---+---+---+---+----------------------+
--| OBJECT                          |SEL|INS|UPD|DEL|CRE|OTHER                 |
--+---------------------------------+---+---+---+---+---+----------------------+
--| CUSTOMER_ALL                    | X |   |   |   |   |                      |
--+---------------------------------+---+---+---+---+---+----------------------+
--| PRICEGROUP_ALL                  | X |   |   |   |   |                      |
--+---------------------------------+---+---+---+---+---+----------------------+
--| CCONTACT_ALL                    | X |   |   |   |   |                      |
--+---------------------------------+---+---+---+---+---+----------------------+
--| PAYMENT_ALL                     | X |   |   |   |   |                      |
--+---------------------------------+---+---+---+---+---+----------------------+
--| AVAL_CONFIG                     | X |   |   |   |   |                      |
--+---------------------------------+---+---+---+---+---+----------------------+

create_file - function for payment requestsl file creation
CRUD Matrix for create_file
--+---------------------------------+---+---+---+---+---+----------------------+
--| OBJECT                          |SEL|INS|UPD|DEL|CRE|OTHER                 |
--+---------------------------------+---+---+---+---+---+----------------------+
--| AVAL_CONFIG                     | X |   |   |   |   |X                     |
--+---------------------------------+---+---+---+---+---+----------------------+
--| UTL_FILE                        |   |   |   |   |   |X                     |
--+---------------------------------+---+---+---+---+---+----------------------+
--| AVAL_FHDR                       | X | X | X |   |   |                      |
--+---------------------------------+---+---+---+---+---+----------------------+
--| PAYMENT_ALL                     | X |   |   |   |   |                      |
--+---------------------------------+---+---+---+---+---+----------------------+
--| AVAL_FTRAILER                   |   | X |   |   |   |                      |
--+---------------------------------+---+---+---+---+---+----------------------+

get_file - for aval response file loading
Loads customers payments into BSCS
CRUD Matrix for get_file
--+---------------------------------+---+---+---+---+---+----------------------+
--| OBJECT                          |SEL|INS|UPD|DEL|CRE|OTHER                 |
--+---------------------------------+---+---+---+---+---+----------------------+
--| AVAL_FHDR                       | X |   | X |   |   |X                     |
--+---------------------------------+---+---+---+---+---+----------------------+
--| UTL_FILE                        |   |   |   |   |   |X                     |
--+---------------------------------+---+---+---+---+---+----------------------+
--| AVAL_FTRAILER                   | X |   | X |   |   |X                     |
--+---------------------------------+---+---+---+---+---+----------------------+
--| AVAL_CONFIG                     | X |   |   |   |   |X                     |
--+---------------------------------+---+---+---+---+---+----------------------+
--| ORDERHDR_ALL                    | X |   | X |   |   |X                     |
--+---------------------------------+---+---+---+---+---+----------------------+
--| CURRENCY_VERSION                | X |   |   |   |   |                      |
--+---------------------------------+---+---+---+---+---+----------------------+
--| CUSTOMER_ALL                    | X |   | X |   |   |                      |
--+---------------------------------+---+---+---+---+---+----------------------+
--| CASHDETAIL                      |   | X |   |   |   |                      |
--+---------------------------------+---+---+---+---+---+----------------------+

get_file_info - procedure for retreiving info about
requested and paid amount, reasons of errors etc.
CRUD Matrix for get_file_info
--+---------------------------------+---+---+---+---+---+----------------------+
--| OBJECT                          |SEL|INS|UPD|DEL|CRE|OTHER                 |
--+---------------------------------+---+---+---+---+---+----------------------+
--| AVAL_FTRAILER                   | X |   |   |   |   |X                     |
--+---------------------------------+---+---+---+---+---+----------------------+
--| CUSTOMER_ALL                    | X |   |   |   |   |                      |
--+---------------------------------+---+---+---+---+---+----------------------+
--| CCONTACT_ALL                    | X |   |   |   |   |                      |
--+---------------------------------+---+---+---+---+---+----------------------+
--| AVAL_ERRORS                     | X |   |   |   |   |                      |
--+---------------------------------+---+---+---+---+---+----------------------+

fill_customer_payments - procedure to find customer_id for customer who payed
some money. Looks for data inserted in umc_customer_paymentss (custcode and
dn_num) and tries to find corresponding customer_id for every record
*/

CREATE	OR REPLACE
PACKAGE	&owner..aval_interface
AS

-- Record for customer data from file
TYPE	customer_rec_type
IS	RECORD
	(
	line_num	NUMBER,				-- Line number in B-file
	custcode	customer_all.custcode%TYPE,	-- Custcode
	name		VARCHAR2(40),			-- Name
	cardnum		VARCHAR2(16),			-- Card number
	amount		NUMBER,				-- Amount requested
	amount_paid	NUMBER,				-- Amount paid
	err_id		aval_errors.err_id%TYPE,	-- Error ID
	err_desc	aval_errors.err_desc%TYPE,	-- Error description
	status		aval_ftrailer.status%TYPE	-- Status (processed or no)
	);

TYPE	customer_cur_type
IS	REF	CURSOR
RETURN	customer_rec_type;

-- Record with BSCS customer data
TYPE	customer_data_rec_type
IS	RECORD
	(
	custcode	customer_all.custcode%TYPE,	-- Custcode
	customer_name	VARCHAR2(60),			-- Name
	prgname		pricegroup_all.prgname%TYPE,	-- Pricegroup name
	cardnum		VARCHAR2(16)			-- Card number
	);

TYPE	customer_data_cur_type
IS	REF CURSOR
RETURN	customer_data_rec_type;

PROCEDURE	check_customers
	(
	i_report_type	IN VARCHAR2,			-- Report type ('G' - pricegroup, 'C' - card prefix)
	i_prgcode	IN pricegroup_all.prgcode%TYPE,	-- Pricegroup
	o_customer	IN OUT customer_data_cur_type	-- Customers' data
	);

FUNCTION	create_file
	(
	i_pm_id		NUMBER,	-- Payment type ID - MANDATORY
	i_treshold	NUMBER,	-- Treshold - MANDATORY
	i_ubamt		CHAR	-- Flag if we should check unbilled amount
	)
RETURN	NUMBER;

FUNCTION	get_file
	(
	i_finame	IN aval_fhdr.finame%TYPE	-- Filename - MANDATORY
	)
RETURN	NUMBER;

PROCEDURE	get_file_info
	(
	i_file_id	IN NUMBER,	-- Internal file ID - MANDATORY
	o_customer	IN OUT customer_cur_type
	);

PROCEDURE	fill_customer_payments;

END	aval_interface;
/

SHOW ERRORS