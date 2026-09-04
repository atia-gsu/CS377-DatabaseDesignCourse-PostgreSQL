--- Stored Procedures for Hospital Medical Database

--- Procedure to insert a new patient record
CREATE OR REPLACE PROCEDURE insert_patient(
    in_p_name VARCHAR,
    in_p_age INT,
    in_p_height FLOAT,
    in_p_weight FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO patient (p_name, p_age, p_height, p_weight)
    VALUES (in_p_name, in_p_age, in_p_height, in_p_weight);
END;
$$;

--- Procedure to insert a new prescription record
CREATE OR REPLACE PROCEDURE insert_prescription(
    in_p_id INT,
    in_d_id INT,
    in_ap_id INT,
    in_pr_date DATE
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO prescriptions (p_id, d_id, ap_id, pr_date)
    VALUES (in_p_id, in_d_id, in_ap_id, in_pr_date);
END;
$$;

--- Procedure to insert a new medical test record
CREATE OR REPLACE PROCEDURE insert_med_test(
    in_p_id INT,
    in_d_id INT,
    in_mt_name VARCHAR,
    in_mt_result VARCHAR,
    in_mt_date DATE
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO med_test (p_id, d_id, mt_name, mt_result, mt_date)
    VALUES (in_p_id, in_d_id, in_mt_name, in_mt_result, in_mt_date);
END;
$$;

--- Procedure to update the price of a medicine
CREATE OR REPLACE PROCEDURE update_medicine_price(
    in_mp_id INT,
    in_new_price FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE medicine_price
    SET price = in_new_price
    WHERE mp_id = in_mp_id;
END;
$$;

--- Procedure to delete an appointment based on appointment ID
CREATE OR REPLACE PROCEDURE delete_appointment(in_ap_id INT)
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM appointments
    WHERE ap_id = in_ap_id;
END;
$$;

