---
layout: pages
title: Hospital Medical Database
permalink: /
---

# Hospital Medical Database

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-blue)
![Docker](https://img.shields.io/badge/Docker-2496ED)
![Course](https://img.shields.io/badge/CS377-Ursinus_College-orange)

---

**Course:** CS377.<br>
**Author:** Karthik Reddy Akkala.<br>
**Date:** May 2, 2026. 

---

## Introduction: 
This project is for implementing a PostgreSQL based hospital management database for managing patients, medical test, and all other records.

This has been containerized with docker for easy setup and working efficiently across different environoments.

---

## Tools:
- PostgreSQL
- Docker

---

## Project Structure: 

```
CS377-A_hospital_medicaldb/
├── README.md
├── database
│   ├── backups
│   │   └── backup.sql
│   └── init. 
│       ├── schema.sql
│       └── seed.sql
├── docker-compose.yml
├── queries
│   ├── function.sql
│   ├── procedures.sql
│   └── queries.sql
└── scripts
    └── backup_db.sh
```

---

## Setting Up Database:

Start & Connect To Database:

```bash
git clone https://github.com/karthik-bit1/CS377-A_hospital_medicaldb.git

cd CS377-A_hospital_medicaldb

docker compose up -d

docker exec -it hospital_postgres psql -U postgres -d hospital_meddb
```
Stop Database:

```bash
docker compose down
```

Reset Database:

```bash
docker compose down -v
docker compose up
```

---

## Backup Database:

Running Backups:
```bash
./scripts/backup_db.sh
```

Backups saved in:

```
CS377-A_hospital_medicaldb/
├── README.md
└── database
    └── backups
        └── backup.sql
```

---

## Tables In The Database:

- **patient**: stores patient information

<p align="left">
  <img src="/CS377-A_hospital_medicaldb/images/patient.png" width="300"/>
</p>

- **doctor**: stores doctor details 

<p align="left">
  <img src="/CS377-A_hospital_medicaldb/images/doctor.png" width="300"/>
</p>

- **appointments**: tracks patients appointments with their doctor

<p align="left">
  <img src="/CS377-A_hospital_medicaldb/images/appointments.png" width="300"/>
</p>

- **med_test**: stores medical test results 

<p align="left">
  <img src="/CS377-A_hospital_medicaldb/images/med_test.png" width="300"/>
</p>

- **medicine_price**: stores medicine pricing

<p align="left">
  <img src="/CS377-A_hospital_medicaldb/images/medicine_price.png" width="300"/>
</p>

- **prescriptions**: records prescriptions issued 

<p align="left">
  <img src="/CS377-A_hospital_medicaldb/images/prescriptions.png" width="300"/>
</p>

- **prescription_medicine**: links prescriptions with medicines 

<p align="left">
  <img src="/CS377-A_hospital_medicaldb/images/prescriptions_medicine.png" width="300"/>
</p>

---

## ERD Diagram:

<p align="center">
  <img src="/CS377-A_hospital_medicaldb/images/Hospital_meddb_ERD_Diagram.png" width="300"/>
</p>

---

## Sample Queries:

```sql
SELECT * FROM patient;
SELECT * FROM doctor;
SELECT * FROM appointments;
SELECT * FROM med_test;
SELECT * FROM medicine_price;
SELECT * FROM prescriptions;
SELECT * FROM prescription_medicine;

SELECT p.p_name, d.d_name, a.ap_date, a.ap_time
FROM appointments a
JOIN patient p ON p.p_id = a.p_id
JOIN doctor d ON d.d_id = a.d_id
ORDER BY p.p_name;

SELECT * FROM get_doctor_appointments(1);
SELECT * FROM get_patient_medical_history(1);
SELECT * FROM get_patient_info(1);

-- Assuming there are records in med_test with mt_name = 'Blood Test' and mt_result = 'negative'
SELECT * FROM scan_reports('Blood Test', 'negative') ORDER BY mt_id; 
-- Assuming pr_id = 1 exists in prescriptions table
SELECT * FROM get_prescription_details(1);
```

And a lot more queries added in <https://github.com/karthik-bit1/CS377-A_hospital_medicaldb/blob/main/queries/queries.sql>

## Main Function Calls Added:

- Scan reports related to each requested scan and it's result.

```sql
SELECT * FROM scan_reports('Blood Test', 'negative') ORDER BY mt_id;
```

- Total number of appointments requested for doctor name.

```sql
SELECT * FROM get_total_appointments_of_doctor('Linda Harris');
```

- Prescriptions details of each prescription id requested

```sql
SELECT * FROM get_prescription_details(100);
```

- And a lot more other functions included in <https://github.com/karthik-bit1/CS377-A_hospital_medicaldb/blob/main/queries/function.sql> .

## Main Procedure Calls Added:

- Inserting patient data into patient table

```sql
CALL insert_patient('Alice Smith', 30, 165.5, 60.0);

SELECT * FROM patient WHERE p_name = 'Alice Smith';
```

- Updating medical price in medicine_price table

```sql
CALL update_medicine_price(1, 19.99);

SELECT * FROM medicine_price WHERE mp_id = 1;
```

- Deleting existing appointments in appointments table

```sql
CALL delete_appointment(1);

SELECT * FROM appointments;
```

- And a lot more other Procedures included in <https://github.com/karthik-bit1/CS377-A_hospital_medicaldb/blob/main/queries/procedures.sql> .


## Conclusion:

This project is used to mange data observation from different data tables included in the database. It is used widely in registar office to manqage bills, patients information and appointments, doctor computer to check there patients data and easy access in editing there prescriptions and appointments, and patients device to schedule appointments, gather information of medicines and check there reports.

Moving further, I will be adding a app.py to access data and have a directs report on search instead of prompting each SQL command line.

