--
-- PostgreSQL database dump
--

\restrict HT5HpRJelzqKlgslJ6hWrbDMUN4jW5TISUcJEY0fRVXi5BNQFkUA5lQuiKG5QfQ

-- Dumped from database version 18.2
-- Dumped by pg_dump version 18.2

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: get_doctor_appointments(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_doctor_appointments(in_d_id integer) RETURNS TABLE(ap_date date, ap_time time without time zone, p_name character varying)
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


ALTER FUNCTION public.get_doctor_appointments(in_d_id integer) OWNER TO postgres;

--
-- Name: get_patient_info(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_patient_info(in_p_id integer) RETURNS TABLE(p_name character varying, p_age integer, p_height double precision, p_weight double precision)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT p.p_name, p.p_age, p.p_height, p.p_weight
    FROM patient p
    WHERE p.p_id = in_p_id;
END;
$$;


ALTER FUNCTION public.get_patient_info(in_p_id integer) OWNER TO postgres;

--
-- Name: get_patient_medical_history(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_patient_medical_history(in_p_id integer) RETURNS TABLE(p_name character varying, mt_name character varying, mt_result character varying, mt_date date, d_name character varying)
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


ALTER FUNCTION public.get_patient_medical_history(in_p_id integer) OWNER TO postgres;

--
-- Name: get_patient_tests(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_patient_tests(pp_id integer) RETURNS TABLE(p_id integer, p_name character varying, mt_name character varying, mt_result character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT p.p_id, p.p_name, m.mt_name, m.mt_result
    FROM med_test m
    JOIN patient p ON p.p_id = m.p_id
    WHERE p.p_id = pp_id;
END;
$$;


ALTER FUNCTION public.get_patient_tests(pp_id integer) OWNER TO postgres;

--
-- Name: get_patients_by_test(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_patients_by_test(p_mt_name character varying, p_mt_result character varying) RETURNS TABLE(p_id integer, p_name character varying, p_age integer, p_height double precision, p_weight double precision)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT p.p_id, p.p_name, p.p_age, p.p_height, p.p_weight
    FROM patient p
    JOIN med_test mt ON p.p_id = mt.p_id
    WHERE mt.mt_name = p_mt_name AND mt.mt_result = p_mt_result;
END;
$$;


ALTER FUNCTION public.get_patients_by_test(p_mt_name character varying, p_mt_result character varying) OWNER TO postgres;

--
-- Name: get_prescription_details(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_prescription_details(in_pr_id integer) RETURNS TABLE(pr_date date, p_name character varying, d_name character varying, ap_date date, ap_time time without time zone)
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


ALTER FUNCTION public.get_prescription_details(in_pr_id integer) OWNER TO postgres;

--
-- Name: insert_med_test(integer, character varying, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.insert_med_test(IN p_id integer, IN mt_name character varying, IN mt_result character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO med_test (p_id, mt_name, mt_result)
    VALUES (p_id, mt_name, mt_result);
END;
$$;


ALTER PROCEDURE public.insert_med_test(IN p_id integer, IN mt_name character varying, IN mt_result character varying) OWNER TO postgres;

--
-- Name: insert_patient(character varying, integer, double precision, double precision); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.insert_patient(IN p_name character varying, IN p_age integer, IN p_height double precision, IN p_weight double precision)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO patient (p_name, p_age, p_height, p_weight)
    VALUES (p_name, p_age, p_height, p_weight);
END;
$$;


ALTER PROCEDURE public.insert_patient(IN p_name character varying, IN p_age integer, IN p_height double precision, IN p_weight double precision) OWNER TO postgres;

--
-- Name: scan_reports(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.scan_reports(p_mt_name character varying, p_mt_result character varying) RETURNS TABLE(mt_id integer, mt_name character varying, p_name character varying, mt_result character varying)
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


ALTER FUNCTION public.scan_reports(p_mt_name character varying, p_mt_result character varying) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: appointments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.appointments (
    ap_id integer NOT NULL,
    ap_date date NOT NULL,
    ap_time time without time zone NOT NULL,
    p_id integer NOT NULL,
    d_id integer NOT NULL
);


ALTER TABLE public.appointments OWNER TO postgres;

--
-- Name: appointments_ap_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.appointments_ap_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.appointments_ap_id_seq OWNER TO postgres;

--
-- Name: appointments_ap_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.appointments_ap_id_seq OWNED BY public.appointments.ap_id;


--
-- Name: doctor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.doctor (
    d_id integer NOT NULL,
    d_name character varying(255) NOT NULL,
    specialty character varying(255) NOT NULL
);


ALTER TABLE public.doctor OWNER TO postgres;

--
-- Name: doctor_d_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.doctor_d_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.doctor_d_id_seq OWNER TO postgres;

--
-- Name: doctor_d_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.doctor_d_id_seq OWNED BY public.doctor.d_id;


--
-- Name: med_test; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.med_test (
    mt_id integer NOT NULL,
    mt_name character varying(255) NOT NULL,
    mt_result character varying(255) NOT NULL,
    mt_date date NOT NULL,
    p_id integer NOT NULL,
    d_id integer NOT NULL
);


ALTER TABLE public.med_test OWNER TO postgres;

--
-- Name: med_test_mt_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.med_test_mt_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.med_test_mt_id_seq OWNER TO postgres;

--
-- Name: med_test_mt_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.med_test_mt_id_seq OWNED BY public.med_test.mt_id;


--
-- Name: medicine_price; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.medicine_price (
    mp_id integer NOT NULL,
    med_name character varying(255) NOT NULL,
    price double precision NOT NULL
);


ALTER TABLE public.medicine_price OWNER TO postgres;

--
-- Name: medicine_price_mp_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.medicine_price_mp_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.medicine_price_mp_id_seq OWNER TO postgres;

--
-- Name: medicine_price_mp_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.medicine_price_mp_id_seq OWNED BY public.medicine_price.mp_id;


--
-- Name: patient; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.patient (
    p_id integer NOT NULL,
    p_name character varying(255) NOT NULL,
    p_age integer NOT NULL,
    p_height double precision NOT NULL,
    p_weight double precision NOT NULL
);


ALTER TABLE public.patient OWNER TO postgres;

--
-- Name: patient_p_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.patient_p_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.patient_p_id_seq OWNER TO postgres;

--
-- Name: patient_p_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.patient_p_id_seq OWNED BY public.patient.p_id;


--
-- Name: prescription_medicine; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.prescription_medicine (
    pm_id integer NOT NULL,
    pr_id integer NOT NULL,
    mp_id integer NOT NULL,
    dosage character varying(255) NOT NULL,
    duration_days integer
);


ALTER TABLE public.prescription_medicine OWNER TO postgres;

--
-- Name: prescription_medicine_pm_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.prescription_medicine_pm_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.prescription_medicine_pm_id_seq OWNER TO postgres;

--
-- Name: prescription_medicine_pm_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.prescription_medicine_pm_id_seq OWNED BY public.prescription_medicine.pm_id;


--
-- Name: prescriptions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.prescriptions (
    pr_id integer NOT NULL,
    ap_id integer NOT NULL,
    p_id integer NOT NULL,
    d_id integer NOT NULL,
    pr_date date NOT NULL
);


ALTER TABLE public.prescriptions OWNER TO postgres;

--
-- Name: prescriptions_pr_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.prescriptions_pr_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.prescriptions_pr_id_seq OWNER TO postgres;

--
-- Name: prescriptions_pr_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.prescriptions_pr_id_seq OWNED BY public.prescriptions.pr_id;


--
-- Name: appointments ap_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments ALTER COLUMN ap_id SET DEFAULT nextval('public.appointments_ap_id_seq'::regclass);


--
-- Name: doctor d_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.doctor ALTER COLUMN d_id SET DEFAULT nextval('public.doctor_d_id_seq'::regclass);


--
-- Name: med_test mt_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.med_test ALTER COLUMN mt_id SET DEFAULT nextval('public.med_test_mt_id_seq'::regclass);


--
-- Name: medicine_price mp_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.medicine_price ALTER COLUMN mp_id SET DEFAULT nextval('public.medicine_price_mp_id_seq'::regclass);


--
-- Name: patient p_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patient ALTER COLUMN p_id SET DEFAULT nextval('public.patient_p_id_seq'::regclass);


--
-- Name: prescription_medicine pm_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescription_medicine ALTER COLUMN pm_id SET DEFAULT nextval('public.prescription_medicine_pm_id_seq'::regclass);


--
-- Name: prescriptions pr_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescriptions ALTER COLUMN pr_id SET DEFAULT nextval('public.prescriptions_pr_id_seq'::regclass);


--
-- Name: appointments appointments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_pkey PRIMARY KEY (ap_id);


--
-- Name: doctor doctor_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.doctor
    ADD CONSTRAINT doctor_pkey PRIMARY KEY (d_id);


--
-- Name: med_test med_test_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.med_test
    ADD CONSTRAINT med_test_pkey PRIMARY KEY (mt_id);


--
-- Name: medicine_price medicine_price_med_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.medicine_price
    ADD CONSTRAINT medicine_price_med_name_key UNIQUE (med_name);


--
-- Name: medicine_price medicine_price_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.medicine_price
    ADD CONSTRAINT medicine_price_pkey PRIMARY KEY (mp_id);


--
-- Name: patient patient_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patient
    ADD CONSTRAINT patient_pkey PRIMARY KEY (p_id);


--
-- Name: prescription_medicine prescription_medicine_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescription_medicine
    ADD CONSTRAINT prescription_medicine_pkey PRIMARY KEY (pm_id);


--
-- Name: prescriptions prescriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescriptions
    ADD CONSTRAINT prescriptions_pkey PRIMARY KEY (pr_id);


--
-- Name: appointments appointments_d_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_d_id_fkey FOREIGN KEY (d_id) REFERENCES public.doctor(d_id);


--
-- Name: appointments appointments_p_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_p_id_fkey FOREIGN KEY (p_id) REFERENCES public.patient(p_id);


--
-- Name: med_test med_test_d_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.med_test
    ADD CONSTRAINT med_test_d_id_fkey FOREIGN KEY (d_id) REFERENCES public.doctor(d_id);


--
-- Name: med_test med_test_p_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.med_test
    ADD CONSTRAINT med_test_p_id_fkey FOREIGN KEY (p_id) REFERENCES public.patient(p_id);


--
-- Name: prescription_medicine prescription_medicine_mp_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescription_medicine
    ADD CONSTRAINT prescription_medicine_mp_id_fkey FOREIGN KEY (mp_id) REFERENCES public.medicine_price(mp_id);


--
-- Name: prescription_medicine prescription_medicine_pr_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescription_medicine
    ADD CONSTRAINT prescription_medicine_pr_id_fkey FOREIGN KEY (pr_id) REFERENCES public.prescriptions(pr_id);


--
-- Name: prescriptions prescriptions_ap_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescriptions
    ADD CONSTRAINT prescriptions_ap_id_fkey FOREIGN KEY (ap_id) REFERENCES public.appointments(ap_id);


--
-- Name: prescriptions prescriptions_d_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescriptions
    ADD CONSTRAINT prescriptions_d_id_fkey FOREIGN KEY (d_id) REFERENCES public.doctor(d_id);


--
-- Name: prescriptions prescriptions_p_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.prescriptions
    ADD CONSTRAINT prescriptions_p_id_fkey FOREIGN KEY (p_id) REFERENCES public.patient(p_id);


--
-- PostgreSQL database dump complete
--

\unrestrict HT5HpRJelzqKlgslJ6hWrbDMUN4jW5TISUcJEY0fRVXi5BNQFkUA5lQuiKG5QfQ

