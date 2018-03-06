/*
Script to check if we have loaded duplicate payment files
Created by Shmyg
LMD 10.12.2003 by Shmyg
*/

DECLARE
	
	-- We need to check all the files with '00' (just loaded) status 
	CURSOR	file_cur
	IS
	SELECT	up.file_id,
		SUM( uc.amount ),
		COUNT( uc.line_num )
	FROM	umc_payment_files	up,
		umc_customer_payments	uc
	WHERE	uc.file_id = up.file_id
	AND	up.file_status = '00'
	GROUP	BY up.file_id;

	v_file_id	PLS_INTEGER;
	v_quantity	PLS_INTEGER;
	v_amount	NUMBER;

BEGIN

	OPEN	file_cur;
	LOOP
		FETCH	file_cur
		INTO	v_file_id,
			v_amount,
			v_quantity;
		
		EXIT	WHEN file_cur%NOTFOUND;

		-- Here we change status to '10' for the files which
		-- have the same quantity of records loaded and amount with
		-- the file to be checked and are loaded later
		-- If there is no such files - we just don't do anything
		UPDATE	umc_payment_files
		SET	file_status = '10'
		WHERE	file_id IN
			(
			SELECT	file_id
			FROM	(
				SELECT	up.file_id,
					SUM( uc.amount ) AS amount,
					COUNT( uc.line_num ) AS quantity
				FROM	umc_payment_files	up,
					umc_customer_payments	uc
				WHERE	uc.file_id = up.file_id
				AND	up.file_status = '00'
				AND	up.file_id > v_file_id
				GROUP	BY up.file_id
				)	fs
			WHERE	fs.amount = v_amount
			AND	fs.quantity = v_quantity
			);

		UPDATE	umc_payment_files
		SET	file_status = '01'
		WHERE	file_id = v_file_id;

	END	LOOP;
	CLOSE	file_cur;
	COMMIT;
END;
/