CREATE OR REPLACE PACKAGE BODY &owner..aval_interface
AS

	g_entdate	CONSTANT DATE := TRUNC( SYSDATE );
	g_payment_type	CONSTANT NUMBER := -4;	-- payment type corresponding to credit card in BSCS

PROCEDURE	check_customers
	(
	i_report_type	IN VARCHAR2,
	i_prgcode	IN pricegroup_all.prgcode%TYPE,
	o_customer	IN OUT customer_data_cur_type
	)
IS
BEGIN
	IF	i_report_type = 'G'
	THEN
		OPEN	o_customer
		FOR
		SELECT	/*+ RULE */ ca.custcode,
			SUBSTR( cc.cclname || cc.ccfname, 1, 60 ),
			pg.prgname,
			pt.bankaccno
		FROM	customer_all	ca,
			payment_all	pt,
			pricegroup_all	pg,
			ccontact_all	cc,
			aval.aval_config	ac
		WHERE	ca.customer_id = pt.customer_id
		AND	ac.prgcode = ca.prgcode
		AND	pg.prgcode = ca.prgcode
		AND	cc.customer_id = ca.customer_id
		AND	ca.prgcode = i_prgcode
		AND	SUBSTR( pt.bankaccno, 1, 6 ) != ac.card_prefix
		AND	cc.ccseq = 
			(
			SELECT	MAX( ccseq )
			FROM	ccontact_all
			WHERE	customer_id = cc.customer_id
			AND	cccontract = 'X'
			)
		AND	pt.seq_id =
			(
			SELECT	MAX( seq_id )
			FROM	payment_all
			WHERE	customer_id = pt.customer_id
			);
	ELSE
		OPEN	o_customer
		FOR
		SELECT	/*+ INDEX(ca FKIFKIPGPGC) */ ca.custcode,
			SUBSTR( cc.cclname || cc.ccfname, 1, 60 ),
			pg.prgname,
			pt.bankaccno
		FROM	customer_all	ca,
			payment_all	pt,
			pricegroup_all	pg,
			ccontact_all	cc,
			aval.aval_config	ac
		WHERE	ca.customer_id = pt.customer_id
		AND	ac.prgcode = i_prgcode
		AND	pg.prgcode = ca.prgcode
		AND	cc.customer_id = ca.customer_id
		AND	ca.prgcode != i_prgcode
		AND	SUBSTR( pt.bankaccno, 1, 6 ) = ac.card_prefix
		AND	cc.ccseq = 
			(
			SELECT	MAX( ccseq )
			FROM	ccontact_all
			WHERE	customer_id = cc.customer_id
			AND	cccontract = 'X'
			)
		AND	pt.seq_id =
			(
			SELECT	MAX( seq_id )
			FROM	payment_all
			WHERE	customer_id = pt.customer_id
			);
	END	IF;

END	check_customers;

FUNCTION	create_file
	(
	i_pm_id		NUMBER,
	i_treshold	NUMBER,
	i_ubamt		CHAR	-- flag if we should take in care unbilled amount, obsolete - not used
	)
RETURN	NUMBER
IS

	-- Cursor for configuration data
	CURSOR	conf_cur
		(
		p_pm_id	NUMBER
		)
	IS
	SELECT	card_type,
		card_prefix,
		fbpath,
		fipath,
		prgcode
	FROM	aval_config
	WHERE	pm_id = p_pm_id;

	-- Cursor for customers who pay by credit card	
	CURSOR	customer_cur
		(
		p_card_prefix	VARCHAR2,
		p_prgcode	NUMBER
		)
	IS
	SELECT	ca.customer_id,
		pt.bankaccno
	FROM	customer_all	ca,
		payment_all	pt
	WHERE	pt.customer_id = ca.customer_id
	AND	pt.payment_type = g_payment_type
	AND	ca.prgcode = p_prgcode
	AND	SUBSTR( pt.bankaccno, 1, 6 ) = p_card_prefix
	AND	pt.seq_id =
		(
		SELECT	MAX( seq_id )
		FROM	payment_all
		WHERE	customer_id = pt.customer_id
		)
	GROUP	BY ca.customer_id,
		pt.bankaccno;

	TYPE	customer_rec_type
	IS	RECORD
		(
		customer_id	NUMBER,
		cardnum		VARCHAR2(16),
		amount		NUMBER
		);

	customer_rec	customer_rec_type;

	TYPE	customer_tab_type
	IS	TABLE
	OF	customer_rec_type
	INDEX	BY BINARY_INTEGER;

	customer_tab	customer_tab_type;

	CURSOR	ohopnamt_cur
		(
		p_customer_id	NUMBER
		)
	IS
	SELECT	NVL( SUM( ohopnamt_gl ), 0 )
	FROM	orderhdr_all
	WHERE	customer_id = p_customer_id;

	v_filename	VARCHAR2(12);
	v_file_id	NUMBER;
	v_seq_id	NUMBER;
	v_card_type	aval_config.card_type%TYPE;
	v_card_prefix	aval_config.card_prefix%TYPE;
	v_fbpath	aval_config.fbpath%TYPE;
	v_fipath	aval_config.fipath%TYPE;
	v_prgcode	aval_config.prgcode%TYPE;
	i		NUMBER := 1;	-- counter
	v_file_handler	UTL_FILE.FILE_TYPE;
	v_string	VARCHAR2(100);	-- string to insert into file
	v_total		NUMBER := 0;	-- total amount per file
	v_sqlcode	NUMBER;
	v_command	NUMBER := 1;	-- pointer to failed query if any

	wrong_payment_type	EXCEPTION;
	no_customers_found	EXCEPTION;

BEGIN

	SAVEPOINT	create_file_start;

	-- Looking for configuration data
	OPEN	conf_cur ( i_pm_id );

		FETCH	conf_cur
		INTO	v_card_type,
			v_card_prefix,
			v_fbpath,
			v_fipath,
			v_prgcode;

		IF	conf_cur%NOTFOUND
		THEN
			RAISE	wrong_payment_type;
		END	IF;

	CLOSE	conf_cur;

	-- Creating file name
	-- Looking for files with same card type created during current day
	SELECT	NVL( COUNT(*), 0 ) + 1
	INTO	v_seq_id
	FROM	aval_fhdr
	WHERE	pm_id = i_pm_id
	AND	entdate = g_entdate;

	v_filename := 'B' || v_card_type || TO_CHAR( g_entdate , 'Y' ) ||
		TO_CHAR( g_entdate, 'DDD' ) || LPAD( v_seq_id, 2, 0 ) || '.UMC';

	-- Inserting file data in header table
	-- Looking for file id
	SELECT	NVL (MAX (file_id), 0) + 1
	INTO	v_file_id
	FROM	aval_fhdr;

	INSERT	INTO aval_fhdr
		(
		file_id,
		pm_id,
		entdate,
		seq_id,
		fbname,
		fbcount,
		fbamount,
		finame,
		ficount,
		fiamount,
		processed
		)
	VALUES	(
		v_file_id,
		i_pm_id,
		g_entdate,
		v_seq_id,
		v_filename,
		0,
		0,
		REPLACE ( v_filename, 'B', 'I' ),	-- response file name
		0,
		0,
		NULL
		);

	dbms_application_info.set_module( 'Aval', 'Looking for customers' );

	-- Looking for data
	OPEN	customer_cur
		(
		v_card_prefix,
		v_prgcode
		);

	-- Filling PL/SQL table with data
	LOOP
		
		FETCH	customer_cur
		INTO	customer_rec.customer_id,
			customer_rec.cardnum;

		EXIT	WHEN customer_cur%NOTFOUND;

		OPEN	ohopnamt_cur
			(
			customer_rec.customer_id
			);

			FETCH	ohopnamt_cur
			INTO	customer_rec.amount;

		CLOSE	ohopnamt_cur;

		-- For 'Electron' cards we should check unbilled amount
		IF	i_pm_id = 1
		THEN
			customer_rec.amount := customer_rec.amount +
				common.umc_util.get_unbilled_amount
					( customer_rec.customer_id );
		END	IF;

		IF	customer_rec.amount >= i_treshold
		THEN
			-- Customer exceeded treshold
			customer_tab(i).customer_id := customer_rec.customer_id;
			customer_tab(i).amount := customer_rec.amount * 100;
			customer_tab(i).cardnum := customer_rec.cardnum;
			i := i + 1;
		END	IF;

	END	LOOP;

	IF	customer_tab.COUNT = 0
	THEN
		RAISE	no_customers_found;
	END	IF;

	i := 1;

	-- Inserting data into trailer table
	FOR	i IN customer_tab.FIRST..customer_tab.COUNT
	LOOP
		INSERT	INTO aval_ftrailer
			(
			file_id,
			line_num,
			customer_id,
			cardnum,
			amount,
			entdate,
			amount_paid,
			err_id,
			status
			)
		VALUES	(
			v_file_id,
			i,
			customer_tab(i).customer_id,
			customer_tab(i).cardnum,
			customer_tab(i).amount,
			g_entdate,
			0,
			0,
			NULL
			);
	END	LOOP;

	dbms_application_info.set_module( 'Aval', 'Writing to file' );

	-- Writing data to the file
	-- Opening
	v_file_handler := UTL_FILE.FOPEN (v_fbpath, v_filename, 'w');

	-- Header
	v_string := LOWER (v_filename) || ':' || customer_tab.COUNT || ';';
	UTL_FILE.PUT_LINE (v_file_handler, v_string);

	i := 1;

	-- Data
	FOR	i IN customer_tab.FIRST..customer_tab.COUNT
	LOOP

		v_string := i || ':' || customer_tab(i).cardnum || ':' ||
			customer_tab(i).amount || ':' ||
			TO_CHAR (g_entdate, 'DDMMYYYY') || ';';

		v_total := v_total + customer_tab(i).amount;

		UTL_FILE.PUT_LINE(v_file_handler, v_string);

	END	LOOP;

	-- Footer
	v_string := LOWER (v_filename) || ':' || v_total || ':' || 'control_group;';
	UTL_FILE.PUT_LINE(v_file_handler, v_string);

	-- Closing
	UTL_FILE.FCLOSE(v_file_handler);
	
	-- Inserting summary data
	i := customer_tab.COUNT;

	UPDATE	aval_fhdr
	SET	fbcount = i,
		fbamount = v_total
	WHERE	file_id = v_file_id;

	-- Cleaning
	customer_tab.DELETE;
	CLOSE	customer_cur;
	
	COMMIT;
	RETURN	0;

EXCEPTION
	WHEN	wrong_payment_type
	THEN
		ROLLBACK TO create_file_start;
		RETURN	-1;
	WHEN	no_customers_found
	THEN
		ROLLBACK TO create_file_start;
		RETURN	0;
	WHEN	OTHERS
	THEN
		ROLLBACK TO create_file_start;
		RETURN	SQLCODE;
END	create_file;

FUNCTION	get_file
	(
	i_finame	aval_fhdr.finame%TYPE
	)
RETURN	NUMBER
IS
	
	v_file_handler	UTL_FILE.FILE_TYPE;
	v_string	VARCHAR2(100);
	v_ficount	NUMBER;
	v_customer_id	aval_ftrailer.customer_id%TYPE;
	v_payment_currency	NUMBER;
	v_caxact	NUMBER;
	v_ohxact	NUMBER;
	v_line_num	NUMBER;
	v_cardnum	aval_ftrailer.cardnum%TYPE;
	v_fiamount	NUMBER;
	i		BINARY_INTEGER;	-- counter

	g_entdate	CONSTANT DATE := SYSDATE;

	conf_rec	aval_config%ROWTYPE;
	fhdr_rec	aval_fhdr%ROWTYPE;

	-- Cursor for requested money
	CURSOR	cash_cur IS
	SELECT	line_num,
		customer_id,
		cardnum,
		amount/100 amount, -- here we have amount in copecks!
		status
	FROM	aval_ftrailer
	WHERE	file_id =
		(
		SELECT	file_id
		FROM	aval_fhdr
		WHERE	finame = i_finame
		)
	ORDER	BY line_num
	FOR	UPDATE OF status;

	cash_rec	cash_cur%ROWTYPE;

	-- Cursor for customer's orders
	CURSOR	ohxact_cur IS
	SELECT	ohxact,
		ohopnamt_gl,
		ohopnamt_doc,
		ohglar
	FROM	orderhdr_all
	WHERE	customer_id = cash_rec.customer_id
	AND	ohstatus = 'IN'
	AND	ohinvtype IN ( 5, 8 )
	AND	ohopnamt_gl > 0
	ORDER	BY ohxact
	FOR	UPDATE OF ohopnamt_gl,
		ohopnamt_doc;
	
	ohxact_rec	ohxact_cur%ROWTYPE;

	TYPE	customer_rec_type
	IS	RECORD
		(
		line_num	NUMBER,
		cardnum		aval_ftrailer.cardnum%TYPE,
		amount		NUMBER,
		err_id		VARCHAR2(2)
		);

	customer_rec	customer_rec_type;
	
	-- Table with data received from bank
	TYPE	customer_tab_type
	IS	TABLE
	OF	customer_rec_type
	INDEX	BY BINARY_INTEGER;

	customer_tab	customer_tab_type;

	wrong_filename	EXCEPTION;
	wrong_count	EXCEPTION;
	cash_insert_failure	EXCEPTION;
	check_failure	EXCEPTION;
	not_equal_amounts	EXCEPTION;
	file_processed	EXCEPTION;

BEGIN

	-- Looking for file data
	SELECT	*
	INTO	fhdr_rec
	FROM	aval_fhdr
	WHERE	finame = i_finame
	FOR	UPDATE OF processed;

	-- Checking if the file haven't been loaded earlier
	IF	fhdr_rec.processed = 'X'
	THEN
		RAISE	file_processed;
	END	IF;

	-- Looking for configuration data
	SELECT	*
	INTO	conf_rec
	FROM	aval_config
	WHERE	card_type = SUBSTR( i_finame, 2, 1 );

	dbms_application_info.set_module ( 'Aval', 'Reading file');

	-- Reading data from the file
	-- Opening
	v_file_handler := UTL_FILE.FOPEN (conf_rec.fipath, i_finame, 'r');

	-- Header
	UTL_FILE.GET_LINE (v_file_handler, v_string);

	v_ficount :=	SUBSTR	(
				v_string,
				INSTR( v_string, ':', 1, 1 ) + 1, 
				INSTR( v_string, ';', 1) - (INSTR ( v_string, ':', 1, 1 ) + 1)
				);

	-- Checking header
	IF	LOWER( fhdr_rec.finame ) != SUBSTR (
						v_string,
						1,
						INSTR( v_string, ':', 1, 1) - 1
						)
	THEN
		RAISE	wrong_filename;
	END	IF;
	
	-- Retreiving data and placing it into PL/SQL table
	FOR	i IN 1..v_ficount
	LOOP
		UTL_FILE.GET_LINE (v_file_handler, v_string);
		v_line_num := TO_NUMBER	(
					SUBSTR	(
						v_string,
						1,
						INSTR( v_string, ':', 1, 1) - 1
						)
					);
		customer_tab(v_line_num).cardnum := SUBSTR	(
							v_string,
							INSTR( v_string, ':', 1, 1) + 1,
							INSTR( v_string, ':', 1, 2) - INSTR( v_string, ':', 1, 1) - 1
							);
		customer_tab(v_line_num).amount := TO_NUMBER	(
							SUBSTR	(
								v_string,
								INSTR( v_string, ':', 1, 2) + 1,
								INSTR( v_string, ':', 1, 3) - INSTR( v_string, ':', 1, 2) - 1
								)
							) / 100;
		customer_tab(v_line_num).err_id := SUBSTR	(
							v_string,
							INSTR( v_string, ':', 1, 3) + 1,
							INSTR( v_string, ';', 1, 1) - INSTR( v_string, ':', 1, 3) - 1
							);
	END	LOOP;

	-- Footer
	UTL_FILE.GET_LINE (v_file_handler, v_string);
	-- Checking footer
	IF	LOWER( fhdr_rec.finame ) != SUBSTR	(
						v_string,
						1,
						INSTR( v_string, ':', 1, 1) - 1
						)
	THEN
		RAISE	wrong_filename;
	END	IF;

	v_fiamount := SUBSTR	(
				v_string,
				INSTR( v_string, ':', 1, 1) + 1,
				INSTR( v_string, ':', 1, 2) - INSTR( v_string, ':', 1, 1) - 1
				);

	IF	'control group' != SUBSTR	(
						v_string,
						INSTR( v_string, ':', 1, 2) + 1,
						INSTR( v_string, ':', 1, 3) - INSTR( v_string, ':', 1, 2) - 1
						)
	THEN
		RAISE	check_failure;
	END	IF;

	-- Closing file
	UTL_FILE.FCLOSE( v_file_handler );

	-- Looking for financial data
	SELECT	fc_id
	INTO	v_payment_currency
	FROM	currency_version	outer
	WHERE	gl_curr = 'X'
	AND	version =
		(
		SELECT	MAX( version )
		FROM	currency_version
		WHERE	gl_curr = 'X'
		AND	fc_id = outer.fc_id
		);

	-- Processing data
	OPEN	cash_cur;
	LOOP
		FETCH	cash_cur
		INTO	cash_rec;
		EXIT	WHEN cash_cur%NOTFOUND;

		dbms_application_info.set_module ( 'Aval', 'Processing customer #' || cash_rec.line_num );

		IF	customer_tab.EXISTS(cash_rec.line_num)
		THEN
			IF	customer_tab(cash_rec.line_num).amount > 0
			THEN
				-- Money is not paid. Marking customer as processed but without money
				IF	customer_tab(cash_rec.line_num).amount != cash_rec.amount
				THEN
					RAISE	not_equal_amounts;
				END	IF;

				UPDATE	aval_ftrailer
				SET	amount_paid = 0,
					err_id = customer_tab(cash_rec.line_num).err_id,
					status = 'X'
				WHERE	customer_id = cash_rec.customer_id
				AND	file_id = fhdr_rec.file_id;

				GOTO	loop_end;	-- Fetching next customer
			ELSE
				UPDATE	aval_ftrailer
				SET	amount_paid = cash_rec.amount * 100,
					err_id = customer_tab(cash_rec.line_num).err_id,
					status = 'X'
				WHERE	customer_id = cash_rec.customer_id
				AND	file_id = fhdr_rec.file_id;
			END	IF;
		ELSE	
			UPDATE	aval_ftrailer
			SET	amount_paid = cash_rec.amount * 100,
				status = 'X'
			WHERE	customer_id = cash_rec.customer_id
			AND	file_id = fhdr_rec.file_id;
		END	IF;
		
		v_caxact := common.umc_util.insert_cash
			(
			cash_rec.customer_id,		-- customer_id
			g_entdate,			-- caentdate
			i_finame,			-- cachknum
			cash_rec.amount,		-- cachkamt
			conf_rec.glacode,		-- caglcash
			conf_rec.cagldis,		-- cagldis
			1,				-- catype
			'UMC VISA AVAL AUTO PAYMENT',	-- carem
			'IT',				-- causername
			17				-- careasoncode
			);

		IF	v_caxact = -1
		THEN
			RAISE	cash_insert_failure;
		END	IF;

		UPDATE	customer_all
		SET	cscurbalance = cscurbalance - cash_rec.amount
		WHERE	customer_id = cash_rec.customer_id;

		-- Looking for customer's orders
		OPEN	ohxact_cur;
		
		LOOP
			FETCH	ohxact_cur
			INTO	ohxact_rec;
			EXIT	WHEN ohxact_cur%NOTFOUND;

			-- Closing invoice
			IF	ohxact_rec.ohopnamt_gl <= cash_rec.amount	-- Inovice is fully closed
			THEN

				UPDATE	orderhdr_all
				SET	ohopnamt_gl = 0,
					ohopnamt_doc = 0
				WHERE	CURRENT OF ohxact_cur;

				cash_rec.amount := cash_rec.amount - ohxact_rec.ohopnamt_gl;

				INSERT	INTO cashdetail
					(
					cadxact,
					cadoxact,
					cadglar,
					cadassocxact,
					cadglar_exchange,
					cadjcid_exchange,
					cadexpconvdate_exchange,
					glacode_diff,
					jobcost_id_diff,
					payment_currency,
					document_currency,
					gl_currency,
					cadamt_doc,
					caddisamt_doc,
					cadamt_gl,
					caddisamt_gl,
					cadcuramt_gl,
					cadamt_exchange_gl,
					taxamt_diff_gl,
					cadamt_pay,
					caddisamt_pay,
					cadcuramt_pay,
					cadconvdate_exchange_gl,
					cadconvdate_exchange_doc,
					cadcuramt_doc,
					rec_version
					)
				VALUES	(
					v_caxact,			-- cadxact
					ohxact_rec.ohxact,		-- cadoxact
					ohxact_rec.ohglar,		-- cadglar
					v_caxact,			-- cadassocxact
					NULL,				-- cadglar_exchange
					NULL,				-- cadjcid_exchange
					g_entdate,			-- cadexpconvdate_exchange
					NULL,				-- glacode_diff
					NULL,				-- jobcost_id_diff
					v_payment_currency,		-- payment_currency
					v_payment_currency,		-- document_currency
					v_payment_currency,		-- gl_currency
					ohxact_rec.ohopnamt_gl,		-- cadamt_doc
					0,				-- caddisamt_doc
					ohxact_rec.ohopnamt_gl,		-- cadamt_gl
					0,				-- caddisamt_gl
					ohxact_rec.ohopnamt_gl,		-- cadcuramt_gl
					NULL,				-- cadamt_exchange_gl
					NULL,				-- taxamt_diff_gl
					ohxact_rec.ohopnamt_gl,		-- cadamt_pay
					0,				-- caddisamt_pay
					ohxact_rec.ohopnamt_gl,		-- cadcuramt_pay
					TRUNC( g_entdate ),		-- cadconvdate_exchange_gl
					TRUNC( g_entdate ),		-- cadconvdate_exchange_doc -- DON'T KNOW WHAT IT IS
					ohxact_rec.ohopnamt_gl,		-- cadcuramt_doc
					1				-- rec_version
					);


			ELSE	-- Inovice is partially closed

				UPDATE	orderhdr_all
				SET	ohopnamt_gl = ohxact_rec.ohopnamt_gl - cash_rec.amount,
					ohopnamt_doc = ohxact_rec.ohopnamt_gl - cash_rec.amount
				WHERE	CURRENT	OF ohxact_cur;

				INSERT	INTO cashdetail
					(
					cadxact,
					cadoxact,
					cadglar,
					cadassocxact,
					cadglar_exchange,
					cadjcid_exchange,
					cadexpconvdate_exchange,
					glacode_diff,
					jobcost_id_diff,
					payment_currency,
					document_currency,
					gl_currency,
					cadamt_doc,
					caddisamt_doc,
					cadamt_gl,
					caddisamt_gl,
					cadcuramt_gl,
					cadamt_exchange_gl,
					taxamt_diff_gl,
					cadamt_pay,
					caddisamt_pay,
					cadcuramt_pay,
					cadconvdate_exchange_gl,
					cadconvdate_exchange_doc,
					cadcuramt_doc,
					rec_version
					)
				VALUES	(
					v_caxact,			-- cadxact
					ohxact_rec.ohxact,		-- cadoxact
					ohxact_rec.ohglar,		-- cadglar
					v_caxact,			-- cadassocxact
					NULL,				-- cadglar_exchange
					NULL,				-- cadjcid_exchange
					g_entdate,			-- cadexpconvdate_exchange
					NULL,				-- glacode_diff
					NULL,				-- jobcost_id_diff
					v_payment_currency,		-- payment_currency
					v_payment_currency,		-- document_currency
					v_payment_currency,		-- gl_currency
					cash_rec.amount,		-- cadamt_doc
					0,				-- caddisamt_doc
					cash_rec.amount,		-- cadamt_gl
					0,				-- caddisamt_gl
					cash_rec.amount,		-- cadcuramt_gl
					NULL,				-- cadamt_exchange_gl
					NULL,				-- taxamt_diff_gl
					cash_rec.amount,		-- cadamt_pay
					0,				-- caddisamt_pay
					cash_rec.amount,		-- cadcuramt_pay
					TRUNC( g_entdate ),		-- cadconvdate_exchange_gl
					TRUNC( g_entdate ),		-- cadconvdate_exchange_doc -- DON'T KNOW WHAT IT IS
					cash_rec.amount,		-- cadcuramt_doc
					1				-- rec_version
					);

				cash_rec.amount := 0;

				EXIT;
			END	IF;
		END	LOOP;

		CLOSE	ohxact_cur;
		
		-- Inserting advance
		IF	cash_rec.amount > 0
		THEN
			v_ohxact := common.umc_util.insert_order
				(
				cash_rec.customer_id,
				i_finame,
				-cash_rec.amount,
				conf_rec.glacode,
				'CO',
				NULL,
				1,
				g_entdate
				);

			IF	v_ohxact < 0
			THEN
				RAISE	cash_insert_failure;
			ELSE
				INSERT	INTO cashdetail
					(
					cadxact,
					cadoxact,
					cadglar,
					cadassocxact,
					cadglar_exchange,
					cadjcid_exchange,
					cadexpconvdate_exchange,
					glacode_diff,
					jobcost_id_diff,
					payment_currency,
					document_currency,
					gl_currency,
					cadamt_doc,
					caddisamt_doc,
					cadamt_gl,
					caddisamt_gl,
					cadcuramt_gl,
					cadamt_exchange_gl,
					taxamt_diff_gl,
					cadamt_pay,
					caddisamt_pay,
					cadcuramt_pay,
					cadconvdate_exchange_gl,
					cadconvdate_exchange_doc,
					cadcuramt_doc,
					rec_version
					)
				VALUES	(
					v_caxact,			-- cadxact
					v_ohxact,			-- cadoxact
					'9999994',			-- cadglar
					v_caxact,			-- cadassocxact
					NULL,				-- cadglar_exchange
					NULL,				-- cadjcid_exchange
					g_entdate,			-- cadexpconvdate_exchange
					NULL,				-- glacode_diff
					NULL,				-- jobcost_id_diff
					v_payment_currency,		-- payment_currency
					v_payment_currency,		-- document_currency
					v_payment_currency,		-- gl_currency
					cash_rec.amount,		-- cadamt_doc
					0,				-- caddisamt_doc
					cash_rec.amount,		-- cadamt_gl
					0,				-- caddisamt_gl
					cash_rec.amount,		-- cadcuramt_gl
					NULL,				-- cadamt_exchange_gl
					NULL,				-- taxamt_diff_gl
					cash_rec.amount,		-- cadamt_pay
					0,				-- caddisamt_pay
					cash_rec.amount,		-- cadcuramt_pay
					TRUNC( g_entdate ),		-- cadconvdate_exchange_gl
					TRUNC( g_entdate ),		-- cadconvdate_exchange_doc -- DON'T KNOW WHAT IT IS
					cash_rec.amount,		-- cadcuramt_doc
					1				-- rec_version
					);
			END	IF;
		END	IF;

	<<loop_end>>
	NULL;
	END	LOOP;

	UPDATE	aval_fhdr
	SET	ficount = v_ficount,
		fiamount = v_fiamount,
		processed = 'X'
	WHERE	finame = i_finame;

	COMMIT;
	RETURN	0;

EXCEPTION
	WHEN	file_processed
	THEN
		ROLLBACK;
		RETURN	-14;
	WHEN	wrong_filename
	THEN	
		ROLLBACK;
		RETURN	-11;
	WHEN	cash_insert_failure
	THEN
		ROLLBACK;
		RETURN	-1;
	WHEN	UTL_FILE.INVALID_PATH
	THEN
		ROLLBACK;
		RETURN	-12;
	WHEN	UTL_FILE.INVALID_OPERATION OR UTL_FILE.READ_ERROR
	THEN
		ROLLBACK;
		RETURN	-13;
END	get_file;

PROCEDURE	get_file_info
	(
	i_file_id	IN NUMBER,
	o_customer	IN OUT customer_cur_type
	)
IS
BEGIN

	OPEN	o_customer FOR
	SELECT	af.line_num,
		ca.custcode,
		SUBSTR( cc.cclname || ' ' || cc.ccfname, 1, 40 ),
		af.cardnum,
		af.amount/100,
		af.amount_paid/100,
		af.err_id,
		ae.err_desc,
		af.status
	FROM	aval_ftrailer	af,
		customer_all	ca,
		ccontact_all	cc,
		aval_errors	ae
	WHERE	af.customer_id = ca.customer_id
	AND	ca.customer_id = cc.customer_id
	AND	cc.cccontract = 'X'
	AND	cc.ccseq =
		(
		SELECT	MAX( ccseq )
		FROM	ccontact_all
		WHERE	customer_id = cc.customer_id
		AND	cccontract = 'X'
		)
	AND	ae.err_id(+) = af.err_id
	AND	af.file_id = i_file_id
	ORDER	BY line_num;

END	get_file_info;


PROCEDURE	fill_customer_payments
IS
	-- Cursor for all the customers who hasn't customer_id yet
	CURSOR	customer_cur
	IS
	SELECT	customer_id,
		custcode,
		'50' || phone_number
	FROM	aval.umc_customer_payments
	WHERE	customer_id IS NULL
	AND	processed IS NULL
	FOR	UPDATE OF customer_id;

	-- Cursor for searching customer_id by custcode
	CURSOR	custcode_cur
		(
		p_custcode	VARCHAR
		)
	IS
	SELECT	customer_id
	FROM	customer_all
	WHERE	custcode = p_custcode;

	-- Cursor for searching customer_id by dn_num
	CURSOR	dn_num_cur
		(
		p_dn_num	VARCHAR
		)
	IS
	SELECT	ca.customer_id
	FROM	contract_all		ca,
		contr_services_cap	cs,
		directory_number	dn
	WHERE	dn.dn_id = cs.dn_id
	AND	cs.co_id = ca.co_id
	AND	dn.dn_num = p_dn_num
	AND	cs.cs_deactiv_date IS NULL;

	v_customer_id		customer_all.customer_id%TYPE;
	v_custcode		customer_all.custcode%TYPE;
	v_dn_num		VARCHAR2(9);

BEGIN

	OPEN	customer_cur;
	LOOP
		FETCH	customer_cur
		INTO	v_customer_id,
			v_custcode,
			v_dn_num;
		EXIT	WHEN customer_cur%NOTFOUND;

		IF	v_custcode IS NOT NULL
		THEN
			-- Trying to find customer_id by custcode
			OPEN	custcode_cur( v_custcode );
				FETCH	custcode_cur
				INTO	v_customer_id;
			CLOSE	custcode_cur;

			IF	v_customer_id IS NULL -- We didn't find customer_id
			THEN
				-- Maybe we can use dn_num
				IF	v_dn_num IS NOT NULL
				THEN
					-- Trying to find id by phone					
					OPEN	dn_num_cur( v_dn_num );
						FETCH	dn_num_cur
						INTO	v_customer_id;
					CLOSE	dn_num_cur;
				END	IF;
			END	IF;
		-- Custcode is not null - trying dn_num
		ELSIF	v_dn_num IS NOT NULL
		THEN
			OPEN	dn_num_cur( v_dn_num );
				FETCH	dn_num_cur
				INTO	v_customer_id;
			CLOSE	dn_num_cur;
		END	IF;
		
		UPDATE	aval.umc_customer_payments
		SET	customer_id = v_customer_id
		WHERE	CURRENT OF customer_cur;

	END	LOOP;
END	fill_customer_payments;

END	aval_interface;
/

SHOW ERRORS