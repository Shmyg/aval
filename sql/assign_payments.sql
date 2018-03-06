/*
Script assigning payments for customers
Looks for payments from shmyg.UMC_CUSTOMER_PAYMENTS table and tries to assign
payment for every customer
Created by Shmyg
LMD 11.12.2003 by Shmyg
*/

DECLARE

	-- Constants
	c_status_to_process	CONSTANT VARCHAR2(2) := '01';
	c_status_is_processed	CONSTANT VARCHAR2(2) := '02';


	v_customer_id		NUMBER;
	v_amount		NUMBER;
	v_payment_rowid		UROWID;
	v_file_rowid		UROWID;

	i			PLS_INTEGER := 0;
	v_count			PLS_INTEGER := 0;

	v_catype		cashreceipts_all.catype%TYPE;
	v_careasoncode		cashreceipts_all.careasoncode%TYPE;
	v_close_orders		VARCHAR2(1);
	v_remark		VARCHAR2(30);
	
	-- Payment object for write off transaction
	payment		donor.payment_t := donor.payment_t
				(
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL,
				NULL	
				);

	-- Cursor for payment files which have been loaded and checked
	-- and to be processed now
	CURSOR	file_cur
	IS
	SELECT	file_id,
		ROWID
	FROM	aval.umc_payment_files
	WHERE	file_status = c_status_to_process;

	-- Cursor for payments for specified file
	CURSOR	payment_cur
		(
		p_file_id	NUMBER
		)
	IS
	SELECT	customer_id,
		amount,
		ROWID
	FROM	aval.umc_customer_payments
	WHERE	file_id = p_file_id
	AND	customer_id IS NOT NULL
	AND	processed IS NULL;

	-- Function to chek if customer is payment repsonsible
	FUNCTION	is_payment_responsible
		(
		i_customer_id	NUMBER
		)
	RETURN	BOOLEAN
	IS
		v_customer_id	NUMBER;
	BEGIN
		SELECT	customer_id
		INTO	v_customer_id
		FROM	customer_all
		WHERE	customer_id = v_customer_id
		AND	paymntresp = 'X';
		
		RETURN	TRUE;

	EXCEPTION
		WHEN	NO_DATA_FOUND
		RETURN	FALSE;
	END;

	-- Function to check if customer has open orders
	FUNCTION	has_open_orders
		(
		i_customer_id	NUMBER
		)
	RETURN	BOOLEAN
	IS
		v_customer_id	PLS_INTEGER;
	BEGIN
		-- Checking if customer has open orders
		SELECT	customer_id
		INTO	v_customer_id
		FROM	orderhdr_all
		WHERE	customer_id = p_customer_id
		AND	ohstatus = 'IN'
		AND	ohopnamt_gl > 0
		AND	ROWNUM = 1;

		RETURN	TRUE;

	EXCEPTION
		WHEN	NO_DATA_FOUND
		THEN	RETURN	FALSE;
	END;

BEGIN

	OPEN	file_cur;

	LOOP
		FETCH	file_cur
		INTO	v_file_id;

		EXIT	WHEN file_cur%NOTFOUND;

		OPEN	payment_cur ( v_file_id );
		LOOP

			FETCH	payment_cur
			INTO	v_customer_id,
				v_amount,
				v_rowid;

			EXIT	WHEN payment_cur%NOTFOUND;

			-- Checking if customer is payment 
			IF	NOT is_payment_resp( v_customer_id )
			THEN
				-- Customer is not payment responsible
				UPDATE	aval.umc_customer_payments
				SET	processed = 'X',
					err_message = v_customer_id || ' is not payment responsible'
				WHERE	ROWID = v_payment_rowid;
			ELSE

				IF	has_open_orders( v_customer_id )
				THEN
					v_catype := 1;
					v_careasoncode := 17;
					v_close_orders := 'Y';
					v_remark := 'Automatic payment';
				ELSE
				-- Customer doesn't have open orders - assigning advance
					v_catype := 3;
					v_careasoncode := 19;
					v_close_orders := 'N';
					v_remark := 'Automatic advance';
				END	IF;
				
				BEGIN
					
				-- Here we need savepoint to roll the TX back in
				-- case of any error
				SAVEPOINT	start_tx;

				-- Inserting write-off
				payment.insert_me
					(
					v_customer_id,
					v_amount,
					v_remark,
					v_remark,
					v_catype,
					v_careasoncode,
					'2012010',
					'9999984',
					SYSDATE,
					v_close_orders
					);

				UPDATE	aval.umc_customer_payments
				SET	processed = 'X',
					err_message = payment.tx_id
				WHERE	ROWID = v_rowid;

				EXCEPTION

				-- Some error ocurred - rolling back and reporting
				WHEN	OTHERS
				THEN
					ROLLBACK TO start_tx;

					UPDATE	aval.umc_customer_payments
					SET	processed = 'X',
						err_message = SQLERRM
					WHERE	ROWID = v_rowid
	
				END;
			END	IF;
		END	LOOP;
		CLOSE	payment_cur;
	COMMIT;
	END	LOOP;
	CLOSE	file_cur;
END;
/