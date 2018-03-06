CREATE	OR REPLACE
TRIGGER	&owner..bef_ins_umc_cust_pay
BEFORE	INSERT ON aval.umc_customer_payments
FOR	EACH ROW
BEGIN
	:new.file_id := aval_util.file_id;
END;
/

SHOW ERROR
