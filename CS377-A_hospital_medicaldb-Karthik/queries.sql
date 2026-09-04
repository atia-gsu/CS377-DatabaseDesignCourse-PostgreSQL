--- SQL Queries for Hospital Management System
--- Forms table data of patient, doctor, appointments, med_test, medicine_price, prescriptions, prescription_medicine
SELECT * FROM patient;
SELECT * FROM doctor;
SELECT * FROM appointments;
SELECT * FROM med_test;
SELECT * FROM medicine_price;
SELECT * FROM prescriptions;
SELECT * FROM prescription_medicine;

SELECT * FROM appointments LIMIT 10;

--- update operations
UPDATE patient SET p_name = 'John Doe' WHERE p_id = 2;

--- COUNT, SUM, AVG, MAX, MIN operations
SELECT mt_name, COUNT(*) AS total_positive_results
FROM med_test
WHERE mt_result = 'positive' GROUP BY mt_name;

SELECT p.p_name, SUM(m.price) AS total_cost_of_each_patient_for_one_unit_of_medicine
FROM prescription_medicine pm
JOIN prescriptions pr ON pr.pr_id = pm.pr_id
JOIN medicine_price m ON m.mp_id = pm.pm_id
JOIN patient p ON p.p_id = pr.p_id
GROUP BY p.p_name
ORDER BY total_cost_of_each_patient_for_one_unit_of_medicine;


SELECT med_name, MAX(price) AS max_price
FROM medicine_price
GROUP BY med_name;

SELECT med_name, MIN(price) AS min_price
FROM medicine_price
GROUP BY med_name;

--- Combining data from multiple tables
SELECT p.p_name, CONCAT_WS(' ', m.med_name,pm.dosage) AS medicine_dosage 
FROM prescription_medicine pm 
JOIN medicine_price m ON m.mp_id=pm.pm_id
JOIN patient p ON p.p_id=pm.pm_id;

--- String functions

SELECT p_name FROM patient WHERE p_name LIKE 'A%';

SELECT SUBSTRING(p_name, 1, 3) AS first_three_letters_of_patient_name FROM patient;

SELECT LEFT(d_name, 1) AS first_letter_of_doctor_name FROM doctor;

SELECT RIGHT(d_name, 1) AS last_letter_of_doctor_name FROM doctor;

--- Replacing spaces in doctor names with ' Dr. ' except for the last name
SELECT REPLACE(d_name, ' ', ' Dr. ') AS doctor_name_with_prefix_besides_lastname FROM doctor;

--- REVERSE the doctor names
SELECT REVERSE(d_name) AS reversed_doctor_name FROM doctor;

--- LENGTH of patient names with spaces included
SELECT LENGTH(p_name) AS length_of_patient_name FROM patient;

--- LENGTH of patient names without spaces
SELECT LENGTH(TRIM(p_name)) AS length_of_patient_name_without_spaces FROM patient;

--- CTE to get all appointments of a specific doctor and order them by date
WITH doctor_appointments AS (
    SELECT d.d_name, a.ap_date, a.ap_time
    FROM doctor d
    JOIN appointments a ON d.d_id = a.d_id
    WHERE d.d_id = 1
)
SELECT d_name, ap_date, ap_time
FROM doctor_appointments
ORDER BY ap_date;

SELECT p.p_name,m.med_name, m.price, SUM(m.price) AS total_price_for_each_medicine 
FROM medicine_price m JOIN prescription_medicine pm ON m.mp_id = pm.mp_id
JOIN prescriptions pr ON pr.pr_id = pm.pr_id
JOIN patient p ON p.p_id = pr.p_id
GROUP BY p.p_name, ROLLUP(med_name, price) HAVING price>100.2 
ORDER BY total_price_for_each_medicine;

--- Window function to rank doctors based on the number of appointments they have
SELECT d.d_name, COUNT(a.ap_id) AS total_appointments, DENSE_RANK() OVER(ORDER BY COUNT(a.ap_id) DESC) AS doctor_rank
FROM doctor d
JOIN appointments a ON d.d_id = a.d_id
GROUP BY d.d_name;

--- Functions to retrieve specific data
SELECT * FROM get_doctor_appointments(1);
SELECT * FROM get_patient_medical_history(1);
SELECT * FROM get_patient_info(1);
SELECT * FROM scan_reports('Blood Test', 'negative') ORDER BY mt_id DESC;
SELECT * FROM get_prescription_details(100);
SELECT * FROM get_total_appointments_of_doctor('Linda Harris');

--- Calling stored procedures
CALL insert_patient('Alice Smith', 30, 165.5, 60.0);
SELECT * FROM patient WHERE p_name = 'Alice Smith';
CALL update_medicine_price(1, 19.99);
SELECT * FROM medicine_price WHERE mp_id = 1;
CALL delete_appointment(1);
SELECT * FROM appointments;
