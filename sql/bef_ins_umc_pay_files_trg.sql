CREATE	OR REPLACE
TRIGGER	&owner..bef_ins_umc_pay_files
BEFORE	INSERT ON aval.umc_payment_files
FOR	EACH ROW
BEGIN
	aval_util.file_id := :new.file_id;
END;
/

SHOW ERROR