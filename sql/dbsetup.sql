/*
|| Aval schema creation
|| Created by Shmyg
|| Last modfied by Shmyg 14.11.2001
*/

ACCEPT owner  DEFAULT aval PROMPT "Enter new user name [aval]: "
ACCEPT deftsp PROMPT "Enter Default tablespace name: "
ACCEPT tmptsp PROMPT "Enter Temp tablespace name: "
ACCEPT indtsp PROMPT "Enter Index tablespace name: "
ACCEPT dbname PROMPT "Enter source database name: "

-- Preparing connect scripts

SET ECHO OFF
SET FEEDBACK  OFF
SET HEADING  OFF
SET VERIFY  OFF

SPOOL /tmp/ReConnect.sql

SELECT	'connect '||user||'@'||name||';'
FROM	v$database;

SPOOL OFF

SPOOL /tmp/ConnSYSADM.sql

SELECT	'connect SYSADM@'||name||';'
FROM	v$database;

SPOOL OFF

SPOOL /tmp/Conn&owner..sql

SELECT	'connect &owner.@'||name||';'
FROM	v$database;

SPOOL OFF

SPOOL /tmp/ConnREPMAN.sql

SELECT	'connect repman@'||name||';'
FROM	v$database;

SPOOL OFF

SET ECHO ON
SET TIME ON
SET FEEDBACK ON
SET HEADING ON
SET LINESIZE 400
SET PAGESIZE 400
SET TRIMSPOOL ON

spool &owner..log

-- Creating user and roles
CREATE USER &owner
IDENTIFIED BY &owner
DEFAULT TABLESPACE &deftsp
TEMPORARY TABLESPACE &tmptsp
QUOTA 1000M ON &&deftsp
QUOTA 512M ON &&indtsp
/

CREATE ROLE &owner._role
IDENTIFIED BY &owner._role
/

GRANT CREATE SESSION TO &owner.
/
GRANT EXECUTE ON common.umc_util TO &owner
/
GRANT SELECT ON common.customer_address TO &owner
/

/*
|| Creating tables
*/ 

-- Aval_config
CREATE	TABLE &owner..aval_config
	(
	pm_id		NUMBER NOT NULL,
	card_type	VARCHAR2(1) NOT NULL,
	card_prefix	NUMBER NOT NULL,
	glacode		VARCHAR2(30) NOT NULL,
	fbpath		VARCHAR2(40) NOT NULL,
	fipath		VARCHAR2(40) NOT NULL,
	des		VARCHAR2(200) NOT NULL,
	prgcode		VARCHAR2(10) NOT NULL,
	cagldis		VARCHAR2(30),
	cagladv		VARCHAR2(30)
	)
PCTFREE		10
PCTUSED		40
INITRANS	1
MAXTRANS	255
/
COMMENT ON TABLE &owner..aval_config IS 'Configuration table for UMC-AVAL interface'
/
COMMENT ON COLUMN &owner..aval_config.pm_id IS 'Payment model - PK'
/
COMMENT ON COLUMN &owner..aval_config.card_type IS 'Card type'
/
COMMENT ON COLUMN &owner..aval_config.card_prefix IS 'First 8 digits of card number'
/
COMMENT ON COLUMN &owner..aval_config.glacode IS 'GL-code for payments'
/
COMMENT ON COLUMN &owner..aval_config.fbpath IS 'Path on server to put B-files'
/
COMMENT ON COLUMN &owner..aval_config.fipath IS 'Path on server to look for I-files'
/
COMMENT ON COLUMN &owner..aval_config.des IS 'GL-code for payments'
/
COMMENT ON COLUMN &owner..aval_config.prgcode IS 'Pricegroup corresponding to card type'
/
COMMENT ON COLUMN &owner..aval_config.cagldis IS 'GL-code for discounts'
/
COMMENT ON COLUMN &owner..aval_config.glacode IS 'GL-code for advances'
/

-- Aval_errors
CREATE	TABLE &owner..aval_errors
	(
	err_id		VARCHAR2(2) NOT NULL,
	err_desc	VARCHAR2(60) NOT NULL,
	username	VARCHAR2(20) NOT NULL,
	entdate		DATE NOT NULL
	)
PCTFREE		10
PCTUSED		40
INITRANS	1
MAXTRANS	255
/
COMMENT ON TABLE &owner..aval_errors IS 'Possible errors in I-files from AVAL'
/
COMMENT ON COLUMN &owner..aval_errors.err_id IS 'Error id - PK'
/
COMMENT ON COLUMN &owner..aval_errors.err_desc IS 'Error description'
/
COMMENT ON COLUMN &owner..aval_errors.username IS 'Username'
/
COMMENT ON COLUMN &owner..aval_errors.entdate IS 'Entry date'
/

-- Aval_fhdr
CREATE TABLE &owner..aval_fhdr
	(
	file_id		NUMBER NOT NULL,
	pm_id		NUMBER NOT NULL,
	entdate		DATE NOT NULL,
	seq_id		NUMBER NOT NULL,
	fbname		VARCHAR2(12) NOT NULL,
	fbcount		NUMBER NOT NULL,
	fbamount	NUMBER NOT NULL,
	finame		VARCHAR2(12),
	ficount		NUMBER,
	fiamount	NUMBER,
	processed	VARCHAR2(1)
	)
PCTFREE		10
PCTUSED		40
INITRANS	1
MAXTRANS	255
/
COMMENT ON TABLE &owner..aval_fhdr IS 'General info about B-file'
/
COMMENT ON COLUMN &owner..aval_fhdr.file_id IS 'File id - PK'
/
COMMENT ON COLUMN &owner..aval_fhdr.pm_id IS 'Payment model - foreign key to AVAL_CONFIG'
/
COMMENT ON COLUMN &owner..aval_fhdr.entdate IS 'Date of creation'
/
COMMENT ON COLUMN &owner..aval_fhdr.seq_id IS 'Sequence number for files created during one day'
/
COMMENT ON COLUMN &owner..aval_fhdr.fbname IS 'B-file name'
/
COMMENT ON COLUMN &owner..aval_fhdr.fbcount IS 'Number of lines in B-file'
/
COMMENT ON COLUMN &owner..aval_fhdr.fbamount IS 'Amount of money requested in I-file (kopecks)'
/
COMMENT ON COLUMN &owner..aval_fhdr.finame IS 'I-file name'
/
COMMENT ON COLUMN &owner..aval_fhdr.ficount IS 'Number of lines in I-file'
/
COMMENT ON COLUMN &owner..aval_fhdr.fiamount IS 'Amount of money paid in I-file (kopecks)'
/
COMMENT ON COLUMN &owner..aval_fhdr.processed IS 'Flag if I-file is processed'
/

-- Aval_ftrailer
CREATE TABLE &owner..aval_ftrailer
	(
	file_id		NUMBER NOT NULL,
	line_num	NUMBER NOT NULL,
	customer_id	NUMBER NOT NULL,
	cardnum		VARCHAR2(16) NOT NULL,
	amount		NUMBER NOT NULL,
	entdate		DATE NOT NULL,
	amount_paid	NUMBER NOT NULL,
	err_id		VARCHAR2(10),
	status		VARCHAR2(1)
	)
PCTFREE		10
PCTUSED		40
INITRANS	1
MAXTRANS	255
/
COMMENT ON TABLE &owner..aval_ftrailer IS 'Detailed info about B-file'
/
COMMENT ON COLUMN &owner..aval_ftrailer.file_id IS 'File id - PK, FK to aval_ftrailer'
/
COMMENT ON COLUMN &owner..aval_ftrailer.line_num IS 'Line number in file - PK'
/
COMMENT ON COLUMN &owner..aval_ftrailer.customer_id IS 'Customer id'
/
COMMENT ON COLUMN &owner..aval_ftrailer.cardnum IS 'Card number'
/
COMMENT ON COLUMN &owner..aval_ftrailer.amount IS 'Requested in B-file amount (kopecks)'
/
COMMENT ON COLUMN &owner..aval_ftrailer.entdate IS 'Creation date'
/
COMMENT ON COLUMN &owner..aval_ftrailer.amount_paid IS 'Amount paid (kopecks)'
/
COMMENT ON COLUMN &owner..aval_ftrailer.err_id IS 'Error id - FK to AVAL_ERRORS'
/
COMMENT ON COLUMN &owner..aval_ftrailer.status IS 'Flag if customer is processed'
/

@/tmp/ConnSYSADM

GRANT SELECT, REFERENCES, UPDATE ON sysadm.customer_all TO &owner.
/
GRANT REFERENCES ON sysadm.glaccount_all TO &owner.
/
GRANT SELECT ON sysadm.customer_all TO &owner.
/
GRANT SELECT ON sysadm.payment_all TO &owner.
/
GRANT SELECT ON sysadm.mpuubtab TO &owner.
/
GRANT SELECT ON sysadm.currency_version TO &owner.
/
GRANT SELECT ON sysadm.ccontact_all TO &owner.
/
GRANT SELECT, UPDATE, REFERENCES ON sysadm.orderhdr_all TO &owner.
/
GRANT INSERT ON sysadm.cashdetail TO &owner.
/

@/tmp/ReConnect

ALTER TABLE &owner..aval_config
ADD CONSTRAINT pkaval_config PRIMARY KEY (pm_id)
USING INDEX
TABLESPACE &indtsp
PCTFREE    10
INITRANS   2
MAXTRANS   255
/

ALTER TABLE &owner..aval_config
ADD CONSTRAINT fkaval_config_gl FOREIGN KEY (glacode) REFERENCES sysadm.glaccount_all
PCTFREE    10
INITRANS   2
MAXTRANS   255
/

ALTER TABLE &owner..aval_errors
ADD CONSTRAINT pkaval_errors PRIMARY KEY (err_id)
USING INDEX
TABLESPACE &indtsp
PCTFREE    10
INITRANS   2
MAXTRANS   255
/

ALTER TABLE &owner..aval_fhdr
ADD CONSTRAINT pkaval_fhdr PRIMARY KEY (file_id, fbname, finame)
USING INDEX
TABLESPACE &indtsp
PCTFREE    10
INITRANS   2
MAXTRANS   255
/
ALTER TABLE &owner..aval_fhdr
ADD CONSTRAINT fkaval_fhdr_conf FOREIGN KEY (pm_id) REFERENCES &owner..aval_config
PCTFREE    10
INITRANS   2
MAXTRANS   255
/
ALTER TABLE &owner..aval_ftrailer
ADD CONSTRAINT pkaval_ftrailer PRIMARY KEY (file_id, line_num)
USING INDEX
TABLESPACE &indtsp
PCTFREE    10
INITRANS   2
MAXTRANS   255
/

ALTER TABLE &owner..aval_ftrailer
ADD CONSTRAINT fk_ftrailer_fhdr FOREIGN KEY (file_id) REFERENCES &owner..aval_fhdr
PCTFREE    10
INITRANS   2
MAXTRANS   255
/
/*
ALTER TABLE &owner..aval_ftrailer
ADD CONSTRAINT fk_ftrailer_err FOREIGN KEY (err_id) REFERENCES &owner..aval_errors
PCTFREE    10
INITRANS   2
MAXTRANS   255
/
*/
ALTER TABLE &owner..aval_ftrailer
ADD CONSTRAINT fkaval_ftrailer_cust FOREIGN KEY (customer_id) REFERENCES sysadm.customer_all
PCTFREE    10
INITRANS   2
MAXTRANS   255
/

@aval.pks

@aval.pkb

@/tmp/Conn&owner.

GRANT EXECUTE ON &owner..aval_interface TO &owner._role
/
GRANT SELECT ON &owner..aval_fhdr TO &owner._role
/
GRANT SELECT ON &owner..aval_ftrailer TO &owner._role
/
GRANT SELECT ON &owner..aval_config TO &owner._role
/
GRANT SELECT ON &owner..aval_errors TO &owner._role
/

-- 08.11.2002
GRANT UPDATE ON &owner..aval_config TO &owner._role
/
GRANT UPDATE ON &owner..aval_errors TO &owner._role
/

-- Aval config
INSERT	INTO aval_config
VALUES	(
	1,
	'E',
	462775,
	'2013010',
	'/daily/UTL',
	'/daily/UTL',
	'Visa-Electron',
	13,
	NULL,
	NULL
	)
/

INSERT	INTO aval_config
VALUES	(
	2,
	'C',
	462773,
	'2013010',
	'/daily/UTL',
	'/daily/UTL',
	'Visa-Classic',
	12,
	NULL,
	NULL
	)
/

INSERT	INTO aval_config
VALUES	(
	3,
	'G',
	462774,
	'2013010',
	'/daily/UTL',
	'/daily/UTL',
	'Visa-Gold',
	11,
	NULL,
	NULL
	)
/

-- Aval errors
INSERT	INTO aval_errors
	(
	err_id,
	err_desc,
	username,
	entdate
	)
VALUES	(
	'01',
	'Credit card number is invalid',
	USER,
	SYSDATE
	)
/

INSERT	INTO aval_errors
	(
	err_id,
	err_desc,
	username,
	entdate
	)
VALUES	(
	'02',
	'Not enough money',
	USER,
	SYSDATE
	)
/
INSERT	INTO aval_errors
	(
	err_id,
	err_desc,
	username,
	entdate
	)
VALUES	(
	'03',
	'Card is in stop-list',
	USER,
	SYSDATE
	)
/

INSERT	INTO aval_errors
	(
	err_id,
	err_desc,
	username,
	entdate
	)
VALUES	(
	'04',
	'Not enaough money to pay next bill',
	USER,
	SYSDATE
	)
/

INSERT	INTO aval_errors
	(
	err_id,
	err_desc,
	username,
	entdate
	)
VALUES	(
	'05',
	'Account is closed',
	USER,
	SYSDATE
	)
/

INSERT	INTO aval_errors
	(
	err_id,
	err_desc,
	username,
	entdate
	)
VALUES	(
	'06',
	'Credit card expired',
	USER,
	SYSDATE
	)
/

@/tmp/ConnREPMAN

GRANT SELECT ON repman.rep_config TO &owner.
/
GRANT SELECT ON repman.rep_config TO &owner._role
/

INSERT	INTO rep_roles
	(
	role_name,
	role_passwd,
	des,
	username,
	entdate
	)
VALUES	(
	'AVAL_ROLE',
	'AVAL_ROLE',
	'Роль для інтерфейсу УМЗ-Аваль',
	USER,
	SYSDATE
	)
/

INSERT	INTO reports
	(
	report_id,
	report_name,
	report_type,
	report_module,
	report_role,
	entdate,
	entuser,
	des
	)
SELECT	MAX( report_id ) + 1,
	'Перегляд файлів інтерфейсу УМЗ-Аваль',
	'REPORT',
	'AVAL_FILE_INFO',
	'AVAL_ROLE',
	SYSDATE,
	USER,
	'Звіт для перегляду файлів інтерфейсу УМЗ-Аваль'
FROM	reports
/

INSERT	INTO reports
	(
	report_id,
	report_name,
	report_type,
	report_module,
	report_role,
	entdate,
	entuser,
	des
	)
SELECT	MAX( report_id ) + 1,
	'Перегляд даних абонентів УМЗ-Аваль',
	'REPORT',
	'AVAL_CUSTOMER_CHECK',
	'AVAL_ROLE',
	SYSDATE,
	USER,
	'Звіт для перегляду відповідності номерів кредитних карток ціновій групі'
FROM	reports
/

@errors.sql

@/tmp/ReConnect

REVOKE CREATE SESSION FROM &owner.
/

SPOOL OFF
SET ECHO OFF
SET TIME OFF

!rm -f /tmp/ReConnect.sql
!rm -f /tmp/ConnSYSADM.sql
!rm -f /tmp/Conn&owner..sql
!rm -f /tmp/ConnREPMAN.sql


UNDEFINE DBNAME
UNDEFINE OWNER
UNDEFINE DEFTSP
UNDEFINE TMPTSP
UNDEFINE INDTSP