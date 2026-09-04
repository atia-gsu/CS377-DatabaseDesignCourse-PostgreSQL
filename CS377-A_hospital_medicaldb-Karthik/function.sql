--- Functions for Hospital Management System

--- Function to scan reports based on medical test name and result
CREATE OR REPLACE FUNCTION Scan_Reports(p_mt_name VARCHAR, p_mt_result VARCHAR)
RETURNS TABLE (
    mt_id INT,
    mt_name VARCHAR,
    p_name VARCHAR,
    mt_result VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT m.mt_id, m.mt_name, p.p_name, m.mt_result
    FROM med_test m
    JOIN patient p ON p.p_id = m.p_id
    WHERE m.mt_name = p_mt_name AND m.mt_result = p_mt_result 
    ORDER BY p.p_name;
END;
$$;

--- Function to get all appointments for a specific doctor
CREATE OR REPLACE FUNCTION Get_Doctor_Appointments(in_d_id INT)
RETURNS TABLE (
    ap_date DATE,
    ap_time TIME,
    p_name VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT a.ap_date, a.ap_time, p.p_name
    FROM appointments a
    JOIN patient p ON p.p_id = a.p_id
    WHERE a.d_id = in_d_id
    ORDER BY a.ap_date, a.ap_time;
END;
$$;

--- Function to get patient information based on patient ID
CREATE OR REPLACE FUNCTION Get_Patient_Info(in_p_id INT)
RETURNS TABLE (
    p_name VARCHAR,
    p_age INT,
    p_height FLOAT,
    p_weight FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT p.p_name, p.p_age, p.p_height, p.p_weight
    FROM patient p
    WHERE p.p_id = in_p_id;
END;
$$;

--- Function to get medical history of a patient based on patient ID
CREATE OR REPLACE FUNCTION Get_Patient_Medical_History(in_p_id INT)
RETURNS TABLE (
    p_name VARCHAR,
    mt_name VARCHAR,
    mt_result VARCHAR,
    mt_date DATE,
    d_name VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT p.p_name, m.mt_name, m.mt_result, m.mt_date, d.d_name
    FROM med_test m
    JOIN patient p ON p.p_id = m.p_id
    JOIN doctor d ON d.d_id = m.d_id
    WHERE m.p_id = in_p_id
    ORDER BY m.mt_date DESC;
END;
$$;

--- Function to get prescription details based on prescription ID
CREATE OR REPLACE FUNCTION Get_Prescription_Details(in_pr_id INT)
RETURNS TABLE (
    pr_date DATE,
    p_name VARCHAR,
    d_name VARCHAR,
    ap_date DATE,
    ap_time TIME
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT pr.pr_date, p.p_name, d.d_name, a.ap_date, a.ap_time
    FROM prescriptions pr
    JOIN patient p ON p.p_id = pr.p_id
    JOIN doctor d ON d.d_id = pr.d_id
    JOIN appointments a ON a.ap_id = pr.ap_id
    WHERE pr.pr_id = in_pr_id;
END;
$$;

--- Function to get total appointments of a doctor based on doctor's name
CREATE OR REPLACE FUNCTION get_total_appointments_of_doctor(in_d_name VARCHAR)
RETURNS TABLE (
    d_name VARCHAR,
    total_appointments BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT d.d_name, COUNT(a.ap_id) AS total_appointments
    FROM doctor d
    LEFT JOIN appointments a ON d.d_id = a.d_id
    WHERE d.d_name = in_d_name
    GROUP BY d.d_name;
END;
$$;

