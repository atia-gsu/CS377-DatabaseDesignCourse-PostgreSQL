--
-- PostgreSQL database dump
--

\restrict 32zlYhPzJLp4IzbDZ2HNFutXhPtvhtcSL8tTZdGERU5P8OcKjbcBFGcSnairrpL

-- Dumped from database version 18.1
-- Dumped by pg_dump version 18.1

-- Started on 2026-05-05 22:02:45

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
-- TOC entry 251 (class 1255 OID 32997)
-- Name: add_issue(integer, character varying, character varying, date, numeric, smallint, text); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.add_issue(IN p_series_id integer, IN p_issue_number character varying, IN p_title character varying, IN p_publish_date date, IN p_cover_price numeric, IN p_page_count smallint, IN p_notes text DEFAULT NULL::text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_series_title VARCHAR;
BEGIN
    SELECT title AS series_title
    INTO v_series_title
    FROM series
    WHERE series_id = p_series_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Series ID % does not exist.', p_series_id;
    END IF;

    INSERT INTO issue (series_id, issue_number, title, publish_date, cover_price, page_count, notes)
    VALUES (p_series_id, p_issue_number, p_title, p_publish_date, p_cover_price, p_page_count, p_notes);

    RAISE NOTICE 'Issue "%" (#%) added to series "%".', p_title, p_issue_number, v_series_title;
END;
$$;


ALTER PROCEDURE public.add_issue(IN p_series_id integer, IN p_issue_number character varying, IN p_title character varying, IN p_publish_date date, IN p_cover_price numeric, IN p_page_count smallint, IN p_notes text) OWNER TO postgres;

--
-- TOC entry 253 (class 1255 OID 32999)
-- Name: delete_creator_credits(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.delete_creator_credits(IN p_creator_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_name          TEXT;
    v_deleted_count INT;
BEGIN
    SELECT CONCAT(first_name, ' ', last_name) AS full_name
    INTO v_name
    FROM creator
    WHERE creator_id = p_creator_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Creator ID % does not exist.', p_creator_id;
    END IF;

    DELETE FROM issue_creator
    WHERE creator_id = p_creator_id;

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

    RAISE NOTICE 'Removed % credit(s) for creator "%" (ID %).', v_deleted_count, v_name, p_creator_id;
END;
$$;


ALTER PROCEDURE public.delete_creator_credits(IN p_creator_id integer) OWNER TO postgres;

--
-- TOC entry 248 (class 1255 OID 32993)
-- Name: get_creator_credits(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_creator_credits(p_first_name character varying, p_last_name character varying) RETURNS TABLE(creator text, creator_ws text, role character varying, series character varying, issue_number character varying, issue_title character varying, publish_date date)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
        SELECT
            CONCAT(c.first_name, ' ', c.last_name)     AS creator,
            CONCAT_WS(' ', c.first_name, c.last_name)  AS creator_ws,
            ic.role,
            s.title                                     AS series,
            i.issue_number,
            i.title                                     AS issue_title,
            i.publish_date
        FROM issue_creator ic
        INNER JOIN creator c ON ic.creator_id = c.creator_id
        INNER JOIN issue   i ON ic.issue_id   = i.issue_id
        INNER JOIN series  s ON i.series_id   = s.series_id
        WHERE LOWER(c.first_name) = LOWER(p_first_name)
          AND LOWER(c.last_name)  = LOWER(p_last_name)
        ORDER BY i.publish_date DESC
        LIMIT 100;
END;
$$;


ALTER FUNCTION public.get_creator_credits(p_first_name character varying, p_last_name character varying) OWNER TO postgres;

--
-- TOC entry 256 (class 1255 OID 33002)
-- Name: get_creator_string_analysis(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_creator_string_analysis(p_search character varying) RETURNS TABLE(full_name text, name_replaced text, name_reversed text, name_length integer, trimmed_length integer, name_substr_1_5 text, first_4_chars text, last_4_chars text, pos_of_e integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
        SELECT
            CONCAT(c.first_name, ' ', c.last_name)  AS full_name,
            REPLACE(c.last_name, 'son', 'SON')       AS name_replaced,
            REVERSE(c.last_name)                     AS name_reversed,
            LENGTH(c.last_name)                      AS name_length,
            LENGTH(TRIM(c.last_name))                AS trimmed_length,
            SUBSTR(c.last_name, 1, 5)                AS name_substr_1_5,
            LEFT(c.last_name, 4)                     AS first_4_chars,
            RIGHT(c.last_name, 4)                    AS last_4_chars,
            POSITION('e' IN LOWER(c.last_name))      AS pos_of_e
        FROM creator c
        WHERE c.last_name LIKE p_search || '_'        -- '_' matches exactly one extra char
           OR c.last_name LIKE '%' || p_search || '%' -- '%' matches anywhere in name
        ORDER BY c.last_name;
END;
$$;


ALTER FUNCTION public.get_creator_string_analysis(p_search character varying) OWNER TO postgres;

--
-- TOC entry 258 (class 1255 OID 33004)
-- Name: get_genre_cross_publisher(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_genre_cross_publisher() RETURNS TABLE(publisher character varying, genre character varying, series_count bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
        SELECT
            p.name           AS publisher,
            genre_list.genre,
            COUNT(s.series_id) AS series_count
        FROM publisher p
        CROSS JOIN (
            SELECT DISTINCT s2.genre
            FROM series s2
            WHERE s2.genre IS NOT NULL
        ) AS genre_list
        LEFT JOIN series s
               ON s.publisher_id = p.publisher_id
              AND s.genre        = genre_list.genre
        GROUP BY p.name, genre_list.genre
        HAVING COUNT(s.series_id) > 0
        ORDER BY p.name, series_count DESC;
END;
$$;


ALTER FUNCTION public.get_genre_cross_publisher() OWNER TO postgres;

--
-- TOC entry 257 (class 1255 OID 33003)
-- Name: get_issue_rankings(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_issue_rankings() RETURNS TABLE(series character varying, issue_title character varying, cover_price numeric, publish_date date, row_num bigint, price_rank bigint, dense_price_rank bigint, prev_price numeric, next_price numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
        WITH issue_base AS (
            SELECT
                s.title        AS series_title,
                i.title        AS issue_title,
                i.cover_price,
                i.publish_date
            FROM issue i
            INNER JOIN series s ON i.series_id = s.series_id
        )
        SELECT
            ib.series_title                                                              AS series,
            ib.issue_title,
            ib.cover_price,
            ib.publish_date,
            ROW_NUMBER()  OVER (PARTITION BY ib.series_title ORDER BY ib.cover_price DESC) AS row_num,
            RANK()        OVER (PARTITION BY ib.series_title ORDER BY ib.cover_price DESC) AS price_rank,
            DENSE_RANK()  OVER (PARTITION BY ib.series_title ORDER BY ib.cover_price DESC) AS dense_price_rank,
            LAG(ib.cover_price)  OVER (PARTITION BY ib.series_title ORDER BY ib.publish_date) AS prev_price,
            LEAD(ib.cover_price) OVER (PARTITION BY ib.series_title ORDER BY ib.publish_date) AS next_price
        FROM issue_base ib
        ORDER BY ib.series_title, ib.cover_price DESC;
END;
$$;


ALTER FUNCTION public.get_issue_rankings() OWNER TO postgres;

--
-- TOC entry 247 (class 1255 OID 32992)
-- Name: get_issues_by_publisher(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_issues_by_publisher(p_publisher_name character varying) RETURNS TABLE(publisher character varying, series character varying, issue_number character varying, issue_title character varying, publish_date date, cover_price numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
        SELECT
            p.name         AS publisher,
            s.title        AS series,
            i.issue_number AS issue_number,
            i.title        AS issue_title,
            i.publish_date,
            i.cover_price
        FROM issue i
        INNER JOIN series    s ON i.series_id    = s.series_id
        INNER JOIN publisher p ON s.publisher_id = p.publisher_id
        WHERE LOWER(p.name) = LOWER(p_publisher_name)
        ORDER BY s.title, i.publish_date;
END;
$$;


ALTER FUNCTION public.get_issues_by_publisher(p_publisher_name character varying) OWNER TO postgres;

--
-- TOC entry 254 (class 1255 OID 33000)
-- Name: get_issues_with_character_count(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_issues_with_character_count(p_min_characters integer DEFAULT 3) RETURNS TABLE(issue_id integer, issue_title character varying, series character varying, publish_date date, character_count bigint, total_pages bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
        SELECT
            i.issue_id,
            i.title                AS issue_title,
            s.title                AS series,
            i.publish_date,
            COUNT(ic.character_id) AS character_count,
            SUM(i.page_count)      AS total_pages
        FROM issue i
        INNER JOIN series          s  ON i.series_id  = s.series_id
        INNER JOIN issue_character ic ON i.issue_id   = ic.issue_id
        GROUP BY i.issue_id, i.title, s.title, i.publish_date
        HAVING COUNT(ic.character_id) >= p_min_characters
        ORDER BY character_count DESC;
END;
$$;


ALTER FUNCTION public.get_issues_with_character_count(p_min_characters integer) OWNER TO postgres;

--
-- TOC entry 250 (class 1255 OID 32995)
-- Name: get_story_arc_issues(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_story_arc_issues(p_arc_title character varying) RETURNS TABLE(arc_title character varying, part_num smallint, issue_title character varying, publish_date date, series character varying, creator text, role text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
        SELECT
            sa.title                                                   AS arc_title,
            isa.part_num,
            i.title                                                    AS issue_title,
            i.publish_date,
            s.title                                                    AS series,
            COALESCE(cr.first_name || ' ' || cr.last_name, 'Unknown') AS creator,
            COALESCE(ic.role::TEXT, 'N/A')                             AS role
        FROM issue_story_arc isa
        INNER JOIN story_arc     sa ON isa.arc_id     = sa.arc_id
        INNER JOIN issue          i ON isa.issue_id   = i.issue_id
        INNER JOIN series         s ON i.series_id    = s.series_id
        LEFT JOIN  issue_creator ic ON i.issue_id     = ic.issue_id
        LEFT JOIN  creator       cr ON ic.creator_id  = cr.creator_id
        WHERE LOWER(sa.title) LIKE LOWER('%' || p_arc_title || '%')
        ORDER BY isa.part_num, ic.role;
END;
$$;


ALTER FUNCTION public.get_story_arc_issues(p_arc_title character varying) OWNER TO postgres;

--
-- TOC entry 249 (class 1255 OID 32994)
-- Name: search_characters_by_name(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.search_characters_by_name(p_search character varying) RETURNS TABLE(character_name character varying, alignment character varying, name_replaced text, name_reversed text, name_length integer, name_trimmed_len integer, name_substr text, name_left4 text, name_right4 text, pos_of_a integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
        SELECT
            ch.name                                        AS character_name,
            ch.alignment,
            REPLACE(ch.name::TEXT, 'man', 'person')        AS name_replaced,
            REVERSE(ch.name::TEXT)                         AS name_reversed,
            LENGTH(ch.name::TEXT)                          AS name_length,
            LENGTH(TRIM(ch.name::TEXT))                    AS name_trimmed_len,
            SUBSTR(ch.name::TEXT, 1, 5)                    AS name_substr,
            LEFT(ch.name::TEXT, 4)                         AS name_left4,
            RIGHT(ch.name::TEXT, 4)                        AS name_right4,
            POSITION('a' IN LOWER(ch.name::TEXT))          AS pos_of_a
        FROM character ch
        WHERE ch.name LIKE '%' || p_search || '%'   -- % wildcard: match anywhere
           OR ch.name LIKE p_search || '_'           -- _ wildcard: one extra char after term
        ORDER BY ch.name;
END;
$$;


ALTER FUNCTION public.search_characters_by_name(p_search character varying) OWNER TO postgres;

--
-- TOC entry 259 (class 1255 OID 33015)
-- Name: summarize_publisher_stats(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.summarize_publisher_stats() RETURNS TABLE(publisher text, total_series bigint, total_issues bigint, total_revenue numeric, avg_cover_price numeric, cheapest_issue numeric, priciest_issue numeric, earliest_issue date, latest_issue date)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
        SELECT
            COALESCE(p.name::TEXT, '*** GRAND TOTAL ***') AS publisher,
            COUNT(DISTINCT s.series_id)                    AS total_series,
            COUNT(DISTINCT i.issue_id)                     AS total_issues,
            SUM(i.cover_price)                             AS total_revenue,
            ROUND(AVG(i.cover_price), 2)                   AS avg_cover_price,
            MIN(i.cover_price)                             AS cheapest_issue,
            MAX(i.cover_price)                             AS priciest_issue,
            MIN(i.publish_date)                            AS earliest_issue,
            MAX(i.publish_date)                            AS latest_issue
        FROM publisher p
        LEFT JOIN series s ON p.publisher_id = s.publisher_id
        LEFT JOIN issue  i ON s.series_id    = i.series_id
        GROUP BY ROLLUP(p.name)
        ORDER BY total_issues DESC;
END;
$$;


ALTER FUNCTION public.summarize_publisher_stats() OWNER TO postgres;

--
-- TOC entry 255 (class 1255 OID 33001)
-- Name: transfer_series_to_publisher(integer, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.transfer_series_to_publisher(IN p_from_publisher_id integer, IN p_to_publisher_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_from_name    VARCHAR;
    v_to_name      VARCHAR;
    v_series_count INT;
BEGIN
    SELECT name AS publisher_name
    INTO v_from_name
    FROM publisher
    WHERE publisher_id = p_from_publisher_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Source publisher ID % does not exist.', p_from_publisher_id;
    END IF;

    SELECT name AS publisher_name
    INTO v_to_name
    FROM publisher
    WHERE publisher_id = p_to_publisher_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Destination publisher ID % does not exist.', p_to_publisher_id;
    END IF;

    IF p_from_publisher_id = p_to_publisher_id THEN
        RAISE EXCEPTION 'Source and destination publisher cannot be the same.';
    END IF;

    SELECT COUNT(*) AS series_count
    INTO v_series_count
    FROM series
    WHERE publisher_id = p_from_publisher_id;

    IF v_series_count = 0 THEN
        RAISE NOTICE 'Publisher "%" has no series to transfer.', v_from_name;
        RETURN;
    END IF;

    UPDATE series
    SET publisher_id = p_to_publisher_id
    WHERE publisher_id = p_from_publisher_id;

    RAISE NOTICE 'Transferred % series from "%" to "%".', v_series_count, v_from_name, v_to_name;
END;
$$;


ALTER PROCEDURE public.transfer_series_to_publisher(IN p_from_publisher_id integer, IN p_to_publisher_id integer) OWNER TO postgres;

--
-- TOC entry 252 (class 1255 OID 32998)
-- Name: update_series_end_year(integer, smallint); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.update_series_end_year(IN p_series_id integer, IN p_end_year smallint)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_title      VARCHAR;
    v_start_year SMALLINT;
    v_end_year   SMALLINT;
BEGIN
    SELECT title      AS series_title,
           start_year AS series_start,
           end_year   AS series_end
    INTO v_title, v_start_year, v_end_year
    FROM series
    WHERE series_id = p_series_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Series ID % does not exist.', p_series_id;
    END IF;

    IF p_end_year <= v_start_year THEN
        RAISE EXCEPTION 'End year (%) must be after start year (%).', p_end_year, v_start_year;
    END IF;

    IF v_end_year IS NOT NULL THEN
        RAISE NOTICE 'Series "%" already has end year %. Updating to %.', v_title, v_end_year, p_end_year;
    END IF;

    UPDATE series
    SET end_year = p_end_year
    WHERE series_id = p_series_id;

    RAISE NOTICE 'Series "%" end year set to %.', v_title, p_end_year;
END;
$$;


ALTER PROCEDURE public.update_series_end_year(IN p_series_id integer, IN p_end_year smallint) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 229 (class 1259 OID 32915)
-- Name: character; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."character" (
    character_id integer NOT NULL,
    name character varying(100) NOT NULL,
    real_name character varying(100),
    publisher_id integer,
    alignment character varying(10),
    first_appeared date,
    description text,
    CONSTRAINT character_alignment_check CHECK (((alignment)::text = ANY ((ARRAY['Hero'::character varying, 'Villain'::character varying, 'Antihero'::character varying, 'Neutral'::character varying])::text[])))
);


ALTER TABLE public."character" OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 32914)
-- Name: character_character_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.character_character_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.character_character_id_seq OWNER TO postgres;

--
-- TOC entry 5121 (class 0 OID 0)
-- Dependencies: 228
-- Name: character_character_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.character_character_id_seq OWNED BY public."character".character_id;


--
-- TOC entry 224 (class 1259 OID 32868)
-- Name: creator; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.creator (
    creator_id integer NOT NULL,
    first_name character varying(60) NOT NULL,
    last_name character varying(60) NOT NULL,
    birth_year smallint,
    nationality character varying(60),
    bio text
);


ALTER TABLE public.creator OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 32867)
-- Name: creator_creator_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.creator_creator_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.creator_creator_id_seq OWNER TO postgres;

--
-- TOC entry 5122 (class 0 OID 0)
-- Dependencies: 223
-- Name: creator_creator_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.creator_creator_id_seq OWNED BY public.creator.creator_id;


--
-- TOC entry 226 (class 1259 OID 32880)
-- Name: issue; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.issue (
    issue_id integer NOT NULL,
    series_id integer NOT NULL,
    issue_number character varying(10) NOT NULL,
    title character varying(200),
    publish_date date,
    cover_price numeric(5,2),
    page_count smallint,
    notes text
);


ALTER TABLE public.issue OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 32931)
-- Name: issue_character; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.issue_character (
    issue_id integer NOT NULL,
    character_id integer NOT NULL,
    appearance character varying(40) DEFAULT 'Main'::character varying NOT NULL
);


ALTER TABLE public.issue_character OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 32896)
-- Name: issue_creator; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.issue_creator (
    issue_id integer NOT NULL,
    creator_id integer NOT NULL,
    role character varying(60) NOT NULL
);


ALTER TABLE public.issue_creator OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 32879)
-- Name: issue_issue_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.issue_issue_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.issue_issue_id_seq OWNER TO postgres;

--
-- TOC entry 5123 (class 0 OID 0)
-- Dependencies: 225
-- Name: issue_issue_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.issue_issue_id_seq OWNED BY public.issue.issue_id;


--
-- TOC entry 233 (class 1259 OID 32966)
-- Name: issue_story_arc; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.issue_story_arc (
    issue_id integer NOT NULL,
    arc_id integer NOT NULL,
    part_num smallint
);


ALTER TABLE public.issue_story_arc OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 32840)
-- Name: publisher; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.publisher (
    publisher_id integer NOT NULL,
    name character varying(100) NOT NULL,
    founded_year smallint,
    country character varying(60),
    website character varying(200)
);


ALTER TABLE public.publisher OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 32839)
-- Name: publisher_publisher_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.publisher_publisher_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.publisher_publisher_id_seq OWNER TO postgres;

--
-- TOC entry 5124 (class 0 OID 0)
-- Dependencies: 219
-- Name: publisher_publisher_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.publisher_publisher_id_seq OWNED BY public.publisher.publisher_id;


--
-- TOC entry 222 (class 1259 OID 32851)
-- Name: series; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.series (
    series_id integer NOT NULL,
    publisher_id integer NOT NULL,
    title character varying(150) NOT NULL,
    start_year smallint,
    end_year smallint,
    genre character varying(60),
    description text
);


ALTER TABLE public.series OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 32850)
-- Name: series_series_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.series_series_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.series_series_id_seq OWNER TO postgres;

--
-- TOC entry 5125 (class 0 OID 0)
-- Dependencies: 221
-- Name: series_series_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.series_series_id_seq OWNED BY public.series.series_id;


--
-- TOC entry 232 (class 1259 OID 32951)
-- Name: story_arc; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.story_arc (
    arc_id integer NOT NULL,
    title character varying(150) NOT NULL,
    publisher_id integer,
    start_date date,
    end_date date,
    description text
);


ALTER TABLE public.story_arc OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 32950)
-- Name: story_arc_arc_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.story_arc_arc_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.story_arc_arc_id_seq OWNER TO postgres;

--
-- TOC entry 5126 (class 0 OID 0)
-- Dependencies: 231
-- Name: story_arc_arc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.story_arc_arc_id_seq OWNED BY public.story_arc.arc_id;


--
-- TOC entry 235 (class 1259 OID 33010)
-- Name: v_character_appearance_summary; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_character_appearance_summary AS
 SELECT COALESCE(ch.name, 'Unknown'::character varying) AS character_name,
    ch.alignment,
    p.name AS publisher,
    count(ic.issue_id) AS total_appearances
   FROM ((public.issue_character ic
     RIGHT JOIN public."character" ch ON ((ic.character_id = ch.character_id)))
     LEFT JOIN public.publisher p ON ((ch.publisher_id = p.publisher_id)))
  GROUP BY ch.name, ch.alignment, p.name
  ORDER BY (count(ic.issue_id)) DESC;


ALTER VIEW public.v_character_appearance_summary OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 33005)
-- Name: v_publisher_series_summary; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_publisher_series_summary AS
 SELECT p.name AS publisher,
    count(DISTINCT s.series_id) AS total_series,
    count(DISTINCT i.issue_id) AS total_issues
   FROM ((public.publisher p
     LEFT JOIN public.series s ON ((p.publisher_id = s.publisher_id)))
     LEFT JOIN public.issue i ON ((s.series_id = i.series_id)))
  GROUP BY p.name
  ORDER BY (count(DISTINCT i.issue_id)) DESC;


ALTER VIEW public.v_publisher_series_summary OWNER TO postgres;

--
-- TOC entry 4918 (class 2604 OID 32918)
-- Name: character character_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."character" ALTER COLUMN character_id SET DEFAULT nextval('public.character_character_id_seq'::regclass);


--
-- TOC entry 4916 (class 2604 OID 32871)
-- Name: creator creator_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.creator ALTER COLUMN creator_id SET DEFAULT nextval('public.creator_creator_id_seq'::regclass);


--
-- TOC entry 4917 (class 2604 OID 32883)
-- Name: issue issue_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.issue ALTER COLUMN issue_id SET DEFAULT nextval('public.issue_issue_id_seq'::regclass);


--
-- TOC entry 4914 (class 2604 OID 32843)
-- Name: publisher publisher_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.publisher ALTER COLUMN publisher_id SET DEFAULT nextval('public.publisher_publisher_id_seq'::regclass);


--
-- TOC entry 4915 (class 2604 OID 32854)
-- Name: series series_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.series ALTER COLUMN series_id SET DEFAULT nextval('public.series_series_id_seq'::regclass);


--
-- TOC entry 4920 (class 2604 OID 32954)
-- Name: story_arc arc_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.story_arc ALTER COLUMN arc_id SET DEFAULT nextval('public.story_arc_arc_id_seq'::regclass);


--
-- TOC entry 5111 (class 0 OID 32915)
-- Dependencies: 229
-- Data for Name: character; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."character" (character_id, name, real_name, publisher_id, alignment, first_appeared, description) FROM stdin;
1	Neoman	Patricia Davis	5	Antihero	1998-09-17	Master of the arcane arts, wielder of forbidden knowledge.
2	Megaveil	James Williams	7	Hero	1992-01-04	A vigilante who operates outside the law to protect the innocent.
3	Alphastar	Nancy White	8	Villain	1962-12-16	A vigilante who operates outside the law to protect the innocent.
4	Steelmind	John Miller	11	Hero	1972-02-01	A former soldier seeking redemption through heroic deeds.
5	Solarforce	Maria Harris	18	Hero	2020-09-28	A mercenary with a strict personal code of honor.
6	Megalance	Lisa Thomas	19	Hero	1944-03-29	A vigilante who operates outside the law to protect the innocent.
7	Blazeshield	\N	8	Antihero	1972-02-07	Once a villain, now fighting for the side of good.
8	Voltforce	Susan Miller	9	Antihero	1999-04-29	A former soldier seeking redemption through heroic deeds.
9	Quantumwing	Patricia Garcia	15	Hero	2021-01-08	Master of the arcane arts, wielder of forbidden knowledge.
10	Blazestorm	\N	2	Hero	1940-11-17	The last survivor of a destroyed civilization seeking justice.
11	Froststrike	Charles Anderson	7	Villain	1973-06-30	Raised in secret, now unleashed upon a world unprepared.
12	Ironstrike	Nancy Young	9	Antihero	1976-06-08	Driven by tragedy, defined by an unbreakable will.
13	Frostforce	John Thompson	16	Hero	1942-03-24	A former soldier seeking redemption through heroic deeds.
14	Ironwing	\N	14	Villain	1972-07-09	A mercenary with a strict personal code of honor.
15	Quantumclaw	Nancy Smith	4	Villain	1986-03-05	Once a villain, now fighting for the side of good.
16	Thunderblade	Linda Harris	1	Neutral	2016-07-29	Once a villain, now fighting for the side of good.
17	Omegawing	Sarah Taylor	17	Villain	1951-09-18	The last survivor of a destroyed civilization seeking justice.
18	Steellance	\N	17	Neutral	1991-09-26	The last survivor of a destroyed civilization seeking justice.
19	Titanman	Susan Taylor	8	Hero	2016-10-08	Driven by tragedy, defined by an unbreakable will.
20	Megahawk	David Young	5	Hero	1980-08-22	Master of the arcane arts, wielder of forbidden knowledge.
21	Steelstrike	Lisa White	7	Neutral	2005-10-04	Gifted with powers beyond comprehension, burdened by their weight.
22	Neonhunter	\N	12	Villain	1984-06-07	Raised in secret, now unleashed upon a world unprepared.
23	Neofire	William Smith	19	Villain	1990-10-17	Gifted with powers beyond comprehension, burdened by their weight.
24	Ultrahawk	Maria Davis	3	Neutral	2015-02-14	The last survivor of a destroyed civilization seeking justice.
25	Megaarrow	Karen Miller	18	Hero	2021-12-05	Driven by tragedy, defined by an unbreakable will.
26	Plasmabolt	Karen White	7	Hero	1997-02-13	A mercenary with a strict personal code of honor.
27	Solarmind	Maria Brown	2	Villain	1968-06-10	A former soldier seeking redemption through heroic deeds.
28	Blazestar	Joseph Jones	14	Hero	1979-07-04	Gifted with powers beyond comprehension, burdened by their weight.
29	Megaclaw	\N	18	Hero	1996-07-04	Master of the arcane arts, wielder of forbidden knowledge.
30	Blazewing	Karen Miller	13	Neutral	1952-10-08	A mercenary with a strict personal code of honor.
31	Ultrahunter	Joseph Taylor	14	Villain	2003-07-16	Master of the arcane arts, wielder of forbidden knowledge.
32	Titanfist	Robert Johnson	19	Antihero	1943-06-21	The last survivor of a destroyed civilization seeking justice.
33	Hyperwoman	Thomas Thompson	6	Hero	1983-07-24	A former soldier seeking redemption through heroic deeds.
34	Steelhawk	Patricia Jackson	4	Neutral	1989-02-09	Gifted with powers beyond comprehension, burdened by their weight.
35	Plasmawave	David White	19	Villain	1966-05-20	Once a villain, now fighting for the side of good.
36	Shadowstorm	Richard Jones	10	Villain	2021-05-07	A former soldier seeking redemption through heroic deeds.
37	Ultraclaw	Charles Brown	3	Villain	1983-05-21	Once a villain, now fighting for the side of good.
38	Ironforce	\N	8	Hero	1952-02-26	Raised in secret, now unleashed upon a world unprepared.
39	Alphashield	Thomas Smith	18	Hero	1997-07-07	A former soldier seeking redemption through heroic deeds.
40	Neoblade	John Wilson	10	Villain	2002-05-19	The last survivor of a destroyed civilization seeking justice.
41	Shadowstrike	Michael Johnson	3	Villain	2012-05-28	Once a villain, now fighting for the side of good.
42	Hyperman	John Wilson	6	Antihero	1987-06-30	A mercenary with a strict personal code of honor.
43	Alphaman	John Young	2	Antihero	1990-04-05	Master of the arcane arts, wielder of forbidden knowledge.
44	Ironmind	Barbara Thomas	2	Antihero	1956-11-05	Gifted with powers beyond comprehension, burdened by their weight.
45	Neoforce	\N	14	Neutral	2005-03-28	A cosmic entity whose motives remain ambiguous to all.
46	Ultrawing	William White	8	Hero	2008-08-21	A former soldier seeking redemption through heroic deeds.
47	Frostwoman	\N	8	Hero	2020-05-25	Raised in secret, now unleashed upon a world unprepared.
48	Solarshield	\N	8	Hero	1997-03-19	Gifted with powers beyond comprehension, burdened by their weight.
49	Froststorm	David Wilson	12	Villain	1973-11-09	Master of the arcane arts, wielder of forbidden knowledge.
50	Thunderman	Michael Garcia	19	Neutral	1961-10-25	A vigilante who operates outside the law to protect the innocent.
51	Neowave	William White	20	Neutral	1948-05-17	A mercenary with a strict personal code of honor.
52	Plasmastar	Jessica Smith	17	Neutral	1986-04-22	Gifted with powers beyond comprehension, burdened by their weight.
53	Megastorm	Sarah Taylor	17	Hero	1974-08-22	The last survivor of a destroyed civilization seeking justice.
54	Frostshield	Robert White	13	Villain	2018-12-30	A cosmic entity whose motives remain ambiguous to all.
55	Quantumveil	Nancy Smith	10	Hero	1976-07-26	Driven by tragedy, defined by an unbreakable will.
56	Quantumstorm	Joseph Miller	17	Villain	2018-11-06	A cosmic entity whose motives remain ambiguous to all.
57	Megashield	Lisa Anderson	3	Antihero	2005-05-22	Gifted with powers beyond comprehension, burdened by their weight.
58	Neonfire	\N	5	Hero	1959-12-20	Raised in secret, now unleashed upon a world unprepared.
59	Quantumhawk	Charles Miller	13	Villain	1959-11-21	A cosmic entity whose motives remain ambiguous to all.
60	Ultrablade	\N	8	Hero	2023-12-11	Master of the arcane arts, wielder of forbidden knowledge.
61	Voltwoman	Sarah Harris	5	Antihero	1997-11-22	Master of the arcane arts, wielder of forbidden knowledge.
62	Alphawave	Joseph Lewis	17	Villain	2019-05-11	Master of the arcane arts, wielder of forbidden knowledge.
63	Voltwing	Karen Harris	9	Antihero	2013-05-07	Once a villain, now fighting for the side of good.
64	Omegabolt	Michael Harris	3	Antihero	1959-01-14	Once a villain, now fighting for the side of good.
65	Thunderstorm	\N	3	Hero	1958-09-30	A mercenary with a strict personal code of honor.
66	Ironstar	Jessica Anderson	18	Villain	1943-08-03	Gifted with powers beyond comprehension, burdened by their weight.
67	Acidhunter	\N	19	Neutral	1939-10-03	Driven by tragedy, defined by an unbreakable will.
68	Frostbolt	Susan Taylor	13	Antihero	2023-07-16	A mercenary with a strict personal code of honor.
69	Alphalance	\N	8	Villain	1962-06-27	A mercenary with a strict personal code of honor.
70	Frostwing	\N	5	Neutral	1985-12-02	A vigilante who operates outside the law to protect the innocent.
71	Frostveil	James Williams	14	Hero	1979-06-03	A cosmic entity whose motives remain ambiguous to all.
72	Hyperstrike	Robert Harris	11	Hero	2016-12-01	A mercenary with a strict personal code of honor.
73	Voidmind	David Martin	1	Antihero	1942-09-03	The last survivor of a destroyed civilization seeking justice.
74	Blazehawk	\N	2	Antihero	2023-03-12	Gifted with powers beyond comprehension, burdened by their weight.
75	Shadowman	Patricia Jones	16	Villain	1988-08-06	Gifted with powers beyond comprehension, burdened by their weight.
76	Voltstrike	\N	6	Villain	2005-02-06	A former soldier seeking redemption through heroic deeds.
77	Steelshield	James Taylor	19	Villain	2023-12-18	A mercenary with a strict personal code of honor.
78	Froststar	Patricia Brown	10	Antihero	1991-11-13	A former soldier seeking redemption through heroic deeds.
79	Plasmawoman	Jessica Thomas	3	Villain	1968-08-12	A vigilante who operates outside the law to protect the innocent.
80	Acidbolt	Susan Harris	5	Villain	2003-11-01	Master of the arcane arts, wielder of forbidden knowledge.
81	Voidwave	\N	18	Antihero	1979-09-15	A mercenary with a strict personal code of honor.
82	Plasmastrike	Patricia Williams	9	Antihero	1959-11-17	Raised in secret, now unleashed upon a world unprepared.
83	Ultrabolt	\N	6	Villain	1969-10-31	Once a villain, now fighting for the side of good.
84	Thunderstrike	\N	9	Villain	1984-05-07	Gifted with powers beyond comprehension, burdened by their weight.
85	Megafire	Karen Young	8	Villain	1995-12-12	Raised in secret, now unleashed upon a world unprepared.
86	Voltman	Patricia Jackson	8	Hero	1990-03-05	The last survivor of a destroyed civilization seeking justice.
87	Titanlance	Jessica Young	11	Hero	1978-09-16	Once a villain, now fighting for the side of good.
88	Neonstrike	Robert Anderson	4	Antihero	2023-04-23	A cosmic entity whose motives remain ambiguous to all.
89	Shadowstar	Michael Robinson	17	Villain	1947-01-08	Gifted with powers beyond comprehension, burdened by their weight.
90	Solarwing	Nancy Jones	9	Hero	1942-11-22	Master of the arcane arts, wielder of forbidden knowledge.
91	Neonfist	Karen Brown	1	Villain	1980-02-11	Raised in secret, now unleashed upon a world unprepared.
92	Voltstorm	Maria Wilson	16	Hero	1943-11-12	A mercenary with a strict personal code of honor.
93	Titanhawk	Maria Jones	5	Antihero	2023-02-24	Once a villain, now fighting for the side of good.
94	Neolance	\N	20	Villain	1993-06-25	Gifted with powers beyond comprehension, burdened by their weight.
95	Omegahunter	Joseph Taylor	19	Neutral	1965-05-25	Driven by tragedy, defined by an unbreakable will.
96	Quantumwoman	Sarah Miller	7	Hero	1945-04-14	A cosmic entity whose motives remain ambiguous to all.
97	Alphahawk	Jessica Harris	20	Villain	1940-12-05	Gifted with powers beyond comprehension, burdened by their weight.
98	Neonshield	Joseph Williams	8	Neutral	2008-09-05	Driven by tragedy, defined by an unbreakable will.
99	Shadowmind	Patricia Jones	9	Antihero	1944-05-28	A vigilante who operates outside the law to protect the innocent.
100	Neonclaw	Barbara Jackson	9	Villain	1982-04-20	Raised in secret, now unleashed upon a world unprepared.
101	Megawave	Jessica Anderson	20	Hero	1946-03-12	Gifted with powers beyond comprehension, burdened by their weight.
102	Plasmaveil	\N	9	Villain	2006-06-18	A cosmic entity whose motives remain ambiguous to all.
103	Titanarrow	Michael Garcia	19	Villain	2011-01-19	Raised in secret, now unleashed upon a world unprepared.
104	Megabolt	William Anderson	4	Antihero	1967-08-04	A mercenary with a strict personal code of honor.
105	Titanshield	Richard Young	2	Villain	1966-03-21	Once a villain, now fighting for the side of good.
106	Frostarrow	\N	1	Villain	1986-09-05	Raised in secret, now unleashed upon a world unprepared.
107	Acidwoman	Susan Lewis	16	Villain	2006-03-08	A vigilante who operates outside the law to protect the innocent.
108	Alphafist	\N	15	Antihero	1981-06-27	A former soldier seeking redemption through heroic deeds.
109	Ultrawave	\N	6	Hero	1939-03-25	Master of the arcane arts, wielder of forbidden knowledge.
110	Acidhawk	Sarah Harris	4	Villain	1951-10-25	Raised in secret, now unleashed upon a world unprepared.
111	Neonarrow	Jessica Martin	16	Hero	1987-06-16	A cosmic entity whose motives remain ambiguous to all.
112	Quantumarrow	John Williams	9	Antihero	2014-08-27	A mercenary with a strict personal code of honor.
113	Thunderarrow	James Taylor	10	Antihero	1990-01-10	Raised in secret, now unleashed upon a world unprepared.
114	Ironclaw	Susan Anderson	18	Antihero	1971-11-04	Raised in secret, now unleashed upon a world unprepared.
115	Thunderstar	\N	8	Villain	1958-12-15	A mercenary with a strict personal code of honor.
116	Hyperstorm	Richard Jackson	5	Villain	1941-04-28	A cosmic entity whose motives remain ambiguous to all.
117	Omegaveil	Sarah Harris	4	Villain	1978-12-29	A vigilante who operates outside the law to protect the innocent.
118	Ironhawk	Michael Anderson	20	Villain	1996-04-19	A former soldier seeking redemption through heroic deeds.
119	Thunderlance	William Martin	18	Hero	1944-02-21	Gifted with powers beyond comprehension, burdened by their weight.
120	Megamind	\N	4	Villain	2000-04-06	Once a villain, now fighting for the side of good.
121	Ultrawoman	Maria Taylor	12	Hero	1951-01-23	Gifted with powers beyond comprehension, burdened by their weight.
122	Omegamind	Linda Garcia	6	Hero	2016-02-16	A mercenary with a strict personal code of honor.
123	Quantumfire	Charles Jones	8	Villain	1960-10-14	Raised in secret, now unleashed upon a world unprepared.
124	Voidman	\N	15	Neutral	1998-10-16	Master of the arcane arts, wielder of forbidden knowledge.
125	Plasmashield	Jessica Wilson	15	Antihero	1955-11-15	A mercenary with a strict personal code of honor.
126	Titanblade	Charles Thomas	19	Hero	2000-09-25	Once a villain, now fighting for the side of good.
127	Quantumbolt	\N	10	Antihero	1958-08-24	Driven by tragedy, defined by an unbreakable will.
128	Solarfire	Lisa Wilson	5	Villain	2019-01-18	A vigilante who operates outside the law to protect the innocent.
129	Hyperveil	John Williams	10	Hero	1975-04-12	A cosmic entity whose motives remain ambiguous to all.
130	Shadowfist	\N	12	Villain	2019-12-15	Once a villain, now fighting for the side of good.
131	Volthawk	Patricia Jackson	18	Hero	2008-12-08	A mercenary with a strict personal code of honor.
132	Ultrastrike	Joseph Thomas	9	Villain	2011-10-13	The last survivor of a destroyed civilization seeking justice.
133	Quantumlance	Lisa Davis	3	Villain	1979-08-27	Once a villain, now fighting for the side of good.
134	Acidblade	Maria Taylor	16	Hero	1959-01-24	Master of the arcane arts, wielder of forbidden knowledge.
135	Ironhunter	Nancy White	19	Antihero	1951-11-12	A mercenary with a strict personal code of honor.
136	Neobolt	Michael Johnson	12	Hero	1977-11-23	Gifted with powers beyond comprehension, burdened by their weight.
137	Solarblade	\N	12	Villain	1995-11-07	The last survivor of a destroyed civilization seeking justice.
138	Hyperhunter	Sarah Harris	3	Villain	1995-07-28	Driven by tragedy, defined by an unbreakable will.
139	Thunderfire	\N	19	Hero	2012-06-12	Master of the arcane arts, wielder of forbidden knowledge.
140	Shadowveil	Patricia Anderson	5	Antihero	1991-06-21	A vigilante who operates outside the law to protect the innocent.
141	Voidfist	\N	18	Hero	1953-08-27	A former soldier seeking redemption through heroic deeds.
142	Ultrafist	Patricia Robinson	11	Hero	1961-10-22	A vigilante who operates outside the law to protect the innocent.
143	Omegablade	Karen Harris	12	Villain	1947-10-14	Raised in secret, now unleashed upon a world unprepared.
144	Omegafire	\N	2	Antihero	2019-07-12	Master of the arcane arts, wielder of forbidden knowledge.
145	Titanhunter	Sarah Martin	15	Hero	1945-04-01	The last survivor of a destroyed civilization seeking justice.
146	Quantumfist	Michael Lewis	19	Villain	1967-03-05	A mercenary with a strict personal code of honor.
147	Omegawave	Sarah Young	7	Villain	2017-09-03	Gifted with powers beyond comprehension, burdened by their weight.
148	Acidstorm	\N	13	Villain	1946-07-13	The last survivor of a destroyed civilization seeking justice.
149	Voidforce	\N	16	Hero	2012-08-15	A former soldier seeking redemption through heroic deeds.
150	Ironlance	Nancy Young	11	Villain	1974-11-09	The last survivor of a destroyed civilization seeking justice.
151	Neonwave	Sarah Robinson	17	Hero	1996-12-01	Raised in secret, now unleashed upon a world unprepared.
152	Blazeblade	Nancy Thomas	4	Antihero	1989-07-04	Gifted with powers beyond comprehension, burdened by their weight.
153	Acidlance	\N	20	Villain	1995-08-29	Master of the arcane arts, wielder of forbidden knowledge.
154	Neonstorm	Linda Jones	19	Villain	1944-03-30	A cosmic entity whose motives remain ambiguous to all.
155	Omegastar	Joseph Anderson	6	Hero	2002-09-27	The last survivor of a destroyed civilization seeking justice.
156	Megawoman	Lisa Johnson	3	Hero	1997-05-21	A mercenary with a strict personal code of honor.
157	Titanwave	Michael Miller	17	Hero	1976-07-27	A former soldier seeking redemption through heroic deeds.
158	Neonveil	Barbara Johnson	8	Hero	1991-10-08	A vigilante who operates outside the law to protect the innocent.
159	Ultrastar	Robert Jones	9	Hero	1948-10-06	A vigilante who operates outside the law to protect the innocent.
160	Titanmind	Richard Young	8	Villain	2012-10-06	The last survivor of a destroyed civilization seeking justice.
161	Megahunter	\N	2	Villain	1979-04-01	A former soldier seeking redemption through heroic deeds.
162	Thunderveil	Richard White	10	Hero	1939-11-15	The last survivor of a destroyed civilization seeking justice.
163	Steelwave	Susan Williams	14	Antihero	1959-10-30	A mercenary with a strict personal code of honor.
164	Plasmahunter	Richard Taylor	11	Hero	2007-11-25	A cosmic entity whose motives remain ambiguous to all.
165	Neoarrow	Susan Thomas	5	Hero	1951-02-20	Once a villain, now fighting for the side of good.
166	Shadowwing	David Garcia	16	Villain	1988-07-29	Driven by tragedy, defined by an unbreakable will.
167	Voltveil	Lisa Anderson	11	Hero	1944-02-16	Raised in secret, now unleashed upon a world unprepared.
168	Voltshield	\N	19	Hero	1983-07-08	A former soldier seeking redemption through heroic deeds.
169	Hyperforce	\N	3	Villain	2014-09-25	A former soldier seeking redemption through heroic deeds.
170	Quantumwave	Joseph Robinson	18	Neutral	2004-04-16	A vigilante who operates outside the law to protect the innocent.
171	Omegafist	\N	15	Hero	2018-08-31	The last survivor of a destroyed civilization seeking justice.
172	Steelwoman	Joseph Harris	17	Villain	1952-03-29	The last survivor of a destroyed civilization seeking justice.
173	Frostmind	\N	20	Hero	1994-08-07	The last survivor of a destroyed civilization seeking justice.
174	Ironstorm	John Thomas	10	Neutral	2000-08-30	A mercenary with a strict personal code of honor.
175	Ironwave	David Taylor	18	Hero	2009-01-09	The last survivor of a destroyed civilization seeking justice.
176	Ironarrow	Jessica Thompson	12	Hero	1965-09-16	A cosmic entity whose motives remain ambiguous to all.
177	Titanstar	John Jones	3	Hero	2008-09-15	A former soldier seeking redemption through heroic deeds.
178	Omegalance	\N	17	Hero	1968-03-19	Driven by tragedy, defined by an unbreakable will.
179	Frostfist	Lisa Garcia	15	Hero	1970-09-07	Gifted with powers beyond comprehension, burdened by their weight.
180	Voltwave	Joseph Davis	18	Hero	2010-07-18	Raised in secret, now unleashed upon a world unprepared.
181	Shadowforce	Charles Harris	15	Antihero	2007-10-23	A mercenary with a strict personal code of honor.
182	Omegaarrow	Linda Miller	20	Hero	1960-06-06	A vigilante who operates outside the law to protect the innocent.
183	Titanforce	Sarah Thompson	4	Hero	2006-06-18	A cosmic entity whose motives remain ambiguous to all.
184	Voidclaw	\N	5	Antihero	1946-03-25	Gifted with powers beyond comprehension, burdened by their weight.
185	Ultramind	Thomas Thomas	8	Hero	1945-04-28	The last survivor of a destroyed civilization seeking justice.
186	Blazeman	Sarah Anderson	5	Hero	1963-09-27	Raised in secret, now unleashed upon a world unprepared.
187	Ironbolt	James Williams	1	Hero	2012-11-28	A cosmic entity whose motives remain ambiguous to all.
188	Neoshield	Sarah Johnson	8	Villain	2009-03-23	Driven by tragedy, defined by an unbreakable will.
189	Ultraarrow	John Taylor	14	Hero	1969-08-27	Gifted with powers beyond comprehension, burdened by their weight.
190	Plasmamind	David Thompson	12	Hero	1985-03-12	Master of the arcane arts, wielder of forbidden knowledge.
191	Solarstrike	Susan Williams	12	Hero	1996-12-13	A former soldier seeking redemption through heroic deeds.
192	Plasmastorm	Susan Young	11	Antihero	1953-09-16	Raised in secret, now unleashed upon a world unprepared.
193	Titanwing	\N	3	Antihero	2022-08-28	Raised in secret, now unleashed upon a world unprepared.
194	Hypershield	Robert Johnson	11	Neutral	1984-03-28	A mercenary with a strict personal code of honor.
195	Alphabolt	Robert Taylor	12	Antihero	1942-04-16	The last survivor of a destroyed civilization seeking justice.
196	Voidblade	\N	14	Antihero	2004-09-07	Raised in secret, now unleashed upon a world unprepared.
197	Steelbolt	Susan Thompson	9	Antihero	2003-03-26	A mercenary with a strict personal code of honor.
198	Acidwing	Susan Harris	2	Antihero	2019-10-14	The last survivor of a destroyed civilization seeking justice.
199	Quantummind	Maria Williams	13	Hero	2009-11-14	A cosmic entity whose motives remain ambiguous to all.
200	Hyperfist	Susan Thomas	13	Neutral	1940-11-27	Driven by tragedy, defined by an unbreakable will.
201	Plasmafist	Richard Anderson	9	Hero	1948-03-06	A vigilante who operates outside the law to protect the innocent.
202	Alphablade	Michael Harris	7	Neutral	1963-08-15	Raised in secret, now unleashed upon a world unprepared.
203	Shadowblade	David Harris	6	Antihero	1977-12-07	A former soldier seeking redemption through heroic deeds.
204	Thunderforce	Nancy Young	10	Antihero	2014-05-19	A cosmic entity whose motives remain ambiguous to all.
205	Steelforce	Sarah Miller	5	Hero	1982-04-28	A vigilante who operates outside the law to protect the innocent.
206	Solarlance	Joseph Young	5	Villain	1945-09-26	A former soldier seeking redemption through heroic deeds.
207	Acidmind	\N	3	Hero	1966-06-11	A former soldier seeking redemption through heroic deeds.
208	Voltclaw	Susan Jones	18	Villain	1954-04-29	A cosmic entity whose motives remain ambiguous to all.
209	Acidarrow	\N	2	Antihero	1984-06-25	A cosmic entity whose motives remain ambiguous to all.
210	Neonwing	Patricia Thomas	17	Antihero	2013-11-22	A former soldier seeking redemption through heroic deeds.
211	Voidstar	Nancy Wilson	5	Villain	1993-02-14	Master of the arcane arts, wielder of forbidden knowledge.
212	Steelveil	\N	5	Hero	1994-01-09	Driven by tragedy, defined by an unbreakable will.
213	Acidwave	Karen Young	10	Villain	1965-02-07	Raised in secret, now unleashed upon a world unprepared.
214	Blazehunter	David Johnson	6	Villain	1981-06-11	Raised in secret, now unleashed upon a world unprepared.
215	Solarhunter	Susan Thompson	18	Hero	1959-09-09	Raised in secret, now unleashed upon a world unprepared.
216	Neostrike	John Brown	2	Hero	1972-06-18	Driven by tragedy, defined by an unbreakable will.
217	Acidfire	\N	6	Antihero	2021-10-09	Driven by tragedy, defined by an unbreakable will.
218	Omegaclaw	Barbara Martin	1	Hero	1973-04-12	Master of the arcane arts, wielder of forbidden knowledge.
219	Voltfire	Susan Johnson	2	Hero	1991-08-10	Raised in secret, now unleashed upon a world unprepared.
220	Neonlance	Sarah White	5	Antihero	2003-04-08	The last survivor of a destroyed civilization seeking justice.
221	Neonhawk	Joseph Young	9	Antihero	1993-11-30	Driven by tragedy, defined by an unbreakable will.
222	Neofist	\N	13	Hero	1968-06-03	Master of the arcane arts, wielder of forbidden knowledge.
223	Solarfist	Thomas Jackson	17	Hero	1941-06-29	A cosmic entity whose motives remain ambiguous to all.
224	Thunderbolt	John Lewis	17	Hero	2021-07-23	Driven by tragedy, defined by an unbreakable will.
225	Thunderwing	Lisa Taylor	19	Hero	2012-04-23	Master of the arcane arts, wielder of forbidden knowledge.
226	Solarstorm	Jessica Robinson	10	Antihero	2003-01-27	A vigilante who operates outside the law to protect the innocent.
227	Voidveil	Maria Robinson	16	Hero	1994-06-07	Driven by tragedy, defined by an unbreakable will.
228	Blazewoman	Sarah Miller	1	Villain	1975-07-28	A cosmic entity whose motives remain ambiguous to all.
229	Acidstar	Lisa Martin	2	Antihero	1984-07-14	Gifted with powers beyond comprehension, burdened by their weight.
230	Alphastorm	\N	16	Villain	1966-02-24	A cosmic entity whose motives remain ambiguous to all.
231	Voltlance	Susan Wilson	20	Villain	2023-11-21	Gifted with powers beyond comprehension, burdened by their weight.
232	Voidlance	Barbara Taylor	7	Villain	1981-11-14	The last survivor of a destroyed civilization seeking justice.
233	Alphastrike	Charles Young	13	Antihero	1973-05-25	The last survivor of a destroyed civilization seeking justice.
234	Ironshield	David Thomas	15	Villain	2005-01-17	Raised in secret, now unleashed upon a world unprepared.
235	Ironblade	Charles Davis	8	Hero	2019-03-18	Master of the arcane arts, wielder of forbidden knowledge.
236	Blazefire	Jessica Anderson	16	Hero	2007-02-24	A cosmic entity whose motives remain ambiguous to all.
237	Ultralance	\N	6	Villain	2021-11-20	Raised in secret, now unleashed upon a world unprepared.
238	Neonwoman	\N	3	Villain	1958-11-01	Master of the arcane arts, wielder of forbidden knowledge.
239	Hyperwing	Linda Johnson	13	Antihero	1954-09-19	Once a villain, now fighting for the side of good.
240	Quantumblade	\N	11	Hero	1995-07-15	Master of the arcane arts, wielder of forbidden knowledge.
241	Steelman	Barbara Robinson	7	Hero	2014-10-23	A mercenary with a strict personal code of honor.
242	Thunderhawk	Sarah Garcia	5	Villain	2021-12-16	Gifted with powers beyond comprehension, burdened by their weight.
243	Frostfire	Michael Anderson	10	Villain	1989-05-25	A vigilante who operates outside the law to protect the innocent.
244	Neoclaw	Richard Thompson	10	Villain	1995-04-21	Once a villain, now fighting for the side of good.
245	Solarwave	John Martin	5	Villain	1992-05-05	The last survivor of a destroyed civilization seeking justice.
246	Shadowfire	Lisa Williams	17	Villain	2001-02-20	The last survivor of a destroyed civilization seeking justice.
247	Neowoman	\N	17	Hero	1986-02-23	A cosmic entity whose motives remain ambiguous to all.
248	Steelstorm	\N	15	Hero	1956-06-05	Driven by tragedy, defined by an unbreakable will.
249	Hyperclaw	Jessica Harris	19	Hero	1979-06-26	Once a villain, now fighting for the side of good.
250	Acidforce	Nancy Johnson	3	Neutral	1980-05-08	A vigilante who operates outside the law to protect the innocent.
251	Neonmind	John White	12	Neutral	1972-04-25	Raised in secret, now unleashed upon a world unprepared.
252	Frosthunter	Nancy Jones	12	Hero	1986-03-14	A mercenary with a strict personal code of honor.
253	Ultrashield	Nancy White	18	Hero	1958-08-09	Gifted with powers beyond comprehension, burdened by their weight.
254	Hypermind	James Davis	7	Hero	1991-04-15	A vigilante who operates outside the law to protect the innocent.
255	Hyperfire	Richard Harris	8	Villain	2005-09-05	A vigilante who operates outside the law to protect the innocent.
256	Acidshield	Nancy Robinson	6	Villain	1976-04-29	Master of the arcane arts, wielder of forbidden knowledge.
257	Titanwoman	\N	13	Antihero	1966-08-06	A mercenary with a strict personal code of honor.
258	Acidfist	Linda Young	16	Hero	1958-03-21	Once a villain, now fighting for the side of good.
259	Hyperlance	Jessica Young	17	Hero	1959-10-15	Once a villain, now fighting for the side of good.
260	Solarhawk	Robert Johnson	9	Hero	1992-04-10	Driven by tragedy, defined by an unbreakable will.
261	Hyperhawk	Charles Young	7	Villain	2016-01-02	The last survivor of a destroyed civilization seeking justice.
262	Neonman	Robert Brown	16	Neutral	2000-05-29	Driven by tragedy, defined by an unbreakable will.
263	Shadowhunter	\N	18	Hero	1963-05-25	A mercenary with a strict personal code of honor.
264	Voltblade	\N	16	Antihero	1966-09-24	Gifted with powers beyond comprehension, burdened by their weight.
265	Plasmafire	James Wilson	18	Neutral	1989-12-16	A mercenary with a strict personal code of honor.
266	Titanbolt	Susan Garcia	5	Antihero	1981-10-23	A cosmic entity whose motives remain ambiguous to all.
267	Alphawoman	David Johnson	1	Villain	2013-08-03	Gifted with powers beyond comprehension, burdened by their weight.
268	Megafist	Thomas Harris	12	Hero	1995-03-20	Driven by tragedy, defined by an unbreakable will.
269	Ultraman	Jessica Smith	1	Villain	1962-08-25	Master of the arcane arts, wielder of forbidden knowledge.
270	Steelblade	\N	17	Hero	1955-03-22	Driven by tragedy, defined by an unbreakable will.
271	Omegastrike	\N	9	Antihero	1945-02-02	The last survivor of a destroyed civilization seeking justice.
272	Frostclaw	Patricia Taylor	3	Villain	2014-12-30	A vigilante who operates outside the law to protect the innocent.
273	Titanstrike	David Wilson	18	Villain	1940-12-14	A cosmic entity whose motives remain ambiguous to all.
274	Blazeveil	\N	13	Villain	1986-07-01	The last survivor of a destroyed civilization seeking justice.
275	Solarwoman	Patricia Williams	11	Villain	1993-01-27	Driven by tragedy, defined by an unbreakable will.
276	Voltbolt	Nancy Jackson	14	Hero	1990-07-24	A mercenary with a strict personal code of honor.
277	Megaman	\N	15	Hero	1962-03-15	A former soldier seeking redemption through heroic deeds.
278	Alphaarrow	James Williams	12	Villain	1991-07-22	Driven by tragedy, defined by an unbreakable will.
279	Thunderhunter	Jessica Jackson	3	Antihero	1988-03-13	Gifted with powers beyond comprehension, burdened by their weight.
280	Plasmaarrow	Richard Garcia	5	Hero	1962-01-30	Raised in secret, now unleashed upon a world unprepared.
281	Neonbolt	\N	12	Hero	1960-02-15	Raised in secret, now unleashed upon a world unprepared.
282	Shadowclaw	Barbara Smith	13	Hero	1993-08-22	A mercenary with a strict personal code of honor.
283	Thunderclaw	Lisa Jones	10	Hero	2022-12-26	Gifted with powers beyond comprehension, burdened by their weight.
284	Titanstorm	Richard Anderson	10	Antihero	1994-10-12	Raised in secret, now unleashed upon a world unprepared.
285	Voidhunter	Charles Miller	19	Neutral	1954-02-21	Master of the arcane arts, wielder of forbidden knowledge.
286	Blazestrike	Jessica Jackson	3	Villain	1991-08-24	Raised in secret, now unleashed upon a world unprepared.
287	Megablade	\N	12	Hero	1992-12-19	A vigilante who operates outside the law to protect the innocent.
288	Thundermind	Sarah Wilson	8	Villain	1984-07-17	Master of the arcane arts, wielder of forbidden knowledge.
289	Blazeclaw	Joseph Robinson	17	Hero	1940-03-15	Raised in secret, now unleashed upon a world unprepared.
290	Shadowarrow	Karen Brown	15	Antihero	1978-08-04	The last survivor of a destroyed civilization seeking justice.
291	Hyperblade	William Brown	6	Neutral	2004-06-07	Gifted with powers beyond comprehension, burdened by their weight.
292	Alphawing	Jessica Harris	8	Antihero	1994-07-01	A cosmic entity whose motives remain ambiguous to all.
293	Frostman	Robert Harris	19	Villain	1938-05-26	Gifted with powers beyond comprehension, burdened by their weight.
294	Voidbolt	William Lewis	13	Villain	1990-08-30	A former soldier seeking redemption through heroic deeds.
295	Neowing	John Thompson	13	Villain	1950-05-15	Driven by tragedy, defined by an unbreakable will.
296	Solarman	Robert Jackson	18	Villain	1982-05-29	A mercenary with a strict personal code of honor.
297	Plasmaman	\N	8	Hero	1962-08-29	Gifted with powers beyond comprehension, burdened by their weight.
298	Steelclaw	Karen Young	17	Hero	1948-03-31	Once a villain, now fighting for the side of good.
299	Alphaforce	Maria Harris	18	Hero	1976-02-22	A former soldier seeking redemption through heroic deeds.
300	Thundershield	Michael Thompson	4	Hero	2005-04-18	A mercenary with a strict personal code of honor.
301	Ironfist	William Davis	13	Villain	1989-10-21	Once a villain, now fighting for the side of good.
302	Solarclaw	\N	11	Villain	2015-12-15	A former soldier seeking redemption through heroic deeds.
303	Thunderwoman	Joseph Smith	4	Neutral	1952-03-04	Raised in secret, now unleashed upon a world unprepared.
304	Megaforce	Susan Garcia	2	Hero	1965-05-29	Gifted with powers beyond comprehension, burdened by their weight.
305	Shadowbolt	Charles Davis	17	Villain	1938-11-01	A vigilante who operates outside the law to protect the innocent.
306	Neostorm	Barbara Jones	13	Antihero	2005-07-27	A cosmic entity whose motives remain ambiguous to all.
307	Solarstar	John White	20	Villain	2015-02-25	Gifted with powers beyond comprehension, burdened by their weight.
308	Thunderfist	David Davis	18	Villain	2002-09-13	Driven by tragedy, defined by an unbreakable will.
309	Neonstar	Thomas Miller	13	Hero	1942-11-24	Gifted with powers beyond comprehension, burdened by their weight.
310	Ultraforce	\N	5	Hero	2013-04-08	Driven by tragedy, defined by an unbreakable will.
311	Ultraveil	Michael Miller	2	Neutral	2023-02-10	A mercenary with a strict personal code of honor.
312	Omegashield	Thomas White	14	Antihero	1945-05-24	Master of the arcane arts, wielder of forbidden knowledge.
313	Voidwing	Michael Brown	1	Hero	1976-07-08	Once a villain, now fighting for the side of good.
314	Omegahawk	Charles Williams	16	Villain	1970-04-23	A vigilante who operates outside the law to protect the innocent.
315	Titanveil	Linda Wilson	4	Antihero	1998-06-24	A former soldier seeking redemption through heroic deeds.
316	Blazearrow	James Davis	2	Villain	1972-05-11	A cosmic entity whose motives remain ambiguous to all.
317	Alphamind	Patricia White	11	Hero	1944-12-27	Driven by tragedy, defined by an unbreakable will.
318	Omegawoman	Thomas Johnson	13	Hero	1979-09-23	Once a villain, now fighting for the side of good.
319	Solarveil	\N	7	Antihero	1987-01-13	Gifted with powers beyond comprehension, burdened by their weight.
320	Ironman	\N	1	Hero	1969-01-29	A vigilante who operates outside the law to protect the innocent.
321	Neostar	Patricia White	16	Neutral	1950-10-10	Once a villain, now fighting for the side of good.
322	Plasmablade	Richard Williams	19	Villain	1977-01-09	A cosmic entity whose motives remain ambiguous to all.
323	Voidstorm	\N	13	Antihero	2003-12-22	The last survivor of a destroyed civilization seeking justice.
324	Voidfire	Robert Jones	19	Hero	1947-06-25	A cosmic entity whose motives remain ambiguous to all.
325	Neohawk	Barbara Lewis	2	Hero	2014-11-06	The last survivor of a destroyed civilization seeking justice.
326	Blazeforce	Maria Taylor	9	Antihero	1953-08-07	A vigilante who operates outside the law to protect the innocent.
327	Blazefist	Richard Thomas	3	Villain	1961-03-22	A former soldier seeking redemption through heroic deeds.
328	Ironwoman	Lisa Davis	10	Villain	2017-03-13	Master of the arcane arts, wielder of forbidden knowledge.
329	Megastrike	Jessica Miller	17	Hero	2009-12-19	Master of the arcane arts, wielder of forbidden knowledge.
330	Solarbolt	Karen Thomas	19	Villain	1972-11-04	Once a villain, now fighting for the side of good.
331	Thunderwave	Michael Johnson	16	Villain	2006-10-18	Driven by tragedy, defined by an unbreakable will.
332	Steelwing	William Thomas	19	Hero	2000-11-06	The last survivor of a destroyed civilization seeking justice.
333	Ironveil	\N	16	Villain	1953-10-01	Raised in secret, now unleashed upon a world unprepared.
334	Quantumforce	Charles Garcia	13	Hero	1999-10-08	Once a villain, now fighting for the side of good.
335	Voltmind	\N	14	Villain	1971-12-23	The last survivor of a destroyed civilization seeking justice.
336	Alphahunter	Karen Robinson	8	Hero	1944-08-12	A vigilante who operates outside the law to protect the innocent.
337	Plasmalance	\N	5	Hero	1938-05-06	A mercenary with a strict personal code of honor.
338	Blazebolt	Richard Johnson	17	Villain	1984-05-14	Driven by tragedy, defined by an unbreakable will.
339	Frostlance	William Wilson	17	Villain	2016-05-12	A vigilante who operates outside the law to protect the innocent.
340	Neomind	Charles Robinson	19	Antihero	2022-04-20	A former soldier seeking redemption through heroic deeds.
341	Neoveil	\N	10	Antihero	2016-12-17	The last survivor of a destroyed civilization seeking justice.
342	Acidstrike	Karen Robinson	20	Villain	1953-06-13	Once a villain, now fighting for the side of good.
343	Megastar	Jessica Martin	17	Antihero	2011-08-29	A vigilante who operates outside the law to protect the innocent.
344	Steelstar	\N	7	Antihero	1960-05-20	A vigilante who operates outside the law to protect the innocent.
345	Voltarrow	Sarah Smith	8	Hero	1991-04-18	Raised in secret, now unleashed upon a world unprepared.
346	Ultrafire	Barbara Wilson	14	Antihero	2014-05-26	The last survivor of a destroyed civilization seeking justice.
347	Quantumhunter	James Thompson	12	Villain	1991-04-09	Driven by tragedy, defined by an unbreakable will.
348	Voidstrike	Barbara Miller	5	Villain	1959-07-24	A vigilante who operates outside the law to protect the innocent.
349	Blazelance	Karen Thomas	17	Hero	1953-04-02	Master of the arcane arts, wielder of forbidden knowledge.
350	Plasmaclaw	Linda Williams	16	Hero	1953-11-12	The last survivor of a destroyed civilization seeking justice.
351	Plasmawing	David Jones	20	Villain	1976-07-10	A mercenary with a strict personal code of honor.
352	Ultrastorm	\N	17	Hero	1998-09-18	A vigilante who operates outside the law to protect the innocent.
353	Omegastorm	John Anderson	16	Hero	1954-11-27	A cosmic entity whose motives remain ambiguous to all.
354	Acidclaw	Nancy Wilson	16	Antihero	1956-06-08	A vigilante who operates outside the law to protect the innocent.
355	Quantumstar	\N	17	Neutral	1970-02-10	A mercenary with a strict personal code of honor.
356	Neonforce	\N	11	Villain	1948-05-25	A former soldier seeking redemption through heroic deeds.
357	Voidhawk	William Garcia	4	Villain	1978-12-16	Once a villain, now fighting for the side of good.
358	Quantumman	\N	5	Villain	1981-10-16	A former soldier seeking redemption through heroic deeds.
359	Steelarrow	\N	16	Antihero	1944-09-19	Raised in secret, now unleashed upon a world unprepared.
360	Hyperarrow	Richard Jackson	8	Hero	1977-11-07	Driven by tragedy, defined by an unbreakable will.
361	Titanclaw	Karen Smith	4	Villain	1941-03-20	Master of the arcane arts, wielder of forbidden knowledge.
362	Quantumshield	\N	18	Hero	1998-03-29	Raised in secret, now unleashed upon a world unprepared.
363	Omegaforce	Maria Garcia	16	Hero	2002-04-24	A mercenary with a strict personal code of honor.
364	Voltstar	Sarah White	2	Neutral	2013-02-18	Driven by tragedy, defined by an unbreakable will.
365	Frostwave	William Thompson	13	Villain	1992-08-20	Gifted with powers beyond comprehension, burdened by their weight.
366	Voltfist	Lisa Thompson	10	Antihero	1987-02-23	The last survivor of a destroyed civilization seeking justice.
367	Shadowlance	Joseph Brown	20	Antihero	2004-05-05	Master of the arcane arts, wielder of forbidden knowledge.
368	Shadowshield	David Garcia	6	Antihero	1948-09-15	A mercenary with a strict personal code of honor.
369	Frosthawk	Robert Anderson	11	Hero	1957-08-07	Driven by tragedy, defined by an unbreakable will.
370	Neohunter	Barbara Smith	17	Antihero	1971-08-22	Master of the arcane arts, wielder of forbidden knowledge.
371	Volthunter	James Jackson	4	Villain	1995-07-19	Driven by tragedy, defined by an unbreakable will.
372	Solararrow	Barbara Lewis	3	Hero	2021-02-19	Raised in secret, now unleashed upon a world unprepared.
373	Blazewave	\N	7	Hero	1998-03-13	Driven by tragedy, defined by an unbreakable will.
374	Ironfire	Lisa Williams	7	Hero	1978-06-06	The last survivor of a destroyed civilization seeking justice.
375	Omegaman	\N	19	Villain	1990-12-08	Gifted with powers beyond comprehension, burdened by their weight.
376	Titanfire	Susan Davis	2	Villain	1984-06-18	The last survivor of a destroyed civilization seeking justice.
377	Steelfire	Michael Miller	5	Hero	1970-07-01	Driven by tragedy, defined by an unbreakable will.
378	Steelfist	Maria Robinson	5	Hero	1961-03-03	A cosmic entity whose motives remain ambiguous to all.
379	Plasmahawk	Richard Jones	4	Hero	1984-11-23	Master of the arcane arts, wielder of forbidden knowledge.
380	Acidveil	Nancy White	19	Hero	1962-09-21	A mercenary with a strict personal code of honor.
381	Voidshield	Richard Jones	4	Antihero	1978-01-25	A cosmic entity whose motives remain ambiguous to all.
382	Steelhunter	\N	1	Antihero	2011-11-10	A cosmic entity whose motives remain ambiguous to all.
383	Hyperwave	Patricia Lewis	6	Villain	1970-04-10	Gifted with powers beyond comprehension, burdened by their weight.
384	Alphaveil	Michael Davis	20	Neutral	1978-10-19	A mercenary with a strict personal code of honor.
385	Quantumstrike	Michael Davis	9	Villain	1993-01-01	The last survivor of a destroyed civilization seeking justice.
386	Frostblade	Maria Miller	9	Villain	1994-07-05	A former soldier seeking redemption through heroic deeds.
387	Megawing	William Anderson	10	Antihero	1992-04-24	A mercenary with a strict personal code of honor.
388	Alphaclaw	Nancy Garcia	19	Villain	1994-08-13	Driven by tragedy, defined by an unbreakable will.
389	Alphafire	\N	15	Hero	1974-12-25	Once a villain, now fighting for the side of good.
390	Blazemind	Linda Wilson	19	Hero	2008-10-18	Gifted with powers beyond comprehension, burdened by their weight.
391	Voidwoman	Joseph Young	10	Villain	1981-12-20	Gifted with powers beyond comprehension, burdened by their weight.
392	Voidarrow	David Taylor	3	Neutral	1984-08-09	A former soldier seeking redemption through heroic deeds.
393	Plasmaforce	Jessica Brown	6	Antihero	1987-05-05	A mercenary with a strict personal code of honor.
394	Shadowhawk	Karen Garcia	16	Antihero	1999-11-13	Driven by tragedy, defined by an unbreakable will.
395	Shadowwave	Joseph Smith	3	Hero	1962-05-05	The last survivor of a destroyed civilization seeking justice.
396	Acidman	\N	14	Hero	1998-03-25	Gifted with powers beyond comprehension, burdened by their weight.
397	Shadowwoman	Maria Thomas	2	Hero	1940-11-28	Driven by tragedy, defined by an unbreakable will.
398	Hyperstar	\N	15	Villain	2009-09-07	Raised in secret, now unleashed upon a world unprepared.
399	Omegawoman	Nancy Thomas	14	Villain	1996-07-01	Once a villain, now fighting for the side of good.
400	Neonblade	Linda Robinson	3	Antihero	1947-07-17	A former soldier seeking redemption through heroic deeds.
401	Hyperbolt	Thomas Johnson	14	Villain	1980-12-30	A former soldier seeking redemption through heroic deeds.
402	Ironclaw	\N	20	Villain	1968-09-08	A cosmic entity whose motives remain ambiguous to all.
403	Neonhawk	\N	14	Antihero	1998-04-05	A former soldier seeking redemption through heroic deeds.
404	Omegamind	Maria Young	3	Neutral	1984-01-23	A former soldier seeking redemption through heroic deeds.
405	Solarblade	Jessica Brown	4	Hero	1963-12-25	A vigilante who operates outside the law to protect the innocent.
406	Voltmind	\N	20	Hero	1996-05-25	A vigilante who operates outside the law to protect the innocent.
407	Titanclaw	Maria Williams	10	Villain	2020-06-09	Raised in secret, now unleashed upon a world unprepared.
408	Neoclaw	Robert Garcia	7	Hero	1954-05-24	Gifted with powers beyond comprehension, burdened by their weight.
409	Solarveil	Thomas Lewis	6	Villain	1951-10-09	The last survivor of a destroyed civilization seeking justice.
410	Alphahunter	Michael Miller	6	Hero	1989-04-22	Gifted with powers beyond comprehension, burdened by their weight.
411	Titanveil	\N	2	Hero	1951-08-06	Raised in secret, now unleashed upon a world unprepared.
412	Solarbolt	\N	20	Villain	1952-03-18	Master of the arcane arts, wielder of forbidden knowledge.
413	Alphastrike	Michael Thomas	15	Hero	1969-08-20	Once a villain, now fighting for the side of good.
414	Titanfire	Nancy Anderson	1	Hero	2022-05-22	Once a villain, now fighting for the side of good.
415	Ironwave	Barbara Anderson	11	Hero	1974-08-25	A mercenary with a strict personal code of honor.
416	Plasmafire	Karen Wilson	14	Hero	1968-04-24	A cosmic entity whose motives remain ambiguous to all.
417	Voidforce	Karen Jackson	10	Hero	2021-05-06	Gifted with powers beyond comprehension, burdened by their weight.
418	Steelveil	David Thomas	1	Antihero	2017-04-06	A mercenary with a strict personal code of honor.
419	Ultrafist	\N	3	Antihero	2000-09-25	The last survivor of a destroyed civilization seeking justice.
420	Megastrike	Barbara Miller	20	Villain	1943-12-30	A vigilante who operates outside the law to protect the innocent.
421	Solarblade	\N	5	Villain	1989-06-30	A cosmic entity whose motives remain ambiguous to all.
422	Ironstar	David Thomas	20	Neutral	1990-05-06	Raised in secret, now unleashed upon a world unprepared.
423	Shadowwave	Barbara Johnson	7	Villain	1983-03-25	Once a villain, now fighting for the side of good.
424	Voidclaw	\N	14	Neutral	1997-05-09	A mercenary with a strict personal code of honor.
425	Alphaveil	Patricia Garcia	13	Hero	1993-04-16	A vigilante who operates outside the law to protect the innocent.
426	Voidblade	\N	18	Hero	2008-04-15	Gifted with powers beyond comprehension, burdened by their weight.
427	Ironbolt	Nancy Anderson	4	Villain	1940-11-30	The last survivor of a destroyed civilization seeking justice.
428	Titanhunter	Susan Johnson	18	Hero	2013-08-15	A mercenary with a strict personal code of honor.
429	Ironwoman	Lisa Williams	4	Antihero	1995-05-10	Driven by tragedy, defined by an unbreakable will.
430	Neonstrike	Linda Robinson	11	Hero	2015-07-11	A mercenary with a strict personal code of honor.
431	Alphastorm	Jessica Thomas	11	Antihero	2013-07-02	Driven by tragedy, defined by an unbreakable will.
432	Ultrablade	Joseph Brown	5	Hero	1976-01-11	The last survivor of a destroyed civilization seeking justice.
433	Steelbolt	Nancy Young	8	Hero	1971-11-10	The last survivor of a destroyed civilization seeking justice.
434	Neonlance	Karen Lewis	3	Villain	2018-11-06	A mercenary with a strict personal code of honor.
435	Shadowfist	Karen Garcia	17	Hero	1988-03-28	Driven by tragedy, defined by an unbreakable will.
436	Thunderclaw	Charles Young	18	Villain	2014-11-27	Driven by tragedy, defined by an unbreakable will.
437	Neonwoman	\N	9	Villain	1990-05-08	Gifted with powers beyond comprehension, burdened by their weight.
438	Neonveil	Barbara Martin	1	Antihero	1938-02-09	A cosmic entity whose motives remain ambiguous to all.
439	Ironstorm	Charles Anderson	13	Hero	1985-11-20	Once a villain, now fighting for the side of good.
440	Ultrahunter	\N	16	Villain	1946-07-10	A vigilante who operates outside the law to protect the innocent.
441	Omegastar	David Miller	8	Antihero	1984-10-03	Driven by tragedy, defined by an unbreakable will.
442	Alphaclaw	Karen Brown	15	Hero	1955-08-20	A vigilante who operates outside the law to protect the innocent.
443	Ultraveil	\N	3	Hero	2005-07-21	A cosmic entity whose motives remain ambiguous to all.
444	Solarwave	\N	2	Antihero	1961-03-07	A former soldier seeking redemption through heroic deeds.
445	Alphaforce	Michael Young	13	Villain	1958-11-16	A vigilante who operates outside the law to protect the innocent.
446	Plasmahunter	Linda Garcia	6	Antihero	1938-10-10	A former soldier seeking redemption through heroic deeds.
447	Plasmalance	\N	16	Hero	1951-10-23	A mercenary with a strict personal code of honor.
448	Alphawave	Charles Young	2	Villain	2014-11-30	The last survivor of a destroyed civilization seeking justice.
449	Ultralance	Nancy Lewis	13	Hero	1969-06-08	Master of the arcane arts, wielder of forbidden knowledge.
450	Alphashield	Thomas Johnson	13	Villain	2003-08-10	Gifted with powers beyond comprehension, burdened by their weight.
451	Frostblade	John Smith	16	Hero	1974-01-17	A mercenary with a strict personal code of honor.
452	Plasmastorm	Joseph Martin	14	Villain	1984-02-06	Gifted with powers beyond comprehension, burdened by their weight.
453	Voidlance	\N	10	Hero	1988-07-16	Master of the arcane arts, wielder of forbidden knowledge.
454	Frosthawk	Richard Anderson	14	Villain	1958-12-14	Raised in secret, now unleashed upon a world unprepared.
455	Ironveil	Richard Young	11	Antihero	1950-10-30	A vigilante who operates outside the law to protect the innocent.
456	Quantumforce	Barbara Jones	13	Villain	1970-09-14	Gifted with powers beyond comprehension, burdened by their weight.
457	Steelhunter	Jessica Jones	9	Antihero	1989-07-07	Raised in secret, now unleashed upon a world unprepared.
458	Voidstorm	Linda Smith	5	Antihero	1971-11-06	Master of the arcane arts, wielder of forbidden knowledge.
459	Hyperfire	Linda Lewis	12	Antihero	1971-05-03	Master of the arcane arts, wielder of forbidden knowledge.
460	Hyperfist	\N	9	Neutral	2009-05-11	Master of the arcane arts, wielder of forbidden knowledge.
461	Neoveil	Nancy Robinson	3	Villain	2002-04-12	A vigilante who operates outside the law to protect the innocent.
462	Quantumhunter	Lisa White	8	Neutral	1938-09-18	A vigilante who operates outside the law to protect the innocent.
463	Blazemind	Patricia Anderson	16	Antihero	2003-03-29	Driven by tragedy, defined by an unbreakable will.
464	Neoblade	Karen Robinson	16	Hero	2017-01-18	Raised in secret, now unleashed upon a world unprepared.
465	Voltfire	\N	14	Antihero	1979-05-14	Raised in secret, now unleashed upon a world unprepared.
466	Ultrabolt	\N	16	Hero	1938-02-28	Master of the arcane arts, wielder of forbidden knowledge.
467	Quantumshield	Richard Taylor	3	Hero	1972-07-26	A vigilante who operates outside the law to protect the innocent.
468	Titanarrow	Lisa Johnson	6	Neutral	1989-10-11	A former soldier seeking redemption through heroic deeds.
469	Neoblade	Charles Lewis	16	Villain	2015-03-08	Driven by tragedy, defined by an unbreakable will.
470	Voltstrike	Nancy Young	9	Hero	1938-04-29	Driven by tragedy, defined by an unbreakable will.
471	Neonbolt	Jessica Thomas	14	Hero	2017-08-02	A former soldier seeking redemption through heroic deeds.
472	Alphafist	Maria Miller	12	Villain	1959-09-16	A cosmic entity whose motives remain ambiguous to all.
473	Blazeman	\N	3	Villain	1975-02-10	A cosmic entity whose motives remain ambiguous to all.
474	Solarhunter	Thomas Davis	15	Hero	2008-07-24	Gifted with powers beyond comprehension, burdened by their weight.
475	Alphamind	David Robinson	2	Hero	2012-05-01	Once a villain, now fighting for the side of good.
476	Blazestrike	Robert Harris	16	Villain	1986-10-21	A cosmic entity whose motives remain ambiguous to all.
477	Megahawk	Sarah Anderson	10	Villain	1938-01-08	Once a villain, now fighting for the side of good.
478	Blazehawk	Thomas Anderson	20	Villain	1961-12-14	Once a villain, now fighting for the side of good.
479	Voidfist	Nancy Davis	10	Villain	1946-04-26	A cosmic entity whose motives remain ambiguous to all.
480	Hyperwave	Barbara Jackson	12	Antihero	1958-02-13	A mercenary with a strict personal code of honor.
481	Voidstrike	\N	2	Antihero	1944-01-20	A vigilante who operates outside the law to protect the innocent.
482	Plasmawave	Richard Miller	12	Villain	1983-04-08	A mercenary with a strict personal code of honor.
483	Blazewing	Maria Taylor	10	Hero	2005-09-16	A vigilante who operates outside the law to protect the innocent.
484	Ultrafist	Karen Harris	6	Hero	1955-05-19	Once a villain, now fighting for the side of good.
485	Shadowfire	Charles Thompson	6	Hero	1988-07-11	A vigilante who operates outside the law to protect the innocent.
486	Shadowstar	Charles Williams	5	Villain	1992-02-28	A vigilante who operates outside the law to protect the innocent.
487	Plasmalance	Linda Martin	2	Hero	1948-12-18	Master of the arcane arts, wielder of forbidden knowledge.
488	Blazeshield	\N	13	Villain	1943-01-27	A former soldier seeking redemption through heroic deeds.
489	Blazearrow	Maria Harris	1	Hero	1961-07-11	A former soldier seeking redemption through heroic deeds.
490	Omegawave	\N	7	Hero	1976-02-12	Gifted with powers beyond comprehension, burdened by their weight.
491	Ultrawoman	Charles Johnson	2	Villain	1984-07-26	Master of the arcane arts, wielder of forbidden knowledge.
492	Neonstar	Richard Johnson	17	Antihero	2022-08-13	Master of the arcane arts, wielder of forbidden knowledge.
493	Quantumarrow	Lisa Davis	1	Hero	1993-12-29	The last survivor of a destroyed civilization seeking justice.
494	Ultraclaw	Susan Thomas	16	Hero	2023-11-08	A cosmic entity whose motives remain ambiguous to all.
495	Ironstorm	Patricia Lewis	5	Hero	1949-07-01	The last survivor of a destroyed civilization seeking justice.
496	Blazemind	\N	18	Hero	1970-04-09	Raised in secret, now unleashed upon a world unprepared.
497	Shadowveil	Joseph Garcia	9	Antihero	1966-04-29	Master of the arcane arts, wielder of forbidden knowledge.
498	Neonblade	Michael Wilson	1	Antihero	1977-01-20	A former soldier seeking redemption through heroic deeds.
499	Shadowstorm	Jessica Garcia	6	Antihero	1972-05-19	A vigilante who operates outside the law to protect the innocent.
500	Ironblade	Charles Anderson	20	Hero	1987-09-27	A cosmic entity whose motives remain ambiguous to all.
501	Hyperforce	Nancy Johnson	13	Villain	1939-09-19	Driven by tragedy, defined by an unbreakable will.
502	Acidveil	\N	6	Antihero	1963-01-02	Driven by tragedy, defined by an unbreakable will.
503	Voidfire	Charles Martin	5	Villain	1958-03-30	Driven by tragedy, defined by an unbreakable will.
504	Alphaclaw	Charles Martin	14	Antihero	1959-07-09	A vigilante who operates outside the law to protect the innocent.
505	Alphaveil	Joseph Miller	2	Villain	2023-12-22	Gifted with powers beyond comprehension, burdened by their weight.
506	Ultraclaw	Lisa Miller	4	Hero	1996-05-28	Once a villain, now fighting for the side of good.
507	Ultrafist	\N	13	Hero	1961-07-15	Driven by tragedy, defined by an unbreakable will.
508	Alphaveil	Charles Thomas	8	Hero	1941-10-25	A vigilante who operates outside the law to protect the innocent.
509	Neoveil	\N	17	Hero	1969-04-20	A cosmic entity whose motives remain ambiguous to all.
510	Neowing	Nancy Miller	14	Hero	1987-03-18	Raised in secret, now unleashed upon a world unprepared.
511	Blazestorm	Lisa Taylor	20	Hero	1963-04-02	Once a villain, now fighting for the side of good.
512	Voltlance	Linda Thompson	1	Villain	1988-10-07	The last survivor of a destroyed civilization seeking justice.
513	Quantumhunter	Patricia Jones	8	Hero	1965-07-16	Raised in secret, now unleashed upon a world unprepared.
514	Voltfist	\N	8	Hero	1996-09-29	Gifted with powers beyond comprehension, burdened by their weight.
515	Omegawoman	\N	6	Hero	1966-08-23	Raised in secret, now unleashed upon a world unprepared.
516	Solarstar	\N	18	Antihero	2003-04-05	Gifted with powers beyond comprehension, burdened by their weight.
517	Voltarrow	Karen Smith	17	Villain	1950-02-02	Once a villain, now fighting for the side of good.
518	Quantumarrow	Maria Jones	20	Antihero	2009-03-15	The last survivor of a destroyed civilization seeking justice.
519	Quantumman	James White	15	Villain	1976-05-07	Driven by tragedy, defined by an unbreakable will.
520	Thunderforce	Michael Wilson	4	Neutral	1997-06-30	Driven by tragedy, defined by an unbreakable will.
521	Neonforce	Joseph Davis	8	Villain	1995-06-05	A former soldier seeking redemption through heroic deeds.
522	Shadowbolt	Richard Brown	12	Antihero	1989-09-14	A cosmic entity whose motives remain ambiguous to all.
523	Quantumclaw	Lisa White	15	Neutral	2014-08-15	A vigilante who operates outside the law to protect the innocent.
524	Thunderman	Lisa Smith	7	Villain	1970-10-07	Raised in secret, now unleashed upon a world unprepared.
525	Plasmahunter	James Jackson	3	Neutral	1976-01-07	Driven by tragedy, defined by an unbreakable will.
526	Alphawing	\N	8	Hero	1945-11-10	Master of the arcane arts, wielder of forbidden knowledge.
527	Megaveil	John Harris	11	Hero	1977-05-24	A former soldier seeking redemption through heroic deeds.
528	Solararrow	Richard Jones	7	Hero	1959-11-01	Driven by tragedy, defined by an unbreakable will.
529	Frostveil	Susan Smith	17	Neutral	2001-11-11	A cosmic entity whose motives remain ambiguous to all.
530	Thunderstar	Jessica Young	15	Hero	1950-11-15	Driven by tragedy, defined by an unbreakable will.
531	Blazefist	Nancy Martin	16	Hero	1969-06-01	A former soldier seeking redemption through heroic deeds.
532	Shadowshield	Robert Garcia	17	Villain	1994-10-18	A cosmic entity whose motives remain ambiguous to all.
533	Solarblade	Susan Lewis	19	Villain	1951-01-06	A mercenary with a strict personal code of honor.
534	Thunderarrow	Michael Garcia	7	Hero	1988-11-25	Once a villain, now fighting for the side of good.
535	Plasmaman	Patricia Taylor	16	Antihero	2011-05-26	A former soldier seeking redemption through heroic deeds.
536	Ultraveil	James Wilson	19	Villain	1964-06-04	A former soldier seeking redemption through heroic deeds.
537	Omegawave	John Davis	15	Antihero	1981-03-17	The last survivor of a destroyed civilization seeking justice.
538	Thunderwave	\N	14	Villain	1950-06-08	Once a villain, now fighting for the side of good.
539	Thundermind	\N	20	Villain	1993-02-05	A vigilante who operates outside the law to protect the innocent.
540	Frostmind	David Lewis	3	Villain	1948-08-27	Raised in secret, now unleashed upon a world unprepared.
541	Alphafist	Nancy Johnson	17	Hero	2003-01-02	Raised in secret, now unleashed upon a world unprepared.
542	Titanarrow	Jessica Jones	8	Neutral	1953-07-03	The last survivor of a destroyed civilization seeking justice.
543	Acidfire	\N	6	Antihero	2007-03-10	Once a villain, now fighting for the side of good.
544	Neostrike	Thomas Thompson	15	Villain	1989-09-16	The last survivor of a destroyed civilization seeking justice.
545	Thunderfire	Karen Robinson	2	Hero	1985-12-03	Driven by tragedy, defined by an unbreakable will.
546	Neowave	William White	5	Antihero	2007-05-01	Master of the arcane arts, wielder of forbidden knowledge.
547	Acidmind	Michael Martin	20	Villain	2000-08-10	A former soldier seeking redemption through heroic deeds.
548	Ironwing	\N	6	Hero	1972-07-29	A vigilante who operates outside the law to protect the innocent.
549	Hyperwoman	William White	8	Villain	1974-02-23	A mercenary with a strict personal code of honor.
550	Hyperfire	David Lewis	19	Villain	1949-04-18	A mercenary with a strict personal code of honor.
551	Solarbolt	\N	17	Neutral	2016-06-22	Master of the arcane arts, wielder of forbidden knowledge.
552	Shadowfist	Maria White	5	Antihero	2002-10-19	Once a villain, now fighting for the side of good.
553	Thunderveil	Michael Johnson	15	Hero	2010-11-23	The last survivor of a destroyed civilization seeking justice.
554	Alphaarrow	Michael Garcia	7	Villain	1998-02-21	The last survivor of a destroyed civilization seeking justice.
555	Voltclaw	Lisa Taylor	17	Hero	1965-12-16	A vigilante who operates outside the law to protect the innocent.
556	Ultrahawk	Nancy Miller	19	Antihero	1960-12-04	The last survivor of a destroyed civilization seeking justice.
557	Blazeveil	Charles Young	17	Villain	1954-02-10	Master of the arcane arts, wielder of forbidden knowledge.
558	Omegastorm	Robert Wilson	13	Antihero	2012-04-29	Once a villain, now fighting for the side of good.
559	Neoveil	Nancy Harris	1	Villain	1975-05-08	A mercenary with a strict personal code of honor.
560	Megahunter	Barbara Brown	18	Villain	2008-02-22	The last survivor of a destroyed civilization seeking justice.
561	Ultrawing	Robert Williams	10	Hero	1941-02-13	Driven by tragedy, defined by an unbreakable will.
562	Quantumstrike	Joseph Thomas	4	Villain	1998-06-08	A vigilante who operates outside the law to protect the innocent.
563	Alphamind	William Garcia	6	Villain	1995-04-21	Raised in secret, now unleashed upon a world unprepared.
564	Ironforce	\N	19	Hero	1940-09-13	Raised in secret, now unleashed upon a world unprepared.
565	Steelfist	Sarah Williams	4	Villain	1940-09-08	Driven by tragedy, defined by an unbreakable will.
566	Alphamind	Richard Wilson	7	Hero	1971-01-02	Driven by tragedy, defined by an unbreakable will.
567	Ultrafist	David White	13	Antihero	1984-08-22	Once a villain, now fighting for the side of good.
568	Neonarrow	James Robinson	20	Neutral	1968-07-09	Raised in secret, now unleashed upon a world unprepared.
569	Frostclaw	\N	14	Antihero	2023-11-05	A vigilante who operates outside the law to protect the innocent.
570	Neoarrow	Jessica Jones	8	Villain	1979-11-08	Master of the arcane arts, wielder of forbidden knowledge.
571	Steelman	Richard Garcia	1	Villain	1976-05-31	Raised in secret, now unleashed upon a world unprepared.
572	Shadowbolt	Joseph Davis	2	Villain	1939-05-03	The last survivor of a destroyed civilization seeking justice.
573	Hyperhunter	\N	6	Hero	1960-01-01	Driven by tragedy, defined by an unbreakable will.
574	Megafire	James Jackson	11	Antihero	1956-01-31	A cosmic entity whose motives remain ambiguous to all.
575	Shadowhawk	Susan Taylor	9	Antihero	1942-10-31	A mercenary with a strict personal code of honor.
576	Voidstar	Joseph Taylor	19	Antihero	1961-07-29	Master of the arcane arts, wielder of forbidden knowledge.
577	Voltfist	Karen Young	6	Hero	1990-07-26	A cosmic entity whose motives remain ambiguous to all.
578	Neoforce	Karen Lewis	11	Villain	1963-09-28	A vigilante who operates outside the law to protect the innocent.
579	Thunderbolt	\N	2	Hero	1985-11-26	Gifted with powers beyond comprehension, burdened by their weight.
580	Acidveil	Charles Taylor	14	Neutral	2000-05-21	Driven by tragedy, defined by an unbreakable will.
581	Omegaman	\N	2	Hero	2013-08-22	A mercenary with a strict personal code of honor.
582	Solarmind	\N	11	Hero	1959-11-16	A vigilante who operates outside the law to protect the innocent.
583	Acidlance	Susan Garcia	7	Hero	1965-03-16	A cosmic entity whose motives remain ambiguous to all.
584	Blazehunter	James Anderson	15	Villain	2021-02-17	A vigilante who operates outside the law to protect the innocent.
585	Solarstar	Patricia Miller	11	Hero	2000-09-25	Once a villain, now fighting for the side of good.
586	Hyperwave	\N	18	Antihero	1953-03-20	A mercenary with a strict personal code of honor.
587	Acidhawk	\N	20	Hero	2010-10-11	Once a villain, now fighting for the side of good.
588	Solarhunter	Barbara Harris	4	Villain	1954-10-28	Master of the arcane arts, wielder of forbidden knowledge.
589	Hyperman	William Thompson	15	Antihero	1981-06-30	A vigilante who operates outside the law to protect the innocent.
590	Voltfist	\N	8	Hero	1968-11-21	A former soldier seeking redemption through heroic deeds.
591	Neonman	James Anderson	16	Villain	2013-09-03	A former soldier seeking redemption through heroic deeds.
592	Alphaarrow	Robert Martin	7	Hero	2018-08-12	A vigilante who operates outside the law to protect the innocent.
593	Blazewave	Joseph Martin	12	Neutral	1999-01-28	A former soldier seeking redemption through heroic deeds.
594	Voidlance	Nancy Thompson	18	Villain	2008-07-18	Once a villain, now fighting for the side of good.
595	Quantumstorm	John Martin	9	Hero	1957-05-23	Gifted with powers beyond comprehension, burdened by their weight.
596	Steelstrike	\N	4	Antihero	2006-06-09	Gifted with powers beyond comprehension, burdened by their weight.
597	Blazewave	\N	15	Antihero	1977-12-28	A former soldier seeking redemption through heroic deeds.
598	Frostarrow	Richard Thompson	12	Antihero	1947-11-19	A cosmic entity whose motives remain ambiguous to all.
599	Ultrashield	\N	4	Villain	1999-08-29	A vigilante who operates outside the law to protect the innocent.
600	Hyperwave	Susan Jackson	20	Antihero	1938-06-14	Gifted with powers beyond comprehension, burdened by their weight.
\.


--
-- TOC entry 5106 (class 0 OID 32868)
-- Dependencies: 224
-- Data for Name: creator; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.creator (creator_id, first_name, last_name, birth_year, nationality, bio) FROM stdin;
1	Christine	Harris	1923	French	Pioneering colorist who revolutionized digital coloring techniques.
2	Donald	Young	1933	German	Renowned penciler celebrated for dynamic action sequences.
3	Helen	Murphy	1924	American	Renowned penciler celebrated for dynamic action sequences.
4	Ashley	Nguyen	1984	Brazilian	Award-winning writer known for complex character arcs.
5	Emma	King	1989	Spanish	Pioneering colorist who revolutionized digital coloring techniques.
6	Kathleen	James	1955	American	Veteran inker whose work defined an entire era of comics.
7	Janet	Murphy	1963	French	Veteran inker whose work defined an entire era of comics.
8	Ashley	Evans	1933	British	Legendary artist whose style influenced an entire generation.
9	Richard	Diaz	1964	Brazilian	Prolific creator with credits spanning five decades of comics.
10	Linda	Ortiz	1988	British	Legendary artist whose style influenced an entire generation.
11	William	Richardson	1957	Brazilian	Independent creator known for groundbreaking creator-owned titles.
12	Nicole	Young	1928	American	Pioneering colorist who revolutionized digital coloring techniques.
13	Roger	Campbell	1930	Australian	Renowned penciler celebrated for dynamic action sequences.
14	Matthew	Baker	1978	Japanese	Veteran inker whose work defined an entire era of comics.
15	Stephanie	Diaz	1946	French	Renowned penciler celebrated for dynamic action sequences.
16	Samantha	Price	1941	German	Pioneering colorist who revolutionized digital coloring techniques.
17	Christopher	Morgan	1968	French	Artist famed for intricate page layouts and expressive faces.
18	Donald	Long	1961	American	Pioneering colorist who revolutionized digital coloring techniques.
19	John	Roberts	1971	French	Renowned penciler celebrated for dynamic action sequences.
20	Ashley	Brooks	1960	Australian	Writer known for socially conscious storytelling and diverse casts.
21	Gary	Alvarez	1978	Canadian	Prolific creator with credits spanning five decades of comics.
22	Nancy	Flores	1991	German	Prolific creator with credits spanning five decades of comics.
23	Diane	Wood	1974	Brazilian	Legendary artist whose style influenced an entire generation.
24	Jason	Torres	1937	German	Writer known for socially conscious storytelling and diverse casts.
25	Susan	Miller	1934	Canadian	Veteran inker whose work defined an entire era of comics.
26	Carolyn	Murphy	1928	Spanish	Legendary artist whose style influenced an entire generation.
27	Jerry	Morgan	1987	French	Artist famed for intricate page layouts and expressive faces.
28	Maria	Long	1934	German	Prolific creator with credits spanning five decades of comics.
29	Roger	Alvarez	1963	British	Prolific creator with credits spanning five decades of comics.
30	Cynthia	Lee	1978	American	Prolific creator with credits spanning five decades of comics.
31	Eric	Hall	1984	British	Prolific creator with credits spanning five decades of comics.
32	Christine	Kelly	1945	Canadian	Independent creator known for groundbreaking creator-owned titles.
33	Julie	Lee	1989	German	Award-winning writer known for complex character arcs.
34	Jerry	Gomez	1982	American	Renowned penciler celebrated for dynamic action sequences.
35	Jason	Carter	1950	American	Pioneering colorist who revolutionized digital coloring techniques.
36	Gregory	Anderson	1930	Italian	Renowned penciler celebrated for dynamic action sequences.
37	Julie	Cox	1936	Canadian	Writer known for socially conscious storytelling and diverse casts.
38	Raymond	Walker	1953	German	Two-time Eisner Award winner for outstanding comics writing.
39	Jose	Scott	1989	Australian	Prolific creator with credits spanning five decades of comics.
40	Sharon	Patel	1967	Italian	Artist famed for intricate page layouts and expressive faces.
41	Kathleen	Martin	1951	Australian	Renowned penciler celebrated for dynamic action sequences.
42	Melissa	Williams	1995	German	Pioneering colorist who revolutionized digital coloring techniques.
43	Helen	Torres	1920	British	Award-winning writer known for complex character arcs.
44	Dorothy	Wilson	1924	Japanese	Renowned penciler celebrated for dynamic action sequences.
45	Anna	Hill	1955	Italian	Pioneering colorist who revolutionized digital coloring techniques.
46	Pamela	Thompson	1993	Brazilian	Writer known for socially conscious storytelling and diverse casts.
47	Kimberly	Cooper	1972	Australian	Renowned penciler celebrated for dynamic action sequences.
48	Richard	Sanders	1975	Japanese	Legendary artist whose style influenced an entire generation.
49	Timothy	Morgan	1926	British	Award-winning writer known for complex character arcs.
50	Sharon	Evans	1933	Australian	Pioneering colorist who revolutionized digital coloring techniques.
51	Paul	Cox	1977	Canadian	Legendary artist whose style influenced an entire generation.
52	Dorothy	Baker	1979	Australian	Renowned penciler celebrated for dynamic action sequences.
53	Larry	Richardson	1932	American	Artist famed for intricate page layouts and expressive faces.
54	Maria	Thomas	1950	Canadian	Legendary artist whose style influenced an entire generation.
55	Scott	Peterson	1947	Spanish	Award-winning writer known for complex character arcs.
56	Betty	Edwards	1920	Spanish	Prolific creator with credits spanning five decades of comics.
57	Jeffrey	Rivera	1974	German	Writer known for socially conscious storytelling and diverse casts.
58	Lisa	Young	1957	Australian	Award-winning writer known for complex character arcs.
59	Joshua	Ward	1927	Japanese	Award-winning writer known for complex character arcs.
60	Robert	Wood	1981	German	Artist famed for intricate page layouts and expressive faces.
61	Christopher	Davis	1985	British	Veteran inker whose work defined an entire era of comics.
62	Michael	Bennett	1928	Australian	Legendary artist whose style influenced an entire generation.
63	Karen	Brooks	1951	Brazilian	Two-time Eisner Award winner for outstanding comics writing.
64	Linda	Ruiz	1930	Spanish	Two-time Eisner Award winner for outstanding comics writing.
65	Gregory	Ramos	1960	French	Pioneering colorist who revolutionized digital coloring techniques.
66	Rachel	Roberts	1950	French	Legendary artist whose style influenced an entire generation.
67	Thomas	Patel	1958	Italian	Independent creator known for groundbreaking creator-owned titles.
68	Ryan	Taylor	1921	Italian	Two-time Eisner Award winner for outstanding comics writing.
69	Gregory	Jackson	1929	German	Pioneering colorist who revolutionized digital coloring techniques.
70	Eric	Adams	1936	Japanese	Renowned penciler celebrated for dynamic action sequences.
71	Kimberly	Cruz	1956	Canadian	Writer known for socially conscious storytelling and diverse casts.
72	Pamela	Mitchell	1987	American	Artist famed for intricate page layouts and expressive faces.
73	Brian	Sanders	1933	Canadian	Prolific creator with credits spanning five decades of comics.
74	Joseph	White	1990	Canadian	Prolific creator with credits spanning five decades of comics.
75	Edward	Gray	1946	Japanese	Pioneering colorist who revolutionized digital coloring techniques.
76	Carolyn	Price	1953	German	Writer known for socially conscious storytelling and diverse casts.
77	Kenneth	Miller	1931	Spanish	Prolific creator with credits spanning five decades of comics.
78	Linda	Smith	1962	Canadian	Prolific creator with credits spanning five decades of comics.
79	Christopher	Rogers	1990	Spanish	Artist famed for intricate page layouts and expressive faces.
80	Maria	Harris	1929	Canadian	Artist famed for intricate page layouts and expressive faces.
81	John	Cruz	1994	German	Veteran inker whose work defined an entire era of comics.
82	Cynthia	Thompson	1925	French	Independent creator known for groundbreaking creator-owned titles.
83	Linda	Diaz	1946	Australian	Renowned penciler celebrated for dynamic action sequences.
84	Deborah	Watson	1972	Brazilian	Veteran inker whose work defined an entire era of comics.
85	George	Lee	1942	Spanish	Award-winning writer known for complex character arcs.
86	Daniel	Phillips	1972	Australian	Prolific creator with credits spanning five decades of comics.
87	Christopher	Foster	1933	Spanish	Award-winning writer known for complex character arcs.
88	Frank	Torres	1945	Italian	Independent creator known for groundbreaking creator-owned titles.
89	Carol	Nguyen	1948	American	Pioneering colorist who revolutionized digital coloring techniques.
90	Sharon	Phillips	1955	British	Prolific creator with credits spanning five decades of comics.
91	Kevin	Alvarez	1985	Spanish	Artist famed for intricate page layouts and expressive faces.
92	Anthony	Brown	1934	French	Veteran inker whose work defined an entire era of comics.
93	Joshua	Adams	1924	British	Two-time Eisner Award winner for outstanding comics writing.
94	Cynthia	Turner	1960	Spanish	Two-time Eisner Award winner for outstanding comics writing.
95	Anna	Harris	1969	Brazilian	Pioneering colorist who revolutionized digital coloring techniques.
96	Kenneth	Garcia	1975	American	Artist famed for intricate page layouts and expressive faces.
97	Andrew	Long	1945	Japanese	Legendary artist whose style influenced an entire generation.
98	Michael	Patel	1962	Brazilian	Independent creator known for groundbreaking creator-owned titles.
99	Peter	Martin	1958	German	Prolific creator with credits spanning five decades of comics.
100	Rachel	Morris	1961	Spanish	Prolific creator with credits spanning five decades of comics.
101	Raymond	Thompson	1944	Spanish	Legendary artist whose style influenced an entire generation.
102	Harold	Hall	1992	French	Legendary artist whose style influenced an entire generation.
103	Raymond	Smith	1958	French	Pioneering colorist who revolutionized digital coloring techniques.
104	Cynthia	Wood	1961	Italian	Writer known for socially conscious storytelling and diverse casts.
105	Larry	Myers	1947	German	Writer known for socially conscious storytelling and diverse casts.
106	Arthur	Walker	1930	French	Artist famed for intricate page layouts and expressive faces.
107	Peter	Price	1962	British	Pioneering colorist who revolutionized digital coloring techniques.
108	Harold	Carter	1948	Australian	Veteran inker whose work defined an entire era of comics.
109	Sarah	Garcia	1951	Italian	Two-time Eisner Award winner for outstanding comics writing.
110	Roger	Taylor	1978	Spanish	Two-time Eisner Award winner for outstanding comics writing.
111	Paul	Foster	1969	Italian	Legendary artist whose style influenced an entire generation.
112	Kimberly	Robinson	1920	British	Legendary artist whose style influenced an entire generation.
113	Donald	Hall	1986	Italian	Award-winning writer known for complex character arcs.
114	Emma	Flores	1935	Italian	Veteran inker whose work defined an entire era of comics.
115	Amy	Patel	1987	German	Two-time Eisner Award winner for outstanding comics writing.
116	Ronald	Rogers	1984	Spanish	Artist famed for intricate page layouts and expressive faces.
117	Kathleen	Lee	1980	Italian	Prolific creator with credits spanning five decades of comics.
118	Ryan	Flores	1955	German	Writer known for socially conscious storytelling and diverse casts.
119	Walter	Hill	1955	Italian	Renowned penciler celebrated for dynamic action sequences.
120	Maria	Rivera	1950	French	Independent creator known for groundbreaking creator-owned titles.
121	Ronald	Ward	1930	Canadian	Veteran inker whose work defined an entire era of comics.
122	Dorothy	Collins	1939	Australian	Renowned penciler celebrated for dynamic action sequences.
123	Laura	Morris	1962	German	Writer known for socially conscious storytelling and diverse casts.
124	Laura	Davis	1946	Spanish	Legendary artist whose style influenced an entire generation.
125	Roger	Wood	1922	Brazilian	Legendary artist whose style influenced an entire generation.
126	Angela	Smith	1965	French	Legendary artist whose style influenced an entire generation.
127	Laura	Cox	1989	Brazilian	Pioneering colorist who revolutionized digital coloring techniques.
128	Scott	Torres	1954	Spanish	Writer known for socially conscious storytelling and diverse casts.
129	Sarah	Collins	1963	Spanish	Veteran inker whose work defined an entire era of comics.
130	Amy	Thompson	1988	American	Legendary artist whose style influenced an entire generation.
131	Helen	Brooks	1923	British	Legendary artist whose style influenced an entire generation.
132	Nancy	Morgan	1943	American	Prolific creator with credits spanning five decades of comics.
133	Matthew	Gomez	1947	Italian	Independent creator known for groundbreaking creator-owned titles.
134	Melissa	Edwards	1955	Spanish	Prolific creator with credits spanning five decades of comics.
135	William	Cooper	1922	German	Award-winning writer known for complex character arcs.
136	Kevin	Torres	1928	American	Award-winning writer known for complex character arcs.
137	Kimberly	King	1922	Brazilian	Veteran inker whose work defined an entire era of comics.
138	George	Thompson	1980	British	Two-time Eisner Award winner for outstanding comics writing.
139	Ashley	Morgan	1952	Japanese	Veteran inker whose work defined an entire era of comics.
140	Samantha	Gray	1934	Canadian	Prolific creator with credits spanning five decades of comics.
141	Jessica	Wood	1923	French	Two-time Eisner Award winner for outstanding comics writing.
142	Harold	Edwards	1970	Australian	Renowned penciler celebrated for dynamic action sequences.
143	Helen	Ross	1951	British	Prolific creator with credits spanning five decades of comics.
144	Carolyn	Bennett	1935	Brazilian	Award-winning writer known for complex character arcs.
145	Kevin	Cox	1974	Japanese	Renowned penciler celebrated for dynamic action sequences.
146	Eric	Alvarez	1963	American	Legendary artist whose style influenced an entire generation.
147	Scott	White	1975	Japanese	Writer known for socially conscious storytelling and diverse casts.
148	Henry	Lewis	1975	Canadian	Artist famed for intricate page layouts and expressive faces.
149	Debra	Nelson	1988	Italian	Writer known for socially conscious storytelling and diverse casts.
150	Cynthia	James	1954	Japanese	Pioneering colorist who revolutionized digital coloring techniques.
151	Susan	Baker	1977	Australian	Writer known for socially conscious storytelling and diverse casts.
152	Gregory	Mendoza	1968	Japanese	Award-winning writer known for complex character arcs.
153	Shirley	Gomez	1943	Italian	Pioneering colorist who revolutionized digital coloring techniques.
154	Deborah	Adams	1963	French	Two-time Eisner Award winner for outstanding comics writing.
155	Janet	Baker	1991	American	Artist famed for intricate page layouts and expressive faces.
156	Paul	Anderson	1950	Spanish	Writer known for socially conscious storytelling and diverse casts.
157	Emma	Hill	1980	Italian	Writer known for socially conscious storytelling and diverse casts.
158	David	Thomas	1957	Australian	Legendary artist whose style influenced an entire generation.
159	Douglas	Flores	1959	Brazilian	Independent creator known for groundbreaking creator-owned titles.
160	Frank	Richardson	1987	Japanese	Legendary artist whose style influenced an entire generation.
161	Diane	Richardson	1962	Japanese	Writer known for socially conscious storytelling and diverse casts.
162	Steven	Carter	1952	Australian	Renowned penciler celebrated for dynamic action sequences.
163	Carl	Young	1960	British	Artist famed for intricate page layouts and expressive faces.
164	Julie	Ross	1943	Australian	Pioneering colorist who revolutionized digital coloring techniques.
165	Arthur	Peterson	1955	Brazilian	Artist famed for intricate page layouts and expressive faces.
166	Jerry	Rivera	1932	Australian	Prolific creator with credits spanning five decades of comics.
167	Dorothy	Parker	1942	French	Award-winning writer known for complex character arcs.
168	Henry	Cox	1936	French	Award-winning writer known for complex character arcs.
169	Robert	Richardson	1957	Canadian	Writer known for socially conscious storytelling and diverse casts.
170	Jessica	Johnson	1993	French	Writer known for socially conscious storytelling and diverse casts.
171	Angela	Rogers	1963	Canadian	Award-winning writer known for complex character arcs.
172	Kenneth	Peterson	1934	British	Legendary artist whose style influenced an entire generation.
173	Scott	Taylor	1993	American	Veteran inker whose work defined an entire era of comics.
174	Lisa	Brooks	1958	British	Pioneering colorist who revolutionized digital coloring techniques.
175	Karen	Watson	1973	Brazilian	Two-time Eisner Award winner for outstanding comics writing.
176	Katherine	Torres	1986	Spanish	Writer known for socially conscious storytelling and diverse casts.
177	Larry	Mitchell	1995	Spanish	Prolific creator with credits spanning five decades of comics.
178	Gregory	Ruiz	1927	Brazilian	Renowned penciler celebrated for dynamic action sequences.
179	Julie	Wright	1947	French	Renowned penciler celebrated for dynamic action sequences.
180	Christopher	Hill	1942	German	Renowned penciler celebrated for dynamic action sequences.
181	Christopher	Smith	1972	Italian	Two-time Eisner Award winner for outstanding comics writing.
182	Frank	Campbell	1924	Australian	Prolific creator with credits spanning five decades of comics.
183	Henry	Rivera	1978	British	Pioneering colorist who revolutionized digital coloring techniques.
184	Emily	Hughes	1995	Australian	Legendary artist whose style influenced an entire generation.
185	Joseph	Ward	1948	Canadian	Prolific creator with credits spanning five decades of comics.
186	Charles	Taylor	1927	Canadian	Prolific creator with credits spanning five decades of comics.
187	Jerry	Brooks	1956	Italian	Renowned penciler celebrated for dynamic action sequences.
188	Amy	Ross	1958	Spanish	Prolific creator with credits spanning five decades of comics.
189	Eric	Ward	1983	Italian	Renowned penciler celebrated for dynamic action sequences.
190	Jerry	Garcia	1975	Japanese	Two-time Eisner Award winner for outstanding comics writing.
191	Kenneth	Brown	1931	Australian	Two-time Eisner Award winner for outstanding comics writing.
192	Helen	Williams	1954	Brazilian	Award-winning writer known for complex character arcs.
193	Julie	Hall	1980	German	Writer known for socially conscious storytelling and diverse casts.
194	Donna	Allen	1994	Spanish	Writer known for socially conscious storytelling and diverse casts.
195	Susan	Cooper	1964	Spanish	Independent creator known for groundbreaking creator-owned titles.
196	Amanda	Patel	1933	Canadian	Independent creator known for groundbreaking creator-owned titles.
197	Timothy	Ross	1983	French	Legendary artist whose style influenced an entire generation.
198	Julie	Richardson	1924	Italian	Renowned penciler celebrated for dynamic action sequences.
199	Ronald	Green	1961	British	Legendary artist whose style influenced an entire generation.
200	Anna	Smith	1989	Italian	Legendary artist whose style influenced an entire generation.
201	Robert	Young	1986	Japanese	Two-time Eisner Award winner for outstanding comics writing.
202	Ryan	Reed	1976	American	Pioneering colorist who revolutionized digital coloring techniques.
203	Steven	Richardson	1936	French	Writer known for socially conscious storytelling and diverse casts.
204	Janet	Bailey	1935	American	Two-time Eisner Award winner for outstanding comics writing.
205	George	Lee	1959	German	Award-winning writer known for complex character arcs.
206	Raymond	Morris	1931	Australian	Renowned penciler celebrated for dynamic action sequences.
207	Amy	Martin	1939	Italian	Prolific creator with credits spanning five decades of comics.
208	Anna	Nelson	1973	Italian	Writer known for socially conscious storytelling and diverse casts.
209	Kimberly	Ortiz	1990	Canadian	Legendary artist whose style influenced an entire generation.
210	Paul	Bennett	1985	Canadian	Renowned penciler celebrated for dynamic action sequences.
211	Donna	Morales	1963	German	Prolific creator with credits spanning five decades of comics.
212	James	Rivera	1958	Brazilian	Two-time Eisner Award winner for outstanding comics writing.
213	Peter	Bailey	1939	Italian	Artist famed for intricate page layouts and expressive faces.
214	Angela	Turner	1962	German	Artist famed for intricate page layouts and expressive faces.
215	Matthew	Ortiz	1961	Australian	Pioneering colorist who revolutionized digital coloring techniques.
216	Nicole	Collins	1949	Spanish	Award-winning writer known for complex character arcs.
217	Ronald	Cooper	1968	Spanish	Veteran inker whose work defined an entire era of comics.
218	Shirley	Jones	1936	German	Two-time Eisner Award winner for outstanding comics writing.
219	Anthony	Jackson	1976	British	Artist famed for intricate page layouts and expressive faces.
220	Jeffrey	Johnson	1938	Spanish	Veteran inker whose work defined an entire era of comics.
221	Barbara	Cooper	1953	Japanese	Two-time Eisner Award winner for outstanding comics writing.
222	Douglas	Reyes	1930	Japanese	Artist famed for intricate page layouts and expressive faces.
223	Matthew	Roberts	1982	German	Award-winning writer known for complex character arcs.
224	Katherine	Wilson	1950	French	Pioneering colorist who revolutionized digital coloring techniques.
225	Diane	Thomas	1975	British	Renowned penciler celebrated for dynamic action sequences.
226	Larry	Walker	1958	American	Award-winning writer known for complex character arcs.
227	Amanda	Davis	1957	Japanese	Independent creator known for groundbreaking creator-owned titles.
228	Cynthia	Robinson	1951	German	Legendary artist whose style influenced an entire generation.
229	Gregory	Long	1943	Canadian	Veteran inker whose work defined an entire era of comics.
230	William	Mendoza	1968	Brazilian	Pioneering colorist who revolutionized digital coloring techniques.
231	Shirley	Wood	1938	Australian	Writer known for socially conscious storytelling and diverse casts.
232	Christine	Green	1978	French	Award-winning writer known for complex character arcs.
233	Amy	Rivera	1989	Canadian	Renowned penciler celebrated for dynamic action sequences.
234	Larry	Turner	1995	French	Legendary artist whose style influenced an entire generation.
235	Douglas	Green	1978	French	Pioneering colorist who revolutionized digital coloring techniques.
236	Rebecca	Peterson	1933	Australian	Legendary artist whose style influenced an entire generation.
237	Nicole	Diaz	1993	French	Prolific creator with credits spanning five decades of comics.
238	David	Sanders	1970	French	Award-winning writer known for complex character arcs.
239	Gregory	Long	1926	Brazilian	Writer known for socially conscious storytelling and diverse casts.
240	Edward	Nguyen	1965	Australian	Pioneering colorist who revolutionized digital coloring techniques.
241	Katherine	Green	1937	British	Award-winning writer known for complex character arcs.
242	Carol	Rogers	1924	Brazilian	Independent creator known for groundbreaking creator-owned titles.
243	Heather	Thompson	1931	French	Independent creator known for groundbreaking creator-owned titles.
244	Diane	Morales	1942	Australian	Veteran inker whose work defined an entire era of comics.
245	Pamela	Parker	1987	German	Prolific creator with credits spanning five decades of comics.
246	Betty	Green	1981	French	Independent creator known for groundbreaking creator-owned titles.
247	Joseph	Morgan	1929	Canadian	Pioneering colorist who revolutionized digital coloring techniques.
248	Harold	Myers	1970	German	Independent creator known for groundbreaking creator-owned titles.
249	Susan	Reyes	1921	French	Artist famed for intricate page layouts and expressive faces.
250	Karen	Ortiz	1967	French	Two-time Eisner Award winner for outstanding comics writing.
251	Matthew	Price	1967	British	Pioneering colorist who revolutionized digital coloring techniques.
252	Frank	Brown	1991	Japanese	Two-time Eisner Award winner for outstanding comics writing.
253	Donald	Alvarez	1928	Italian	Prolific creator with credits spanning five decades of comics.
254	Debra	Morris	1934	Canadian	Award-winning writer known for complex character arcs.
255	John	Mitchell	1983	British	Renowned penciler celebrated for dynamic action sequences.
256	George	Cox	1937	Spanish	Writer known for socially conscious storytelling and diverse casts.
257	Stephanie	Patel	1989	Spanish	Two-time Eisner Award winner for outstanding comics writing.
258	Diane	Lewis	1973	British	Writer known for socially conscious storytelling and diverse casts.
259	Dennis	Morris	1955	American	Independent creator known for groundbreaking creator-owned titles.
260	Ashley	Rogers	1976	Australian	Independent creator known for groundbreaking creator-owned titles.
261	Richard	Long	1967	German	Independent creator known for groundbreaking creator-owned titles.
262	Patricia	Reyes	1955	Australian	Renowned penciler celebrated for dynamic action sequences.
263	Jeffrey	Thomas	1947	Brazilian	Award-winning writer known for complex character arcs.
264	Robert	Phillips	1951	Canadian	Two-time Eisner Award winner for outstanding comics writing.
265	Mark	Wilson	1990	Australian	Two-time Eisner Award winner for outstanding comics writing.
266	Ashley	Nguyen	1962	Canadian	Two-time Eisner Award winner for outstanding comics writing.
267	James	Baker	1938	Canadian	Artist famed for intricate page layouts and expressive faces.
268	Kenneth	Hall	1934	American	Veteran inker whose work defined an entire era of comics.
269	Maria	Diaz	1950	Brazilian	Independent creator known for groundbreaking creator-owned titles.
270	David	Hall	1953	American	Veteran inker whose work defined an entire era of comics.
271	Arthur	Morales	1987	British	Renowned penciler celebrated for dynamic action sequences.
272	Frank	Gutierrez	1966	German	Two-time Eisner Award winner for outstanding comics writing.
273	Jessica	Gutierrez	1984	Australian	Two-time Eisner Award winner for outstanding comics writing.
274	Linda	Sanders	1986	French	Writer known for socially conscious storytelling and diverse casts.
275	Patrick	Brown	1927	Italian	Legendary artist whose style influenced an entire generation.
276	Jose	Long	1933	Italian	Writer known for socially conscious storytelling and diverse casts.
277	Barbara	Anderson	1961	Brazilian	Veteran inker whose work defined an entire era of comics.
278	Michael	Thompson	1955	Brazilian	Two-time Eisner Award winner for outstanding comics writing.
279	Raymond	Gomez	1968	Brazilian	Artist famed for intricate page layouts and expressive faces.
280	Michelle	Ortiz	1984	Brazilian	Legendary artist whose style influenced an entire generation.
281	Richard	Foster	1934	German	Pioneering colorist who revolutionized digital coloring techniques.
282	Cynthia	Gutierrez	1949	Spanish	Independent creator known for groundbreaking creator-owned titles.
283	Jeffrey	Stewart	1973	British	Independent creator known for groundbreaking creator-owned titles.
284	Jose	Roberts	1952	Japanese	Veteran inker whose work defined an entire era of comics.
285	Carolyn	Cooper	1928	British	Renowned penciler celebrated for dynamic action sequences.
286	Susan	Cook	1932	Japanese	Veteran inker whose work defined an entire era of comics.
287	Emma	Davis	1995	German	Artist famed for intricate page layouts and expressive faces.
288	Anthony	Patel	1935	Spanish	Independent creator known for groundbreaking creator-owned titles.
289	Rachel	Murphy	1926	French	Two-time Eisner Award winner for outstanding comics writing.
290	Carol	Diaz	1933	Brazilian	Artist famed for intricate page layouts and expressive faces.
291	Ashley	Lewis	1981	Australian	Renowned penciler celebrated for dynamic action sequences.
292	Kevin	Watson	1967	British	Prolific creator with credits spanning five decades of comics.
293	Nicole	Torres	1974	German	Two-time Eisner Award winner for outstanding comics writing.
294	Dennis	Myers	1991	American	Two-time Eisner Award winner for outstanding comics writing.
295	Peter	Ross	1954	American	Veteran inker whose work defined an entire era of comics.
296	Steven	Foster	1959	Japanese	Independent creator known for groundbreaking creator-owned titles.
297	James	Allen	1938	Brazilian	Legendary artist whose style influenced an entire generation.
298	Michael	Robinson	1923	British	Artist famed for intricate page layouts and expressive faces.
299	Ashley	Edwards	1973	Italian	Independent creator known for groundbreaking creator-owned titles.
300	Christopher	Cruz	1959	Japanese	Two-time Eisner Award winner for outstanding comics writing.
301	Jerry	Anderson	1926	Canadian	Veteran inker whose work defined an entire era of comics.
302	Ryan	Ruiz	1926	British	Prolific creator with credits spanning five decades of comics.
303	Larry	Sanders	1974	Italian	Two-time Eisner Award winner for outstanding comics writing.
304	Larry	Morales	1954	Australian	Artist famed for intricate page layouts and expressive faces.
305	Joseph	Turner	1975	British	Prolific creator with credits spanning five decades of comics.
306	Harold	Myers	1995	Italian	Artist famed for intricate page layouts and expressive faces.
307	Rachel	Carter	1925	Australian	Legendary artist whose style influenced an entire generation.
308	Jerry	Davis	1920	Australian	Prolific creator with credits spanning five decades of comics.
309	Ashley	Young	1952	French	Independent creator known for groundbreaking creator-owned titles.
310	Karen	Smith	1983	Spanish	Veteran inker whose work defined an entire era of comics.
311	Thomas	Edwards	1988	Australian	Artist famed for intricate page layouts and expressive faces.
312	Emma	Patel	1965	British	Legendary artist whose style influenced an entire generation.
313	Arthur	Garcia	1975	American	Writer known for socially conscious storytelling and diverse casts.
314	Barbara	Roberts	1993	Spanish	Two-time Eisner Award winner for outstanding comics writing.
315	Sharon	Price	1973	French	Renowned penciler celebrated for dynamic action sequences.
316	Sharon	Williams	1961	Canadian	Two-time Eisner Award winner for outstanding comics writing.
317	Jeffrey	Ross	1966	British	Legendary artist whose style influenced an entire generation.
318	Jessica	Flores	1975	Brazilian	Legendary artist whose style influenced an entire generation.
319	Brenda	Anderson	1970	French	Independent creator known for groundbreaking creator-owned titles.
320	Donald	Phillips	1941	British	Artist famed for intricate page layouts and expressive faces.
321	Christine	Harris	1987	German	Pioneering colorist who revolutionized digital coloring techniques.
322	Joyce	Turner	1964	Canadian	Pioneering colorist who revolutionized digital coloring techniques.
323	Jessica	Robinson	1952	Australian	Veteran inker whose work defined an entire era of comics.
324	Samantha	Lewis	1929	Canadian	Writer known for socially conscious storytelling and diverse casts.
325	Amy	Brooks	1994	Italian	Two-time Eisner Award winner for outstanding comics writing.
326	Patrick	Price	1961	Japanese	Veteran inker whose work defined an entire era of comics.
327	Larry	Wilson	1980	Italian	Prolific creator with credits spanning five decades of comics.
328	Donna	James	1927	Japanese	Artist famed for intricate page layouts and expressive faces.
329	Barbara	Carter	1979	Italian	Award-winning writer known for complex character arcs.
330	Patricia	Cruz	1956	British	Renowned penciler celebrated for dynamic action sequences.
331	Dennis	Bennett	1984	Spanish	Writer known for socially conscious storytelling and diverse casts.
332	Joshua	Richardson	1925	Italian	Two-time Eisner Award winner for outstanding comics writing.
333	Debra	Young	1961	Brazilian	Writer known for socially conscious storytelling and diverse casts.
334	Eric	Lewis	1927	Italian	Renowned penciler celebrated for dynamic action sequences.
335	Melissa	Anderson	1984	Canadian	Award-winning writer known for complex character arcs.
336	Kimberly	Rogers	1976	German	Artist famed for intricate page layouts and expressive faces.
337	Dennis	Lee	1966	Japanese	Prolific creator with credits spanning five decades of comics.
338	Rebecca	Morris	1963	Brazilian	Award-winning writer known for complex character arcs.
339	Walter	Alvarez	1962	British	Independent creator known for groundbreaking creator-owned titles.
340	Richard	Watson	1969	French	Prolific creator with credits spanning five decades of comics.
341	Carl	Sanders	1939	Japanese	Renowned penciler celebrated for dynamic action sequences.
342	Joshua	Sanders	1938	Japanese	Prolific creator with credits spanning five decades of comics.
343	Debra	Foster	1970	Canadian	Two-time Eisner Award winner for outstanding comics writing.
344	Henry	Anderson	1959	German	Legendary artist whose style influenced an entire generation.
345	Patrick	Phillips	1936	German	Renowned penciler celebrated for dynamic action sequences.
346	Patrick	Patel	1974	German	Independent creator known for groundbreaking creator-owned titles.
347	David	Parker	1959	Canadian	Pioneering colorist who revolutionized digital coloring techniques.
348	Melissa	Bailey	1944	Australian	Veteran inker whose work defined an entire era of comics.
349	Lisa	Taylor	1957	British	Artist famed for intricate page layouts and expressive faces.
350	Roger	Ward	1987	American	Independent creator known for groundbreaking creator-owned titles.
351	Roger	Ruiz	1936	Brazilian	Legendary artist whose style influenced an entire generation.
352	Lisa	Lee	1943	Brazilian	Veteran inker whose work defined an entire era of comics.
353	Carl	Rogers	1925	Spanish	Independent creator known for groundbreaking creator-owned titles.
354	Harold	Hill	1976	Brazilian	Prolific creator with credits spanning five decades of comics.
355	Ryan	Gutierrez	1949	German	Pioneering colorist who revolutionized digital coloring techniques.
356	Carol	Cooper	1944	Japanese	Two-time Eisner Award winner for outstanding comics writing.
357	Larry	Morgan	1956	Spanish	Artist famed for intricate page layouts and expressive faces.
358	Brenda	Morales	1940	Australian	Two-time Eisner Award winner for outstanding comics writing.
359	Nancy	Green	1926	Italian	Independent creator known for groundbreaking creator-owned titles.
360	Raymond	White	1986	British	Prolific creator with credits spanning five decades of comics.
361	William	Lee	1954	Italian	Artist famed for intricate page layouts and expressive faces.
362	Charles	Cook	1931	Australian	Writer known for socially conscious storytelling and diverse casts.
363	Kevin	Brown	1973	American	Legendary artist whose style influenced an entire generation.
364	Eric	Cruz	1950	Spanish	Renowned penciler celebrated for dynamic action sequences.
365	Stephanie	Torres	1923	Japanese	Renowned penciler celebrated for dynamic action sequences.
366	Maria	Castillo	1962	Canadian	Veteran inker whose work defined an entire era of comics.
367	John	Rivera	1980	Canadian	Writer known for socially conscious storytelling and diverse casts.
368	Kathleen	Mendoza	1920	British	Award-winning writer known for complex character arcs.
369	Kenneth	Scott	1939	German	Two-time Eisner Award winner for outstanding comics writing.
370	Brenda	Murphy	1934	French	Pioneering colorist who revolutionized digital coloring techniques.
371	Brian	Martin	1926	Australian	Legendary artist whose style influenced an entire generation.
372	Christine	Ruiz	1978	British	Renowned penciler celebrated for dynamic action sequences.
373	Shirley	Bennett	1988	American	Artist famed for intricate page layouts and expressive faces.
374	Nicole	Hill	1938	French	Legendary artist whose style influenced an entire generation.
375	James	Mendoza	1965	Australian	Two-time Eisner Award winner for outstanding comics writing.
376	Laura	Allen	1930	German	Independent creator known for groundbreaking creator-owned titles.
377	Michael	Kim	1989	German	Artist famed for intricate page layouts and expressive faces.
378	Raymond	Williams	1969	Italian	Award-winning writer known for complex character arcs.
379	Christine	Collins	1967	French	Award-winning writer known for complex character arcs.
380	Deborah	Wilson	1964	Australian	Renowned penciler celebrated for dynamic action sequences.
381	Roger	Wood	1962	Canadian	Award-winning writer known for complex character arcs.
382	Deborah	Ward	1963	Canadian	Writer known for socially conscious storytelling and diverse casts.
383	Janet	Peterson	1943	Canadian	Renowned penciler celebrated for dynamic action sequences.
384	Maria	Ortiz	1924	French	Pioneering colorist who revolutionized digital coloring techniques.
385	Linda	King	1925	Japanese	Prolific creator with credits spanning five decades of comics.
386	Anna	Reyes	1989	Italian	Prolific creator with credits spanning five decades of comics.
387	John	Alvarez	1944	French	Independent creator known for groundbreaking creator-owned titles.
388	Joyce	Miller	1962	French	Renowned penciler celebrated for dynamic action sequences.
389	Stephanie	Cook	1971	Italian	Legendary artist whose style influenced an entire generation.
390	Melissa	Allen	1983	Italian	Independent creator known for groundbreaking creator-owned titles.
391	Stephen	Nelson	1930	Spanish	Renowned penciler celebrated for dynamic action sequences.
392	Cynthia	Gray	1943	German	Prolific creator with credits spanning five decades of comics.
393	Amanda	White	1930	Japanese	Prolific creator with credits spanning five decades of comics.
394	Carol	Gutierrez	1974	Canadian	Writer known for socially conscious storytelling and diverse casts.
395	Kevin	Gutierrez	1925	Japanese	Two-time Eisner Award winner for outstanding comics writing.
396	Cynthia	Baker	1927	British	Legendary artist whose style influenced an entire generation.
397	Jason	Howard	1940	American	Veteran inker whose work defined an entire era of comics.
398	Samantha	Myers	1976	American	Veteran inker whose work defined an entire era of comics.
399	Michael	Hill	1966	Japanese	Legendary artist whose style influenced an entire generation.
400	Gregory	Jones	1939	Italian	Independent creator known for groundbreaking creator-owned titles.
401	Stephanie	Rogers	1929	Brazilian	Veteran inker whose work defined an entire era of comics.
402	Brenda	Parker	1970	Japanese	Prolific creator with credits spanning five decades of comics.
403	Kimberly	Harris	1923	Canadian	Writer known for socially conscious storytelling and diverse casts.
404	Stephen	Collins	1991	British	Prolific creator with credits spanning five decades of comics.
405	Joyce	Adams	1977	Australian	Two-time Eisner Award winner for outstanding comics writing.
406	Edward	Ross	1982	Australian	Renowned penciler celebrated for dynamic action sequences.
407	Nancy	Taylor	1977	Canadian	Writer known for socially conscious storytelling and diverse casts.
408	Susan	Long	1960	Japanese	Renowned penciler celebrated for dynamic action sequences.
409	Raymond	Ward	1957	French	Veteran inker whose work defined an entire era of comics.
410	Maria	Foster	1942	Japanese	Artist famed for intricate page layouts and expressive faces.
411	Donald	Martin	1945	Canadian	Pioneering colorist who revolutionized digital coloring techniques.
412	Shirley	Brown	1966	German	Two-time Eisner Award winner for outstanding comics writing.
413	Stephanie	Morgan	1990	Canadian	Two-time Eisner Award winner for outstanding comics writing.
414	Susan	Wilson	1959	Spanish	Writer known for socially conscious storytelling and diverse casts.
415	Brenda	Morris	1972	Brazilian	Renowned penciler celebrated for dynamic action sequences.
416	Thomas	Roberts	1929	Italian	Writer known for socially conscious storytelling and diverse casts.
417	Carolyn	Ramos	1964	Canadian	Artist famed for intricate page layouts and expressive faces.
418	Christine	James	1943	Canadian	Legendary artist whose style influenced an entire generation.
419	Eric	Davis	1935	German	Veteran inker whose work defined an entire era of comics.
420	Brian	Walker	1940	Japanese	Pioneering colorist who revolutionized digital coloring techniques.
421	Kevin	Ramos	1956	British	Prolific creator with credits spanning five decades of comics.
422	Sandra	Price	1990	French	Veteran inker whose work defined an entire era of comics.
423	Walter	Mitchell	1988	British	Artist famed for intricate page layouts and expressive faces.
424	Patrick	Walker	1995	Brazilian	Veteran inker whose work defined an entire era of comics.
425	Betty	Sanders	1963	Brazilian	Award-winning writer known for complex character arcs.
426	Sarah	Anderson	1925	Brazilian	Prolific creator with credits spanning five decades of comics.
427	Debra	Wright	1993	Spanish	Two-time Eisner Award winner for outstanding comics writing.
428	Christine	Brown	1983	German	Prolific creator with credits spanning five decades of comics.
429	Patrick	Mitchell	1981	Australian	Legendary artist whose style influenced an entire generation.
430	Brian	Ortiz	1929	American	Veteran inker whose work defined an entire era of comics.
431	Larry	Morales	1981	Italian	Pioneering colorist who revolutionized digital coloring techniques.
432	Melissa	Gray	1938	Japanese	Independent creator known for groundbreaking creator-owned titles.
433	Heather	Turner	1971	Canadian	Independent creator known for groundbreaking creator-owned titles.
434	Anna	Watson	1933	Japanese	Pioneering colorist who revolutionized digital coloring techniques.
435	Amy	Martin	1954	Italian	Pioneering colorist who revolutionized digital coloring techniques.
436	Charles	Jackson	1926	French	Legendary artist whose style influenced an entire generation.
437	Dennis	Morales	1951	Canadian	Independent creator known for groundbreaking creator-owned titles.
438	Nicole	Roberts	1944	Canadian	Writer known for socially conscious storytelling and diverse casts.
439	Anna	Morgan	1983	French	Writer known for socially conscious storytelling and diverse casts.
440	David	Thomas	1970	German	Writer known for socially conscious storytelling and diverse casts.
441	George	Scott	1994	Japanese	Award-winning writer known for complex character arcs.
442	Robert	Rivera	1983	Brazilian	Writer known for socially conscious storytelling and diverse casts.
443	Edward	Cox	1921	British	Legendary artist whose style influenced an entire generation.
444	Nancy	Adams	1966	Spanish	Independent creator known for groundbreaking creator-owned titles.
445	Linda	Stewart	1926	Brazilian	Artist famed for intricate page layouts and expressive faces.
446	Paul	Parker	1990	French	Renowned penciler celebrated for dynamic action sequences.
447	Rebecca	Kelly	1977	German	Prolific creator with credits spanning five decades of comics.
448	Katherine	Long	1935	Canadian	Renowned penciler celebrated for dynamic action sequences.
449	Gary	Cruz	1963	German	Independent creator known for groundbreaking creator-owned titles.
450	Ryan	Robinson	1945	Brazilian	Artist famed for intricate page layouts and expressive faces.
451	Sharon	Kelly	1925	American	Award-winning writer known for complex character arcs.
452	Nancy	Phillips	1980	German	Writer known for socially conscious storytelling and diverse casts.
453	Lisa	Gray	1985	Canadian	Independent creator known for groundbreaking creator-owned titles.
454	Dennis	Roberts	1940	Spanish	Two-time Eisner Award winner for outstanding comics writing.
455	Arthur	Mitchell	1995	Japanese	Artist famed for intricate page layouts and expressive faces.
456	Anna	Cox	1982	Brazilian	Prolific creator with credits spanning five decades of comics.
457	Frank	Williams	1967	Japanese	Renowned penciler celebrated for dynamic action sequences.
458	Laura	Wood	1959	American	Two-time Eisner Award winner for outstanding comics writing.
459	Frank	Adams	1994	Brazilian	Pioneering colorist who revolutionized digital coloring techniques.
460	Carl	Miller	1994	Italian	Veteran inker whose work defined an entire era of comics.
461	Brenda	Hughes	1968	Canadian	Pioneering colorist who revolutionized digital coloring techniques.
462	John	Chavez	1934	Australian	Award-winning writer known for complex character arcs.
463	Larry	Roberts	1973	Canadian	Legendary artist whose style influenced an entire generation.
464	Douglas	Wright	1972	German	Two-time Eisner Award winner for outstanding comics writing.
465	Frank	Davis	1937	German	Pioneering colorist who revolutionized digital coloring techniques.
466	Emma	Gomez	1981	German	Legendary artist whose style influenced an entire generation.
467	Ronald	Hall	1978	German	Independent creator known for groundbreaking creator-owned titles.
468	Pamela	Diaz	1953	Brazilian	Writer known for socially conscious storytelling and diverse casts.
469	Paul	Flores	1955	German	Prolific creator with credits spanning five decades of comics.
470	Donald	Mitchell	1956	Australian	Writer known for socially conscious storytelling and diverse casts.
471	Ronald	Peterson	1964	German	Prolific creator with credits spanning five decades of comics.
472	Edward	Martin	1993	German	Legendary artist whose style influenced an entire generation.
473	Gary	Turner	1938	French	Award-winning writer known for complex character arcs.
474	Edward	Anderson	1964	Italian	Prolific creator with credits spanning five decades of comics.
475	Diane	Peterson	1947	Australian	Artist famed for intricate page layouts and expressive faces.
476	Steven	Watson	1954	Canadian	Renowned penciler celebrated for dynamic action sequences.
477	Dennis	James	1950	Australian	Award-winning writer known for complex character arcs.
478	Rachel	Kim	1948	Australian	Award-winning writer known for complex character arcs.
479	Richard	Morris	1962	Italian	Renowned penciler celebrated for dynamic action sequences.
480	Carolyn	Young	1920	German	Veteran inker whose work defined an entire era of comics.
481	Timothy	Castillo	1980	Italian	Pioneering colorist who revolutionized digital coloring techniques.
482	Ryan	Rivera	1961	French	Award-winning writer known for complex character arcs.
483	Roger	Thomas	1993	Australian	Artist famed for intricate page layouts and expressive faces.
484	Arthur	Jones	1942	Spanish	Veteran inker whose work defined an entire era of comics.
485	John	Reyes	1983	Canadian	Prolific creator with credits spanning five decades of comics.
486	John	Johnson	1958	Brazilian	Two-time Eisner Award winner for outstanding comics writing.
487	Jessica	Phillips	1956	Italian	Artist famed for intricate page layouts and expressive faces.
488	Brenda	Reed	1937	German	Writer known for socially conscious storytelling and diverse casts.
489	Steven	Young	1934	Japanese	Veteran inker whose work defined an entire era of comics.
490	Heather	Ortiz	1952	Canadian	Award-winning writer known for complex character arcs.
491	Arthur	Evans	1957	Brazilian	Pioneering colorist who revolutionized digital coloring techniques.
492	Daniel	Mendoza	1971	Spanish	Artist famed for intricate page layouts and expressive faces.
493	Amanda	Thomas	1971	British	Veteran inker whose work defined an entire era of comics.
494	Nancy	Peterson	1961	Australian	Award-winning writer known for complex character arcs.
495	Emily	Collins	1950	Italian	Prolific creator with credits spanning five decades of comics.
496	Anthony	Mitchell	1994	Brazilian	Award-winning writer known for complex character arcs.
497	Emily	Castillo	1966	Australian	Award-winning writer known for complex character arcs.
498	Rachel	Martin	1979	French	Veteran inker whose work defined an entire era of comics.
499	Sharon	Long	1984	French	Renowned penciler celebrated for dynamic action sequences.
500	Christine	Campbell	1967	Brazilian	Pioneering colorist who revolutionized digital coloring techniques.
\.


--
-- TOC entry 5108 (class 0 OID 32880)
-- Dependencies: 226
-- Data for Name: issue; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.issue (issue_id, series_id, issue_number, title, publish_date, cover_price, page_count, notes) FROM stdin;
1	109	581	Oblivion of Holt	2024-10-06	0.12	28	Low distribution; considered scarce.
2	279	674	Dawn of Cross	1966-08-22	1.50	24	High print run; common in collections.
3	74	408	Shadows of Burns	2023-12-29	0.35	100	High print run; common in collections.
4	291	694	Descent of Flynn	1970-06-16	2.50	32	Landmark story milestone.
5	257	355	Dawn of Kane	2006-09-20	2.99	36	Landmark story milestone.
6	175	788	Shattered of Price	1978-10-14	2.50	44	Key first appearance issue.
7	140	462	Oblivion of Vale	1994-10-15	1.95	80	Direct edition only; no newsstand version.
8	222	697	Reborn of Ward	1997-05-02	0.15	100	Low distribution; considered scarce.
9	127	76	Shadows of Holt	2023-12-29	0.25	48	Controversial issue banned in three states.
10	200	370	Rising of Voss	1983-05-30	0.10	40	Contains bonus pin-up gallery.
11	185	277	Rising of Steele	2001-07-16	0.15	32	Direct edition only; no newsstand version.
12	230	569	Resurgence of Crane	1972-06-28	0.20	24	Landmark story milestone.
13	182	96	Shattered of Price	2002-09-21	1.50	48	Key first appearance issue.
14	150	398	Shadows of Grant	2014-07-24	0.75	100	Double-sized anniversary issue.
15	87	174	Fallen of Holt	2003-02-27	1.25	40	Contains bonus pin-up gallery.
16	75	172	Legacy of Holt	1973-11-02	2.99	40	Contains bonus pin-up gallery.
17	40	258	Revelation of Stark	1947-01-10	0.50	64	Landmark story milestone.
18	70	7	Nemesis of Flynn	1960-08-31	2.50	44	Contains bonus pin-up gallery.
19	172	667	Shattered of Steele	1983-08-29	1.25	44	Reprints classic story with new framing pages.
20	103	322	Convergence of Ward	1955-05-17	1.50	40	Contains bonus pin-up gallery.
21	295	334	Nemesis of Holt	1943-05-12	2.50	44	Landmark story milestone.
22	289	607	Descent of Cross	1994-06-25	0.10	64	High print run; common in collections.
23	225	710	Shadows of Crane	1986-01-26	4.99	32	Low distribution; considered scarce.
24	124	675	Fallen of Crane	1946-09-01	2.50	28	Contains bonus pin-up gallery.
25	246	411	Descent of Cole	2009-02-12	2.99	80	Key first appearance issue.
26	185	550	Shattered of Voss	2000-11-13	0.20	36	Part of a crossover event.
27	86	577	Nemesis of Flynn	1999-12-27	2.99	28	Key first appearance issue.
28	51	228	Resurgence of Cole	2014-10-21	0.75	64	Part of a crossover event.
29	201	791	Reborn of Cole	2015-05-22	0.25	44	Key first appearance issue.
30	248	303	Legacy of Voss	2011-03-05	0.20	32	Part of a crossover event.
31	160	467	Uprising of Cole	1952-12-17	4.99	44	Contains bonus pin-up gallery.
32	50	740	Fracture of Flynn	1977-04-23	0.15	40	Key first appearance issue.
33	59	352	Rising of Cross	1990-01-06	0.75	80	Controversial issue banned in three states.
34	283	339	Descent of Crane	1970-10-18	3.99	36	Direct edition only; no newsstand version.
35	95	656	Legacy of Ward	1988-09-20	0.10	100	High print run; common in collections.
36	231	440	Nemesis of Morgan	2001-07-25	0.50	36	Low distribution; considered scarce.
37	33	105	Descent of Cross	1984-03-28	1.95	44	High print run; common in collections.
38	235	269	Oblivion of Cole	2006-07-22	1.50	100	Direct edition only; no newsstand version.
39	201	117	Inferno of Nash	2018-03-02	3.99	100	Controversial issue banned in three states.
40	153	689	Fallen of Flynn	1968-12-13	0.20	36	Low distribution; considered scarce.
41	60	383	Fallen of Cole	1962-01-19	2.50	48	Reprints classic story with new framing pages.
42	71	393	Legacy of Cross	2020-07-27	4.99	80	Controversial issue banned in three states.
43	285	502	Vendetta of Steele	1972-06-26	0.35	44	Contains bonus pin-up gallery.
44	28	368	Reckoning of Stark	2019-10-29	0.25	36	Direct edition only; no newsstand version.
45	288	669	Oblivion of Crane	2012-09-03	4.99	48	Contains bonus pin-up gallery.
46	251	85	Reborn of Morgan	1958-01-02	0.75	40	Key first appearance issue.
47	141	551	Vendetta of Cross	1980-02-01	3.99	100	Contains bonus pin-up gallery.
48	282	116	Reborn of Kane	1998-11-30	1.00	80	Part of a crossover event.
49	278	43	Fracture of Grant	1980-12-21	0.50	48	Landmark story milestone.
50	127	34	Fracture of Holt	2014-09-04	1.95	28	Contains bonus pin-up gallery.
51	61	243	Uprising of Hunt	1995-05-25	1.95	100	Direct edition only; no newsstand version.
52	85	143	Uprising of Stone	2023-08-22	0.12	100	Part of a crossover event.
53	273	612	Descent of Cross	1964-03-20	1.50	40	Low distribution; considered scarce.
54	294	527	Rising of Steele	2012-12-31	2.99	24	Low distribution; considered scarce.
55	65	136	Revelation of Steele	2016-12-05	1.50	36	Direct edition only; no newsstand version.
56	251	592	Chaos of Crane	1955-10-03	2.50	64	Landmark story milestone.
57	48	528	Chaos of Nash	1992-01-27	3.99	64	Part of a crossover event.
58	298	793	Shadows of Fox	1950-01-11	1.95	28	Double-sized anniversary issue.
59	204	440	Uprising of Stark	1989-11-20	1.00	44	Low distribution; considered scarce.
60	173	592	Fallen of Hunt	2023-07-21	4.99	44	Key first appearance issue.
61	24	642	Fracture of Morgan	1968-07-22	0.20	32	Contains bonus pin-up gallery.
62	234	439	Uprising of Steele	1990-01-02	1.25	32	Low distribution; considered scarce.
63	48	257	Shadows of Nash	1990-03-03	0.35	24	Direct edition only; no newsstand version.
64	157	774	Revelation of Crane	2021-12-17	0.15	28	Key first appearance issue.
65	110	80	Fallen of Hunt	2018-05-08	0.75	80	Contains bonus pin-up gallery.
66	5	713	Eclipse of Kane	1957-09-22	2.99	32	Contains bonus pin-up gallery.
67	37	393	Shadows of Kane	1981-04-09	0.20	44	Part of a crossover event.
68	154	392	Fallen of Steele	1997-02-24	0.15	80	Reprints classic story with new framing pages.
69	5	666	Convergence of Fox	2011-10-03	1.95	36	Controversial issue banned in three states.
70	211	704	Fracture of Stone	2003-04-09	0.15	28	Controversial issue banned in three states.
71	64	360	Legacy of Flynn	2019-03-24	0.25	36	Low distribution; considered scarce.
72	44	567	Shattered of Price	1969-04-06	1.25	24	Low distribution; considered scarce.
73	106	622	Resurgence of Stone	2004-10-21	2.50	40	Key first appearance issue.
74	123	396	Rising of Vale	2008-05-25	4.99	100	Landmark story milestone.
75	271	13	Inferno of Flynn	1953-12-26	0.25	48	Reprints classic story with new framing pages.
76	216	560	Convergence of Stark	1978-10-13	0.15	24	Reprints classic story with new framing pages.
77	35	269	Uprising of Drake	2007-01-29	0.12	48	Double-sized anniversary issue.
78	147	786	Legacy of Crane	1960-03-28	2.50	28	Double-sized anniversary issue.
79	276	157	Chaos of Voss	1982-10-26	1.25	28	Double-sized anniversary issue.
80	105	160	Descent of Flynn	2023-07-13	2.50	100	Landmark story milestone.
81	159	448	Revelation of Drake	1971-09-02	0.75	28	Direct edition only; no newsstand version.
82	60	627	Shattered of Drake	1965-01-31	1.25	32	Landmark story milestone.
83	7	719	Reckoning of Cross	1956-01-30	4.99	44	Double-sized anniversary issue.
84	265	739	Chaos of Cross	2014-03-30	1.95	32	Low distribution; considered scarce.
85	61	31	Eclipse of Crane	1995-04-21	1.00	80	Landmark story milestone.
86	135	643	Shadows of Stark	2023-06-20	3.99	80	Part of a crossover event.
87	29	581	Convergence of Nash	1949-10-20	0.35	40	Landmark story milestone.
88	294	741	Rising of Vale	2017-07-24	0.10	24	Key first appearance issue.
89	126	484	Inferno of Ward	1975-07-08	0.25	32	Key first appearance issue.
90	284	430	Revelation of Flynn	2017-11-02	0.75	48	Part of a crossover event.
91	139	586	Inferno of Kane	1993-06-30	0.12	32	High print run; common in collections.
92	265	411	Shadows of Fox	1948-02-13	1.25	40	Part of a crossover event.
93	45	468	Reckoning of Nash	2020-08-14	0.50	40	Reprints classic story with new framing pages.
94	156	638	Revelation of Fox	2011-05-09	1.95	100	Contains bonus pin-up gallery.
95	101	779	Revelation of Steele	2020-07-07	0.10	48	Key first appearance issue.
96	120	652	Reckoning of Flynn	1989-10-08	0.10	48	Low distribution; considered scarce.
97	54	543	Revelation of Crane	1999-03-16	4.99	24	Controversial issue banned in three states.
98	144	45	Revelation of Cole	1944-03-04	2.99	44	Contains bonus pin-up gallery.
99	44	98	Resurgence of Steele	1999-02-07	2.50	28	Reprints classic story with new framing pages.
100	291	446	Fallen of Vale	1955-10-18	1.25	40	Part of a crossover event.
101	202	326	Fracture of Holt	2018-10-31	0.75	28	High print run; common in collections.
102	70	112	Fallen of Kane	1973-03-24	0.35	64	Contains bonus pin-up gallery.
103	161	124	Descent of Nash	2015-06-21	0.50	64	Low distribution; considered scarce.
104	238	123	Shadows of Cross	1951-12-22	1.25	100	Key first appearance issue.
105	111	336	Fallen of Voss	1973-05-16	0.75	44	Direct edition only; no newsstand version.
106	263	694	Vendetta of Holt	1969-05-24	0.35	24	Direct edition only; no newsstand version.
107	232	767	Descent of Vale	1990-11-17	0.20	64	Landmark story milestone.
108	72	13	Dawn of Vale	1965-06-12	0.25	36	Direct edition only; no newsstand version.
109	191	597	Reborn of Holt	2005-10-08	0.15	24	Landmark story milestone.
110	102	455	Fallen of Voss	1972-03-30	1.50	28	Key first appearance issue.
111	237	173	Reborn of Crane	2019-04-14	2.50	64	Key first appearance issue.
112	196	177	Inferno of Stone	1959-07-28	0.35	40	Low distribution; considered scarce.
113	229	36	Shattered of Price	1977-05-02	0.75	40	Contains bonus pin-up gallery.
114	211	491	Dawn of Voss	1997-05-27	1.00	48	Controversial issue banned in three states.
115	215	659	Resurgence of Vale	1988-02-13	0.10	48	Part of a crossover event.
116	246	497	Inferno of Hunt	2007-06-05	1.50	48	Low distribution; considered scarce.
117	93	327	Shattered of Vale	2020-02-23	0.10	40	Key first appearance issue.
118	242	367	Reborn of Vale	2019-10-01	0.35	28	High print run; common in collections.
119	124	547	Dawn of Vale	1946-12-24	2.50	44	Controversial issue banned in three states.
120	91	607	Eclipse of Nash	2020-08-26	0.10	44	Reprints classic story with new framing pages.
121	289	577	Uprising of Stark	1993-03-10	1.25	32	Contains bonus pin-up gallery.
122	20	58	Revelation of Price	1942-01-18	0.75	24	Double-sized anniversary issue.
123	245	340	Shattered of Stone	1979-01-12	0.25	44	Controversial issue banned in three states.
124	166	23	Fallen of Hunt	1984-05-05	0.25	28	Double-sized anniversary issue.
125	187	383	Nemesis of Hunt	1963-08-18	0.20	44	Low distribution; considered scarce.
126	166	162	Legacy of Stark	1991-03-30	1.50	32	Double-sized anniversary issue.
127	183	682	Reborn of Cross	1948-01-03	2.50	40	Low distribution; considered scarce.
128	66	747	Reckoning of Hunt	1983-12-21	2.50	100	Key first appearance issue.
129	94	326	Shattered of Vale	2010-10-03	0.20	64	Controversial issue banned in three states.
130	170	244	Inferno of Flynn	1949-06-09	0.35	28	Part of a crossover event.
131	229	272	Uprising of Vale	1974-04-04	0.15	44	Low distribution; considered scarce.
132	56	2	Dawn of Ward	1962-01-15	3.99	48	Controversial issue banned in three states.
133	212	388	Inferno of Grant	1988-03-27	2.50	28	Contains bonus pin-up gallery.
134	296	167	Fracture of Voss	2020-07-12	0.12	40	Key first appearance issue.
135	164	108	Shadows of Flynn	2004-11-09	0.35	48	Controversial issue banned in three states.
136	39	347	Shattered of Price	1986-05-09	4.99	24	Direct edition only; no newsstand version.
137	85	445	Convergence of Drake	2023-03-30	0.20	44	High print run; common in collections.
138	98	714	Descent of Grant	2018-03-07	1.00	40	Low distribution; considered scarce.
139	122	51	Nemesis of Hunt	1952-08-08	4.99	32	Key first appearance issue.
140	185	438	Shadows of Burns	1993-01-16	4.99	36	Landmark story milestone.
141	14	175	Vendetta of Voss	1992-08-22	4.99	28	Low distribution; considered scarce.
142	204	501	Chaos of Voss	1995-07-25	2.50	32	Part of a crossover event.
143	196	192	Fracture of Drake	1958-04-15	1.00	64	Contains bonus pin-up gallery.
144	135	276	Reborn of Drake	2019-07-16	0.25	28	Landmark story milestone.
145	177	555	Legacy of Hunt	2021-04-03	0.75	80	Key first appearance issue.
146	199	429	Descent of Stark	1960-09-20	0.75	64	Low distribution; considered scarce.
147	41	732	Dawn of Cole	2006-09-17	0.25	28	Contains bonus pin-up gallery.
148	89	217	Uprising of Steele	2015-12-09	0.12	48	Landmark story milestone.
149	223	643	Fallen of Price	1965-07-13	1.00	44	Landmark story milestone.
150	45	570	Nemesis of Grant	2005-10-26	1.50	40	Double-sized anniversary issue.
151	235	13	Shattered of Hunt	2024-07-27	2.99	28	Direct edition only; no newsstand version.
152	77	581	Reborn of Hunt	2010-04-29	0.20	28	Reprints classic story with new framing pages.
153	52	549	Inferno of Crane	2014-06-01	1.00	48	Contains bonus pin-up gallery.
154	293	39	Convergence of Holt	2017-04-21	2.50	32	Reprints classic story with new framing pages.
155	206	406	Eclipse of Vale	1985-03-21	0.12	64	Low distribution; considered scarce.
156	191	346	Vendetta of Burns	2002-11-28	1.00	64	Landmark story milestone.
157	117	308	Fracture of Flynn	2015-07-05	1.00	48	Reprints classic story with new framing pages.
158	46	453	Uprising of Crane	1962-03-20	4.99	80	Part of a crossover event.
159	29	163	Shadows of Burns	1949-11-21	2.50	32	Double-sized anniversary issue.
160	292	178	Uprising of Stone	1991-04-20	0.12	36	Key first appearance issue.
161	234	370	Uprising of Holt	1990-04-14	1.95	64	Double-sized anniversary issue.
162	204	127	Reckoning of Vale	1999-04-03	1.95	64	Reprints classic story with new framing pages.
163	229	486	Reborn of Grant	1977-12-25	1.95	44	Controversial issue banned in three states.
164	133	292	Reckoning of Ward	2002-01-06	0.12	32	Reprints classic story with new framing pages.
165	110	663	Revelation of Stone	2015-06-26	1.00	48	Double-sized anniversary issue.
166	11	486	Fallen of Cross	2006-02-06	0.10	36	Low distribution; considered scarce.
167	157	727	Chaos of Crane	2021-12-30	2.50	44	Contains bonus pin-up gallery.
168	130	478	Vendetta of Cole	2010-11-23	2.50	100	Landmark story milestone.
169	4	679	Inferno of Grant	1974-06-08	1.25	40	Landmark story milestone.
170	247	345	Chaos of Flynn	1957-11-11	1.00	40	Low distribution; considered scarce.
171	97	530	Revelation of Drake	1964-05-13	2.50	44	Controversial issue banned in three states.
172	14	510	Vendetta of Holt	2002-09-13	2.99	48	Direct edition only; no newsstand version.
173	19	352	Revelation of Grant	1976-04-04	4.99	44	Double-sized anniversary issue.
174	154	674	Descent of Cross	1998-08-17	1.25	28	Contains bonus pin-up gallery.
175	66	743	Descent of Cross	1987-08-08	1.50	28	High print run; common in collections.
176	182	763	Vendetta of Crane	1973-01-14	1.50	44	Low distribution; considered scarce.
177	300	475	Rising of Stark	2020-10-28	0.12	100	Reprints classic story with new framing pages.
178	37	200	Resurgence of Kane	1992-03-07	2.50	80	Low distribution; considered scarce.
179	212	155	Fallen of Stone	1948-11-06	1.50	48	Reprints classic story with new framing pages.
180	235	324	Convergence of Voss	2007-03-19	4.99	44	Controversial issue banned in three states.
181	161	5	Fracture of Holt	1984-03-15	0.50	32	Reprints classic story with new framing pages.
182	82	782	Shadows of Steele	1984-12-03	2.99	48	Direct edition only; no newsstand version.
183	220	393	Reckoning of Drake	1998-09-15	0.50	44	Key first appearance issue.
184	165	196	Reckoning of Morgan	1981-12-23	0.75	36	Part of a crossover event.
185	160	106	Nemesis of Cole	1952-05-12	1.25	32	Landmark story milestone.
186	24	298	Fracture of Cole	1969-09-02	1.50	48	Controversial issue banned in three states.
187	176	368	Uprising of Cross	2012-09-30	2.50	24	High print run; common in collections.
188	115	135	Uprising of Morgan	2012-03-27	0.35	28	Part of a crossover event.
189	20	656	Chaos of Grant	1954-10-31	0.12	100	Key first appearance issue.
190	56	21	Dawn of Kane	1961-08-31	2.99	64	Direct edition only; no newsstand version.
191	64	486	Fallen of Stone	2013-05-03	0.10	40	Direct edition only; no newsstand version.
192	52	533	Chaos of Price	2022-11-10	0.25	48	Landmark story milestone.
193	262	633	Rising of Burns	2007-06-26	0.20	28	Contains bonus pin-up gallery.
194	102	205	Chaos of Cole	1971-10-31	0.50	44	Direct edition only; no newsstand version.
195	152	41	Descent of Stark	1969-05-22	0.50	64	Part of a crossover event.
196	121	14	Shadows of Kane	1989-02-14	4.99	32	Landmark story milestone.
197	262	741	Rising of Holt	1949-09-25	0.75	64	Low distribution; considered scarce.
198	136	52	Rising of Cross	2020-08-08	0.12	40	Part of a crossover event.
199	161	757	Rising of Kane	2017-03-21	0.12	24	Controversial issue banned in three states.
200	88	367	Fracture of Price	2005-05-16	1.00	28	Part of a crossover event.
201	176	117	Nemesis of Ward	2011-01-10	3.99	40	Direct edition only; no newsstand version.
202	245	665	Convergence of Kane	1997-12-01	0.25	24	Controversial issue banned in three states.
203	54	605	Oblivion of Hunt	2008-08-30	3.99	32	Reprints classic story with new framing pages.
204	195	627	Reckoning of Steele	2006-03-04	4.99	64	Landmark story milestone.
205	211	48	Shadows of Holt	1987-07-15	1.50	24	Double-sized anniversary issue.
206	296	230	Eclipse of Cole	2024-05-03	0.20	48	High print run; common in collections.
207	247	680	Nemesis of Steele	1970-07-05	0.12	24	Controversial issue banned in three states.
208	259	508	Convergence of Voss	2017-07-11	4.99	44	High print run; common in collections.
209	170	52	Resurgence of Vale	1950-07-24	2.50	48	High print run; common in collections.
210	41	455	Reborn of Fox	2009-08-05	0.15	64	Contains bonus pin-up gallery.
211	162	510	Reckoning of Kane	1954-08-30	2.50	48	Key first appearance issue.
212	286	94	Shattered of Price	2011-01-02	1.25	80	Double-sized anniversary issue.
213	106	350	Inferno of Drake	2004-02-12	0.75	64	Part of a crossover event.
214	287	635	Shattered of Stark	1962-03-19	1.95	64	Landmark story milestone.
215	50	675	Revelation of Morgan	2006-02-14	1.50	44	Low distribution; considered scarce.
216	281	383	Rising of Drake	2017-09-16	0.35	64	Controversial issue banned in three states.
217	210	261	Shattered of Stone	1951-08-06	0.50	28	Direct edition only; no newsstand version.
218	111	196	Eclipse of Kane	1969-02-15	2.99	24	Reprints classic story with new framing pages.
219	64	469	Reborn of Cole	2022-03-18	0.25	64	Key first appearance issue.
220	272	50	Descent of Crane	2020-01-10	4.99	80	Controversial issue banned in three states.
221	297	749	Fallen of Kane	1941-12-12	2.50	100	Reprints classic story with new framing pages.
222	165	394	Legacy of Price	1981-10-29	0.75	40	Direct edition only; no newsstand version.
223	176	464	Fallen of Steele	2011-08-26	2.99	100	Double-sized anniversary issue.
224	154	322	Descent of Stone	2015-07-29	0.50	36	Reprints classic story with new framing pages.
225	149	354	Fallen of Cross	2014-10-19	1.50	28	Part of a crossover event.
226	288	597	Reborn of Crane	2011-07-20	1.25	48	Key first appearance issue.
227	268	26	Nemesis of Steele	1989-03-12	0.12	24	High print run; common in collections.
228	137	165	Vendetta of Holt	1953-03-17	0.25	24	Low distribution; considered scarce.
229	105	555	Dawn of Nash	2023-03-24	3.99	28	Reprints classic story with new framing pages.
230	288	761	Descent of Ward	2000-01-24	0.75	80	Low distribution; considered scarce.
231	25	397	Legacy of Flynn	1988-03-26	0.12	24	Low distribution; considered scarce.
232	104	800	Fracture of Vale	2019-12-02	1.95	100	Double-sized anniversary issue.
233	101	302	Fracture of Cross	2004-09-05	0.15	32	Controversial issue banned in three states.
234	264	387	Dawn of Crane	2015-09-05	1.00	80	Low distribution; considered scarce.
235	67	599	Chaos of Morgan	2013-10-21	1.50	64	Controversial issue banned in three states.
236	21	331	Shattered of Drake	2019-09-22	1.25	64	Reprints classic story with new framing pages.
237	282	75	Eclipse of Cole	1992-01-23	0.75	32	Double-sized anniversary issue.
238	35	164	Legacy of Grant	2009-10-31	2.50	28	Part of a crossover event.
239	114	680	Eclipse of Flynn	1967-10-14	1.95	40	High print run; common in collections.
240	272	575	Reckoning of Kane	2008-04-20	1.95	64	High print run; common in collections.
241	125	699	Eclipse of Ward	1967-10-16	0.20	48	Low distribution; considered scarce.
242	277	26	Resurgence of Nash	1966-03-04	3.99	64	Key first appearance issue.
243	152	198	Eclipse of Cole	2013-06-14	0.15	28	Controversial issue banned in three states.
244	276	8	Shadows of Stone	1980-12-17	0.50	48	Landmark story milestone.
245	106	720	Legacy of Voss	2005-01-11	0.25	24	Contains bonus pin-up gallery.
246	170	90	Shadows of Drake	1949-03-19	0.35	40	Double-sized anniversary issue.
247	37	234	Chaos of Crane	1996-10-16	2.50	64	Direct edition only; no newsstand version.
248	222	18	Nemesis of Kane	2003-03-12	0.10	100	Landmark story milestone.
249	300	718	Shadows of Nash	2020-02-16	0.20	40	Low distribution; considered scarce.
250	45	784	Fracture of Ward	1996-04-03	2.50	24	Contains bonus pin-up gallery.
251	81	226	Fallen of Ward	2012-12-25	1.25	32	Low distribution; considered scarce.
252	192	567	Descent of Steele	1987-04-02	0.20	24	Key first appearance issue.
253	294	404	Descent of Grant	2016-09-09	0.15	40	High print run; common in collections.
254	177	423	Resurgence of Steele	1994-07-02	0.35	32	High print run; common in collections.
255	130	118	Convergence of Hunt	2010-05-11	0.12	80	Contains bonus pin-up gallery.
256	282	298	Shadows of Holt	1979-04-13	0.20	36	Reprints classic story with new framing pages.
257	250	366	Fallen of Vale	1987-09-17	0.20	40	Reprints classic story with new framing pages.
258	36	326	Oblivion of Fox	1973-09-06	1.50	100	Low distribution; considered scarce.
259	300	580	Reborn of Nash	2020-06-05	1.50	48	Controversial issue banned in three states.
260	3	253	Revelation of Crane	1955-01-19	1.00	44	Controversial issue banned in three states.
261	170	474	Fracture of Nash	1951-09-10	1.25	64	Double-sized anniversary issue.
262	56	662	Shattered of Voss	1958-12-26	1.00	32	Double-sized anniversary issue.
263	101	752	Shadows of Voss	2007-10-22	0.10	80	Key first appearance issue.
264	298	415	Reborn of Stone	1956-06-29	0.12	80	Low distribution; considered scarce.
265	279	484	Fallen of Nash	1966-02-08	2.50	36	Reprints classic story with new framing pages.
266	149	476	Resurgence of Cole	1990-01-02	0.15	48	Part of a crossover event.
267	258	679	Revelation of Price	1979-03-28	0.35	80	Controversial issue banned in three states.
268	229	184	Reborn of Hunt	1977-07-28	0.25	64	Part of a crossover event.
269	21	780	Oblivion of Vale	2020-06-15	0.15	40	Part of a crossover event.
270	120	685	Uprising of Cole	1982-12-17	1.95	48	Contains bonus pin-up gallery.
271	233	41	Eclipse of Kane	2016-04-05	1.00	40	Reprints classic story with new framing pages.
272	279	179	Nemesis of Ward	1966-10-15	1.95	100	Landmark story milestone.
273	265	386	Revelation of Cole	1966-07-27	2.50	44	Part of a crossover event.
274	250	619	Reckoning of Cole	1989-05-28	0.25	64	Controversial issue banned in three states.
275	118	527	Chaos of Stone	1970-06-17	0.25	32	Controversial issue banned in three states.
276	186	677	Revelation of Crane	1993-04-22	1.50	28	Contains bonus pin-up gallery.
277	246	216	Reborn of Cross	2004-06-27	2.99	24	High print run; common in collections.
278	23	588	Reborn of Cross	1951-06-22	0.25	80	Key first appearance issue.
279	294	58	Convergence of Holt	2011-08-25	0.35	80	Direct edition only; no newsstand version.
280	289	20	Vendetta of Voss	2004-04-20	0.50	64	Reprints classic story with new framing pages.
281	242	175	Revelation of Crane	2017-08-09	0.25	100	Controversial issue banned in three states.
282	262	172	Eclipse of Fox	1966-09-24	0.15	36	Direct edition only; no newsstand version.
283	198	112	Reckoning of Stone	1959-11-11	2.99	32	Reprints classic story with new framing pages.
284	50	488	Shattered of Price	1953-12-01	0.12	80	Double-sized anniversary issue.
285	61	494	Fallen of Price	1980-02-03	0.10	48	Double-sized anniversary issue.
286	216	45	Resurgence of Crane	1979-03-25	0.75	64	Direct edition only; no newsstand version.
287	180	436	Fallen of Holt	1985-10-07	4.99	36	Landmark story milestone.
288	146	557	Legacy of Holt	2021-05-10	0.50	24	Key first appearance issue.
289	296	121	Resurgence of Morgan	2023-11-11	2.50	36	Part of a crossover event.
290	210	110	Fallen of Crane	1974-07-02	1.00	40	Double-sized anniversary issue.
291	217	375	Shattered of Holt	1993-08-29	2.50	36	Direct edition only; no newsstand version.
292	283	184	Inferno of Grant	1974-05-31	4.99	40	Low distribution; considered scarce.
293	296	793	Nemesis of Steele	2021-11-11	0.20	36	Contains bonus pin-up gallery.
294	83	220	Resurgence of Ward	2017-07-25	1.50	80	Reprints classic story with new framing pages.
295	27	399	Reckoning of Voss	1988-08-09	0.25	64	Reprints classic story with new framing pages.
296	223	66	Chaos of Vale	1962-12-24	1.95	28	Reprints classic story with new framing pages.
297	20	411	Shattered of Cole	1955-03-29	1.25	100	Key first appearance issue.
298	90	507	Fracture of Morgan	2005-09-21	0.50	80	Low distribution; considered scarce.
299	100	614	Resurgence of Cole	1985-10-03	0.75	100	Controversial issue banned in three states.
300	19	245	Reckoning of Cross	1980-01-25	0.15	40	Direct edition only; no newsstand version.
301	181	416	Reborn of Stone	1993-09-22	0.10	28	Landmark story milestone.
302	282	744	Descent of Hunt	1988-10-05	1.95	44	Low distribution; considered scarce.
303	116	200	Fracture of Ward	1959-10-20	0.10	40	Controversial issue banned in three states.
304	209	110	Descent of Voss	2011-06-02	1.25	44	Landmark story milestone.
305	263	551	Reborn of Holt	1988-02-14	3.99	48	Reprints classic story with new framing pages.
306	248	776	Eclipse of Fox	2012-09-23	3.99	100	Key first appearance issue.
307	247	265	Shadows of Ward	1960-03-19	0.75	36	Part of a crossover event.
308	212	529	Descent of Morgan	1975-09-05	1.00	36	Low distribution; considered scarce.
309	48	690	Eclipse of Voss	1991-11-24	0.35	64	Part of a crossover event.
310	182	588	Chaos of Cross	1972-08-10	0.50	64	High print run; common in collections.
311	121	272	Uprising of Vale	1999-11-10	0.50	36	Reprints classic story with new framing pages.
312	183	798	Rising of Kane	1946-07-01	0.15	64	Reprints classic story with new framing pages.
313	4	44	Oblivion of Nash	1974-07-09	1.50	64	Reprints classic story with new framing pages.
314	141	188	Resurgence of Holt	1992-01-07	2.50	36	Reprints classic story with new framing pages.
315	66	539	Legacy of Stark	1978-06-06	0.12	80	Part of a crossover event.
316	202	469	Rising of Cole	2017-12-24	3.99	44	Key first appearance issue.
317	7	389	Reborn of Kane	1957-09-23	1.50	44	Reprints classic story with new framing pages.
318	133	562	Chaos of Vale	2003-02-06	1.00	64	Reprints classic story with new framing pages.
319	176	189	Oblivion of Crane	2012-01-20	0.50	48	Part of a crossover event.
320	187	287	Fracture of Cross	1970-12-26	0.25	100	High print run; common in collections.
321	52	277	Revelation of Grant	2024-03-01	2.99	48	High print run; common in collections.
322	75	485	Reckoning of Cross	1977-09-16	2.99	64	Controversial issue banned in three states.
323	265	738	Eclipse of Stark	1991-11-27	1.25	40	Double-sized anniversary issue.
324	291	408	Rising of Cross	1955-02-21	0.12	36	Low distribution; considered scarce.
325	244	461	Eclipse of Holt	2001-04-27	1.95	44	Double-sized anniversary issue.
326	286	353	Reckoning of Crane	2016-10-12	0.20	44	Reprints classic story with new framing pages.
327	102	590	Descent of Cross	1971-06-21	1.25	44	Part of a crossover event.
328	262	794	Fracture of Voss	1986-09-26	2.50	100	Low distribution; considered scarce.
329	238	172	Eclipse of Crane	1950-08-17	2.50	28	Landmark story milestone.
330	83	234	Eclipse of Flynn	2018-12-05	1.25	40	Reprints classic story with new framing pages.
331	203	456	Inferno of Hunt	2006-03-03	3.99	48	Controversial issue banned in three states.
332	95	129	Revelation of Holt	1974-01-26	0.15	36	Controversial issue banned in three states.
333	204	98	Shadows of Stark	1987-04-24	0.12	24	Direct edition only; no newsstand version.
334	269	86	Rising of Holt	2013-02-26	0.25	28	Direct edition only; no newsstand version.
335	159	254	Vendetta of Fox	1961-02-21	0.25	32	Double-sized anniversary issue.
336	88	36	Inferno of Flynn	1998-08-23	4.99	64	Double-sized anniversary issue.
337	140	456	Fallen of Grant	1992-02-25	0.35	100	Reprints classic story with new framing pages.
338	234	767	Reborn of Crane	1993-07-16	1.25	44	Contains bonus pin-up gallery.
339	277	92	Fracture of Burns	1965-07-19	1.95	48	Low distribution; considered scarce.
340	80	11	Reckoning of Cole	2012-08-13	0.25	44	Low distribution; considered scarce.
341	241	9	Oblivion of Stark	2024-01-01	1.25	24	Direct edition only; no newsstand version.
342	150	237	Reckoning of Grant	2022-10-12	1.95	36	Direct edition only; no newsstand version.
343	288	405	Revelation of Cross	2009-08-10	2.50	48	High print run; common in collections.
344	135	433	Revelation of Cole	2017-11-21	1.00	40	Double-sized anniversary issue.
345	138	193	Shadows of Cross	1982-01-17	0.25	40	Landmark story milestone.
346	234	464	Chaos of Price	1993-06-19	4.99	36	Part of a crossover event.
347	10	51	Descent of Morgan	1989-10-28	0.35	28	Low distribution; considered scarce.
348	138	733	Fracture of Morgan	1956-03-21	0.75	28	Controversial issue banned in three states.
349	8	223	Eclipse of Crane	2022-01-26	1.25	64	Part of a crossover event.
350	238	339	Shadows of Steele	1949-05-10	0.12	40	Direct edition only; no newsstand version.
351	37	482	Convergence of Stone	1995-05-14	1.00	48	Key first appearance issue.
352	63	395	Fracture of Vale	2004-03-02	0.12	36	Contains bonus pin-up gallery.
353	49	682	Uprising of Stark	1993-05-18	2.50	40	Part of a crossover event.
354	82	746	Dawn of Grant	1997-06-12	0.20	40	Contains bonus pin-up gallery.
355	153	370	Dawn of Stone	1970-03-24	0.20	36	Direct edition only; no newsstand version.
356	167	172	Chaos of Hunt	2015-01-31	0.20	48	High print run; common in collections.
357	5	596	Oblivion of Price	1960-10-08	0.25	44	Landmark story milestone.
358	128	512	Shadows of Price	1980-01-28	1.50	24	Key first appearance issue.
359	183	158	Descent of Kane	1957-06-16	0.25	64	High print run; common in collections.
360	163	661	Inferno of Fox	1957-04-06	0.50	24	Direct edition only; no newsstand version.
361	184	257	Dawn of Stark	1987-02-01	3.99	80	Low distribution; considered scarce.
362	278	502	Uprising of Hunt	1979-08-20	0.35	80	Part of a crossover event.
363	166	282	Shattered of Grant	2021-01-08	0.35	28	Double-sized anniversary issue.
364	80	303	Chaos of Grant	2019-02-27	1.95	64	Key first appearance issue.
365	260	752	Convergence of Morgan	2010-01-02	1.95	100	High print run; common in collections.
366	165	675	Descent of Ward	1979-05-10	0.50	80	Contains bonus pin-up gallery.
367	283	628	Vendetta of Flynn	1970-09-24	2.99	44	Landmark story milestone.
368	50	675	Shadows of Drake	1984-12-09	0.25	32	Key first appearance issue.
369	104	498	Uprising of Kane	2008-05-26	0.12	100	Direct edition only; no newsstand version.
370	251	639	Reborn of Holt	1990-03-05	0.12	44	High print run; common in collections.
371	37	214	Oblivion of Voss	1971-08-03	3.99	24	Part of a crossover event.
372	286	378	Dawn of Price	2020-04-30	1.00	80	Key first appearance issue.
373	37	80	Uprising of Cole	1984-08-19	0.20	28	High print run; common in collections.
374	273	195	Uprising of Cole	1973-07-27	0.75	100	Controversial issue banned in three states.
375	286	765	Rising of Hunt	2020-04-24	1.95	64	Direct edition only; no newsstand version.
376	54	185	Descent of Ward	1997-06-26	1.50	32	Double-sized anniversary issue.
377	227	323	Descent of Flynn	1957-10-21	1.95	48	Direct edition only; no newsstand version.
378	166	577	Descent of Stone	2000-08-05	2.50	80	Low distribution; considered scarce.
379	185	459	Nemesis of Morgan	1998-01-28	0.12	40	Reprints classic story with new framing pages.
380	9	139	Vendetta of Morgan	1978-08-11	1.25	36	High print run; common in collections.
381	162	791	Chaos of Grant	1952-06-26	0.25	28	Key first appearance issue.
382	236	160	Fallen of Holt	1989-11-28	1.95	100	High print run; common in collections.
383	120	308	Shadows of Hunt	1987-10-01	2.50	100	High print run; common in collections.
384	40	495	Convergence of Stark	1946-10-27	0.20	100	Low distribution; considered scarce.
385	20	391	Shadows of Drake	1963-11-07	1.50	44	Direct edition only; no newsstand version.
386	214	789	Revelation of Price	1939-05-09	0.10	48	Key first appearance issue.
387	157	43	Eclipse of Grant	2021-06-20	0.25	44	Double-sized anniversary issue.
388	114	52	Nemesis of Fox	1966-06-08	0.15	36	Direct edition only; no newsstand version.
389	149	404	Fallen of Steele	2019-04-10	1.50	28	Contains bonus pin-up gallery.
390	293	562	Nemesis of Holt	2012-07-20	0.15	48	Double-sized anniversary issue.
391	223	781	Fallen of Stark	1963-12-05	0.50	64	Direct edition only; no newsstand version.
392	293	575	Shattered of Cole	2014-03-14	0.75	36	Landmark story milestone.
393	137	441	Eclipse of Hunt	1953-05-10	0.15	28	Direct edition only; no newsstand version.
394	217	357	Uprising of Flynn	1975-10-09	1.95	100	Key first appearance issue.
395	157	359	Shattered of Fox	2020-06-22	0.25	64	Key first appearance issue.
396	120	702	Inferno of Steele	1986-06-24	0.15	28	Key first appearance issue.
397	125	152	Vendetta of Morgan	1993-11-09	1.50	28	Low distribution; considered scarce.
398	231	24	Eclipse of Stone	1996-02-19	0.50	36	Double-sized anniversary issue.
399	268	562	Oblivion of Price	1990-11-25	0.25	24	Direct edition only; no newsstand version.
400	299	540	Dawn of Holt	1975-09-20	0.35	24	Low distribution; considered scarce.
401	103	714	Shattered of Holt	1958-11-07	0.12	64	Key first appearance issue.
402	35	677	Chaos of Nash	2009-03-06	0.20	24	Low distribution; considered scarce.
403	198	390	Resurgence of Kane	1968-09-26	1.50	64	Reprints classic story with new framing pages.
404	273	191	Uprising of Cole	1946-11-24	3.99	80	Key first appearance issue.
405	21	543	Vendetta of Flynn	2020-10-10	4.99	48	Controversial issue banned in three states.
406	10	701	Inferno of Nash	1998-07-22	1.25	36	Double-sized anniversary issue.
407	142	64	Chaos of Ward	2012-03-18	0.10	80	Low distribution; considered scarce.
408	116	350	Nemesis of Steele	1954-09-14	0.15	48	Double-sized anniversary issue.
409	117	247	Reborn of Steele	2018-09-06	2.99	40	Reprints classic story with new framing pages.
410	169	556	Fallen of Stone	2012-02-24	0.25	100	Double-sized anniversary issue.
411	104	317	Resurgence of Steele	2009-02-05	2.99	32	Reprints classic story with new framing pages.
412	81	70	Descent of Grant	2010-07-24	0.20	32	Part of a crossover event.
413	75	784	Eclipse of Crane	1972-04-28	2.99	40	Contains bonus pin-up gallery.
414	141	798	Uprising of Kane	1976-10-25	0.25	32	Key first appearance issue.
415	137	581	Shattered of Vale	1952-05-25	0.75	36	Key first appearance issue.
416	184	705	Oblivion of Steele	1982-02-17	4.99	44	Controversial issue banned in three states.
417	199	486	Fallen of Cross	1960-01-09	0.50	36	Key first appearance issue.
418	210	16	Chaos of Crane	2010-08-04	0.75	36	High print run; common in collections.
419	34	450	Shattered of Stark	1956-12-26	1.50	64	High print run; common in collections.
420	219	795	Dawn of Price	1999-04-28	2.50	44	Direct edition only; no newsstand version.
421	293	657	Dawn of Cole	2017-11-21	0.20	64	Contains bonus pin-up gallery.
422	22	532	Descent of Ward	1969-01-08	0.12	80	Direct edition only; no newsstand version.
423	265	646	Dawn of Stone	2012-08-23	1.25	64	Direct edition only; no newsstand version.
424	156	293	Fracture of Cross	2014-05-30	2.99	40	Reprints classic story with new framing pages.
425	28	530	Fallen of Fox	2011-12-14	3.99	28	Double-sized anniversary issue.
426	58	798	Reborn of Grant	1996-02-16	0.25	48	Direct edition only; no newsstand version.
427	166	26	Convergence of Fox	2019-06-14	0.50	64	Landmark story milestone.
428	129	709	Convergence of Kane	1988-07-15	0.15	28	Contains bonus pin-up gallery.
429	186	537	Nemesis of Cole	1991-10-29	0.35	48	Double-sized anniversary issue.
430	195	787	Convergence of Flynn	1977-12-09	0.25	32	Controversial issue banned in three states.
431	92	730	Dawn of Crane	2012-01-02	1.25	40	Contains bonus pin-up gallery.
432	148	186	Rising of Steele	2012-02-06	0.50	24	Reprints classic story with new framing pages.
433	130	470	Oblivion of Stark	2006-04-11	0.10	100	Contains bonus pin-up gallery.
434	122	603	Oblivion of Fox	1963-06-16	2.99	64	Landmark story milestone.
435	4	561	Chaos of Price	1973-09-08	0.50	24	Controversial issue banned in three states.
436	76	669	Inferno of Drake	1975-06-22	0.25	24	Reprints classic story with new framing pages.
437	153	90	Dawn of Kane	1971-09-18	2.99	32	Controversial issue banned in three states.
438	146	677	Shattered of Hunt	2021-06-05	0.35	64	Reprints classic story with new framing pages.
439	185	96	Vendetta of Flynn	1993-05-27	1.95	48	Landmark story milestone.
440	219	67	Vendetta of Stark	2012-05-20	0.25	28	Low distribution; considered scarce.
441	169	424	Resurgence of Stone	2015-08-23	0.50	100	Key first appearance issue.
442	56	748	Resurgence of Voss	1961-03-16	4.99	100	Low distribution; considered scarce.
443	219	325	Chaos of Cole	2017-08-15	1.95	32	Reprints classic story with new framing pages.
444	289	533	Oblivion of Stark	2001-02-18	0.35	100	High print run; common in collections.
445	149	2	Rising of Morgan	1992-09-06	3.99	28	High print run; common in collections.
446	213	47	Eclipse of Nash	2018-08-23	0.50	24	High print run; common in collections.
447	145	70	Vendetta of Burns	2017-11-08	1.50	24	Landmark story milestone.
448	171	406	Reborn of Price	2016-08-28	0.10	32	High print run; common in collections.
449	170	689	Oblivion of Stark	1950-11-24	0.12	32	Contains bonus pin-up gallery.
450	80	550	Eclipse of Fox	2019-08-30	2.99	24	Double-sized anniversary issue.
451	154	743	Eclipse of Grant	2016-05-05	0.10	36	Reprints classic story with new framing pages.
452	170	68	Fallen of Holt	1950-12-26	0.10	44	Direct edition only; no newsstand version.
453	274	170	Reborn of Price	2011-06-13	2.50	32	Reprints classic story with new framing pages.
454	60	770	Vendetta of Flynn	1969-09-11	0.12	40	Direct edition only; no newsstand version.
455	45	244	Inferno of Fox	2015-08-05	1.25	36	Double-sized anniversary issue.
456	155	115	Inferno of Drake	1995-12-18	0.50	28	Contains bonus pin-up gallery.
457	260	495	Resurgence of Steele	1978-03-28	0.50	44	Contains bonus pin-up gallery.
458	269	795	Eclipse of Steele	2002-12-17	0.20	80	Controversial issue banned in three states.
459	106	471	Nemesis of Cole	1999-05-30	0.20	24	Low distribution; considered scarce.
460	23	609	Shadows of Flynn	2001-08-21	3.99	24	Landmark story milestone.
461	267	675	Vendetta of Morgan	1957-08-05	1.25	36	Part of a crossover event.
462	103	294	Chaos of Grant	1952-02-28	1.50	64	Landmark story milestone.
463	140	162	Chaos of Kane	1987-09-04	0.10	100	Double-sized anniversary issue.
464	264	212	Descent of Nash	2015-04-19	1.50	40	Controversial issue banned in three states.
465	146	251	Convergence of Voss	2021-03-21	1.25	100	Part of a crossover event.
466	277	52	Fallen of Morgan	1967-12-23	4.99	24	Landmark story milestone.
467	197	89	Legacy of Ward	1948-08-08	0.35	100	Reprints classic story with new framing pages.
468	229	365	Vendetta of Flynn	1987-10-28	0.50	80	Landmark story milestone.
469	239	135	Shadows of Fox	2021-05-14	0.20	64	Low distribution; considered scarce.
470	239	238	Revelation of Steele	2020-04-11	1.00	44	Direct edition only; no newsstand version.
471	94	682	Eclipse of Flynn	2011-11-05	3.99	64	Key first appearance issue.
472	34	116	Inferno of Stark	1960-04-30	3.99	32	Low distribution; considered scarce.
473	179	589	Fallen of Cole	2018-02-11	0.20	48	Landmark story milestone.
474	167	310	Descent of Fox	2015-05-26	2.50	100	Direct edition only; no newsstand version.
475	123	250	Descent of Cross	2019-09-13	4.99	48	Landmark story milestone.
476	175	711	Reborn of Crane	1974-05-02	2.99	100	Part of a crossover event.
477	279	242	Convergence of Voss	1969-07-27	4.99	28	Reprints classic story with new framing pages.
478	238	569	Rising of Fox	1952-08-25	0.35	40	Direct edition only; no newsstand version.
479	36	112	Shattered of Ward	1991-11-02	1.50	64	Key first appearance issue.
480	47	143	Reborn of Morgan	1977-03-21	0.25	32	Contains bonus pin-up gallery.
481	273	400	Shattered of Hunt	1965-02-24	3.99	36	High print run; common in collections.
482	163	584	Vendetta of Crane	1954-05-12	1.95	28	Reprints classic story with new framing pages.
483	5	523	Nemesis of Steele	2011-11-11	1.25	24	Part of a crossover event.
484	282	1	Descent of Nash	1978-05-20	0.20	40	Key first appearance issue.
485	121	720	Reborn of Ward	2008-05-14	1.50	48	Direct edition only; no newsstand version.
486	196	559	Uprising of Cross	1959-10-06	4.99	32	High print run; common in collections.
487	285	369	Legacy of Steele	1982-04-03	1.25	32	Controversial issue banned in three states.
488	6	664	Reckoning of Steele	1984-08-10	4.99	48	Controversial issue banned in three states.
489	44	658	Legacy of Fox	1959-04-24	2.99	100	Controversial issue banned in three states.
490	233	435	Descent of Fox	2018-11-09	2.50	44	High print run; common in collections.
491	96	620	Reckoning of Hunt	2016-01-21	4.99	36	Double-sized anniversary issue.
492	138	560	Reborn of Nash	1981-11-10	0.12	24	Reprints classic story with new framing pages.
493	248	116	Reborn of Stark	2014-02-18	0.15	32	Double-sized anniversary issue.
494	144	530	Shadows of Cole	1960-11-08	0.15	36	Contains bonus pin-up gallery.
495	40	649	Descent of Hunt	1948-11-01	1.25	100	Key first appearance issue.
496	176	798	Reckoning of Stark	2012-12-31	3.99	80	Contains bonus pin-up gallery.
497	294	340	Legacy of Nash	2018-03-25	1.25	40	Controversial issue banned in three states.
498	19	745	Reborn of Holt	1978-10-26	0.12	64	Reprints classic story with new framing pages.
499	87	53	Vendetta of Price	2020-05-24	0.10	40	Contains bonus pin-up gallery.
500	43	518	Shadows of Holt	1979-05-18	1.00	32	Reprints classic story with new framing pages.
501	144	264	Reckoning of Kane	1952-05-06	0.35	100	Controversial issue banned in three states.
502	229	180	Chaos of Vale	1982-04-18	4.99	32	Double-sized anniversary issue.
503	17	87	Fallen of Price	1972-05-19	0.25	64	Direct edition only; no newsstand version.
504	197	677	Fracture of Cross	1950-09-01	0.50	100	Part of a crossover event.
505	28	271	Rising of Drake	2009-10-23	0.35	64	Direct edition only; no newsstand version.
506	244	488	Descent of Vale	2010-07-09	2.50	48	Contains bonus pin-up gallery.
507	135	544	Legacy of Morgan	2018-08-18	1.25	64	Direct edition only; no newsstand version.
508	162	700	Dawn of Kane	1963-11-22	1.95	48	Reprints classic story with new framing pages.
509	140	277	Chaos of Kane	1989-10-04	1.00	100	Direct edition only; no newsstand version.
510	237	768	Revelation of Hunt	2022-10-14	0.50	80	Part of a crossover event.
511	93	561	Reckoning of Morgan	2021-10-03	0.15	24	Direct edition only; no newsstand version.
512	51	107	Fracture of Nash	2020-10-12	0.75	40	Low distribution; considered scarce.
513	99	25	Shattered of Voss	1952-01-21	0.12	100	High print run; common in collections.
514	63	123	Shadows of Price	2024-10-06	0.25	48	Reprints classic story with new framing pages.
515	95	713	Convergence of Holt	1981-12-11	1.25	64	Landmark story milestone.
516	233	788	Legacy of Flynn	2017-07-20	1.00	32	Landmark story milestone.
517	142	64	Nemesis of Ward	2011-06-07	1.50	24	Low distribution; considered scarce.
518	136	452	Shadows of Stark	2018-12-31	0.50	100	Direct edition only; no newsstand version.
519	92	504	Rising of Steele	2000-11-28	2.99	36	Reprints classic story with new framing pages.
520	55	453	Chaos of Kane	2022-11-16	0.12	28	Landmark story milestone.
521	293	796	Fracture of Morgan	2014-10-23	4.99	32	Key first appearance issue.
522	20	400	Chaos of Steele	1967-10-24	1.50	48	Reprints classic story with new framing pages.
523	2	725	Oblivion of Stark	2014-06-12	2.99	48	Landmark story milestone.
524	277	4	Nemesis of Stark	1965-07-14	0.20	100	Double-sized anniversary issue.
525	184	699	Vendetta of Ward	2004-11-30	0.12	28	Part of a crossover event.
526	274	349	Shadows of Fox	2011-07-28	1.25	36	Controversial issue banned in three states.
527	284	394	Uprising of Burns	2016-02-10	2.50	28	Part of a crossover event.
528	250	648	Fracture of Stone	1984-12-13	0.25	24	High print run; common in collections.
529	13	501	Nemesis of Voss	1993-05-24	1.25	64	Double-sized anniversary issue.
530	231	38	Eclipse of Drake	1975-09-26	1.50	24	Direct edition only; no newsstand version.
531	61	670	Resurgence of Fox	1982-10-01	0.25	100	High print run; common in collections.
532	37	754	Fallen of Stark	1972-08-27	0.10	64	Reprints classic story with new framing pages.
533	24	719	Fallen of Morgan	1969-05-12	0.35	24	Low distribution; considered scarce.
534	50	626	Convergence of Hunt	1978-12-05	0.15	28	Landmark story milestone.
535	255	631	Revelation of Voss	1950-09-03	0.50	48	Part of a crossover event.
536	206	124	Reborn of Grant	1986-10-27	0.25	44	High print run; common in collections.
537	24	178	Eclipse of Voss	1971-04-29	0.20	40	Controversial issue banned in three states.
538	213	714	Inferno of Grant	2015-11-20	0.35	64	High print run; common in collections.
539	298	137	Rising of Price	1950-06-16	2.50	32	Key first appearance issue.
540	250	7	Reckoning of Cross	1984-11-26	0.15	100	Low distribution; considered scarce.
541	214	792	Oblivion of Steele	1945-10-11	0.50	32	Low distribution; considered scarce.
542	268	422	Revelation of Cross	1993-01-18	0.12	100	Controversial issue banned in three states.
543	256	91	Vendetta of Nash	2016-11-28	2.99	24	Double-sized anniversary issue.
544	121	121	Resurgence of Kane	1997-08-11	1.95	80	Double-sized anniversary issue.
545	113	789	Uprising of Holt	1983-08-25	0.12	36	Landmark story milestone.
546	77	486	Oblivion of Cross	2022-05-15	0.35	24	Key first appearance issue.
547	187	215	Legacy of Holt	1968-05-24	1.50	100	Contains bonus pin-up gallery.
548	23	759	Dawn of Grant	1949-05-14	0.35	32	Key first appearance issue.
549	249	119	Shadows of Vale	2021-10-10	3.99	100	Reprints classic story with new framing pages.
550	167	204	Eclipse of Vale	2017-05-08	0.20	44	High print run; common in collections.
551	51	756	Legacy of Stone	2014-04-27	2.50	36	Landmark story milestone.
552	242	497	Dawn of Crane	2022-03-31	0.25	36	Reprints classic story with new framing pages.
553	233	397	Inferno of Steele	2016-12-30	3.99	36	Part of a crossover event.
554	139	344	Fallen of Drake	1999-01-27	0.12	40	Controversial issue banned in three states.
555	57	470	Legacy of Cross	2016-11-18	1.50	36	Low distribution; considered scarce.
556	81	654	Shattered of Cross	2015-11-08	0.75	28	Direct edition only; no newsstand version.
557	268	222	Reborn of Stark	1993-06-26	3.99	40	Key first appearance issue.
558	220	253	Revelation of Flynn	2004-07-05	2.99	100	High print run; common in collections.
559	77	6	Legacy of Drake	2019-11-13	0.12	64	Double-sized anniversary issue.
560	18	544	Nemesis of Stark	2018-10-10	0.20	64	Contains bonus pin-up gallery.
561	124	572	Reckoning of Crane	1942-11-12	0.50	32	Part of a crossover event.
562	152	664	Shadows of Morgan	1976-06-12	4.99	40	Controversial issue banned in three states.
563	236	766	Reborn of Morgan	2009-03-04	3.99	64	Controversial issue banned in three states.
564	208	380	Fracture of Morgan	1960-08-04	0.15	48	Part of a crossover event.
565	272	304	Legacy of Holt	1988-06-19	0.50	28	Reprints classic story with new framing pages.
566	172	528	Inferno of Drake	1975-03-26	0.20	48	Part of a crossover event.
567	239	42	Inferno of Nash	2021-12-10	0.35	80	Landmark story milestone.
568	288	793	Uprising of Steele	2021-10-26	1.50	36	Double-sized anniversary issue.
569	59	756	Reborn of Stone	2010-06-19	0.75	44	Part of a crossover event.
570	137	697	Legacy of Holt	1951-10-29	0.12	28	Part of a crossover event.
571	177	498	Resurgence of Cole	2005-04-18	0.20	64	Double-sized anniversary issue.
572	273	300	Fracture of Price	2019-09-11	1.95	28	High print run; common in collections.
573	235	83	Nemesis of Cross	2005-12-16	1.25	28	Landmark story milestone.
574	85	115	Fallen of Stark	2008-05-18	0.25	36	Double-sized anniversary issue.
575	12	427	Descent of Steele	1992-02-25	4.99	44	Direct edition only; no newsstand version.
576	228	661	Reckoning of Burns	2021-02-02	0.50	28	Key first appearance issue.
577	119	661	Eclipse of Crane	2009-08-27	1.50	44	Contains bonus pin-up gallery.
578	272	562	Fracture of Fox	2024-10-06	1.25	100	Controversial issue banned in three states.
579	157	267	Revelation of Stark	2020-06-24	1.95	40	Key first appearance issue.
580	76	292	Fracture of Cross	1988-11-03	0.35	80	Low distribution; considered scarce.
581	94	726	Fallen of Cross	2005-12-19	0.75	28	Key first appearance issue.
582	163	130	Fracture of Holt	1957-06-11	1.95	32	High print run; common in collections.
583	288	36	Eclipse of Nash	2021-09-20	0.25	44	Contains bonus pin-up gallery.
584	277	547	Vendetta of Kane	1964-10-27	0.10	48	Contains bonus pin-up gallery.
585	75	328	Fallen of Morgan	1991-07-19	1.50	40	Contains bonus pin-up gallery.
586	149	588	Fallen of Hunt	2017-10-30	3.99	44	Landmark story milestone.
587	246	42	Fallen of Grant	2023-05-19	0.20	40	Key first appearance issue.
588	206	226	Fracture of Nash	1988-06-18	0.15	44	Key first appearance issue.
589	100	540	Revelation of Holt	1998-02-01	0.50	24	Landmark story milestone.
590	276	457	Shadows of Cole	1988-01-20	2.50	36	Contains bonus pin-up gallery.
591	163	620	Resurgence of Drake	1957-10-06	1.95	48	Controversial issue banned in three states.
592	219	396	Inferno of Morgan	1996-02-29	1.25	44	Part of a crossover event.
593	158	575	Shadows of Stone	1955-12-30	3.99	48	Contains bonus pin-up gallery.
594	148	746	Legacy of Crane	1991-05-07	0.25	100	Reprints classic story with new framing pages.
595	45	213	Vendetta of Stark	1983-11-20	1.50	28	Reprints classic story with new framing pages.
596	193	7	Legacy of Holt	2005-12-20	2.99	32	Double-sized anniversary issue.
597	237	582	Fallen of Stone	2022-12-25	0.35	48	Low distribution; considered scarce.
598	284	44	Vendetta of Hunt	2017-05-17	1.25	64	Double-sized anniversary issue.
599	238	28	Reckoning of Steele	1951-07-09	1.00	40	Contains bonus pin-up gallery.
600	64	428	Convergence of Stark	2014-11-27	0.75	24	Landmark story milestone.
601	142	69	Shattered of Nash	2005-01-22	4.99	100	Direct edition only; no newsstand version.
602	133	711	Rising of Nash	2006-05-04	0.10	40	Controversial issue banned in three states.
603	298	150	Eclipse of Fox	1950-08-28	0.25	44	Controversial issue banned in three states.
604	28	370	Legacy of Nash	1993-03-26	0.12	40	Low distribution; considered scarce.
605	272	79	Resurgence of Stone	2015-08-30	0.35	28	Reprints classic story with new framing pages.
606	86	331	Eclipse of Burns	2022-05-23	1.00	44	Landmark story milestone.
607	274	361	Fallen of Morgan	2008-07-03	0.25	80	Low distribution; considered scarce.
608	191	422	Eclipse of Cross	2023-10-02	0.20	36	Controversial issue banned in three states.
609	258	193	Descent of Price	1983-12-17	0.20	48	Contains bonus pin-up gallery.
610	40	135	Reckoning of Stark	1945-08-27	1.95	40	Part of a crossover event.
611	72	612	Resurgence of Flynn	1979-10-28	0.35	40	Key first appearance issue.
612	61	132	Fallen of Vale	1982-12-27	1.25	32	High print run; common in collections.
613	67	436	Rising of Voss	2012-11-17	0.10	64	Direct edition only; no newsstand version.
614	22	111	Dawn of Cole	1966-10-23	0.12	64	Landmark story milestone.
615	130	68	Vendetta of Morgan	2006-12-21	0.20	28	Reprints classic story with new framing pages.
616	106	205	Convergence of Nash	2005-08-03	0.10	28	Controversial issue banned in three states.
617	143	357	Inferno of Cross	1990-04-02	0.75	80	Reprints classic story with new framing pages.
618	35	593	Reckoning of Cole	2007-07-22	0.50	36	Low distribution; considered scarce.
619	88	551	Reckoning of Kane	2014-11-29	0.50	80	Contains bonus pin-up gallery.
620	188	604	Convergence of Fox	2018-08-19	0.20	32	Part of a crossover event.
621	195	220	Resurgence of Vale	2012-01-18	2.99	28	Part of a crossover event.
622	64	113	Resurgence of Steele	2022-11-25	4.99	44	Low distribution; considered scarce.
623	286	85	Eclipse of Stark	2011-11-29	0.20	48	Low distribution; considered scarce.
624	234	754	Vendetta of Fox	1993-05-14	0.75	80	Direct edition only; no newsstand version.
625	149	439	Uprising of Voss	2022-05-15	4.99	44	Controversial issue banned in three states.
626	7	689	Rising of Ward	1964-01-11	3.99	80	Landmark story milestone.
627	62	405	Nemesis of Hunt	1943-05-27	0.20	32	Landmark story milestone.
628	187	347	Uprising of Price	1966-06-19	2.50	28	High print run; common in collections.
629	218	286	Reborn of Hunt	2023-08-07	1.00	48	Part of a crossover event.
630	244	415	Oblivion of Cole	2024-01-22	1.00	32	Contains bonus pin-up gallery.
631	56	257	Oblivion of Stark	1958-09-08	0.75	32	Key first appearance issue.
632	51	70	Oblivion of Morgan	2010-03-09	0.35	48	Reprints classic story with new framing pages.
633	168	311	Shattered of Price	1973-11-07	0.20	28	Double-sized anniversary issue.
634	253	478	Uprising of Burns	1993-10-12	4.99	64	Double-sized anniversary issue.
635	134	352	Descent of Grant	2020-05-01	0.10	24	Direct edition only; no newsstand version.
636	61	461	Eclipse of Ward	1986-08-09	3.99	64	Key first appearance issue.
637	17	571	Vendetta of Cross	1964-12-07	4.99	48	Controversial issue banned in three states.
638	160	500	Rising of Hunt	1953-02-02	4.99	80	Double-sized anniversary issue.
639	293	488	Descent of Cross	2017-04-08	0.12	48	Low distribution; considered scarce.
640	254	387	Shattered of Nash	2011-07-07	1.25	44	Key first appearance issue.
641	15	132	Inferno of Nash	2010-01-05	0.10	44	Direct edition only; no newsstand version.
642	50	354	Inferno of Crane	1976-05-30	1.95	24	High print run; common in collections.
643	127	664	Vendetta of Hunt	2013-04-06	0.15	28	Low distribution; considered scarce.
644	59	174	Reckoning of Grant	2004-02-23	1.50	24	Contains bonus pin-up gallery.
645	217	528	Legacy of Holt	1993-12-17	0.10	64	Reprints classic story with new framing pages.
646	12	387	Reborn of Ward	1993-03-13	1.50	100	Landmark story milestone.
647	251	708	Uprising of Flynn	1951-12-23	4.99	80	Part of a crossover event.
648	86	373	Legacy of Stone	2011-06-09	4.99	28	Double-sized anniversary issue.
649	110	272	Dawn of Burns	2016-03-23	2.50	36	Reprints classic story with new framing pages.
650	48	607	Eclipse of Holt	1978-04-02	0.15	100	Double-sized anniversary issue.
651	244	215	Inferno of Voss	2016-02-28	1.25	80	Low distribution; considered scarce.
652	222	553	Eclipse of Stone	2018-10-06	2.99	48	Low distribution; considered scarce.
653	264	688	Descent of Cross	2023-03-02	0.10	80	Controversial issue banned in three states.
654	296	219	Fracture of Holt	2023-08-07	2.99	100	Key first appearance issue.
655	268	374	Fracture of Steele	1990-04-01	0.75	32	Low distribution; considered scarce.
656	223	327	Shadows of Stone	1970-03-15	2.99	40	Low distribution; considered scarce.
657	83	704	Shattered of Vale	2018-06-10	2.50	36	Landmark story milestone.
658	77	29	Revelation of Burns	2011-04-22	3.99	64	Double-sized anniversary issue.
659	224	663	Dawn of Stone	2010-12-06	0.35	40	Controversial issue banned in three states.
660	15	285	Descent of Cross	2014-10-18	0.12	64	Key first appearance issue.
661	29	322	Shattered of Burns	1947-06-21	0.15	48	Part of a crossover event.
662	47	742	Fallen of Vale	1978-03-23	0.20	100	Double-sized anniversary issue.
663	62	681	Reborn of Cole	1944-06-18	1.00	64	Landmark story milestone.
664	122	126	Eclipse of Flynn	1997-10-23	2.50	36	Direct edition only; no newsstand version.
665	112	110	Convergence of Stone	1959-12-11	1.00	64	Direct edition only; no newsstand version.
666	131	503	Descent of Nash	1981-07-05	0.20	44	Double-sized anniversary issue.
667	217	700	Revelation of Holt	1985-08-08	0.25	44	Contains bonus pin-up gallery.
668	189	22	Shattered of Drake	2021-06-16	0.12	36	Low distribution; considered scarce.
669	283	317	Inferno of Kane	1973-04-25	0.75	64	Direct edition only; no newsstand version.
670	5	262	Vendetta of Voss	1992-04-04	0.75	40	High print run; common in collections.
671	83	647	Eclipse of Crane	2019-06-18	0.12	40	Landmark story milestone.
672	252	755	Legacy of Flynn	1967-07-27	2.99	28	Controversial issue banned in three states.
673	134	68	Inferno of Crane	2018-09-17	1.50	64	Key first appearance issue.
674	27	657	Convergence of Fox	1999-05-22	0.25	24	Direct edition only; no newsstand version.
675	103	313	Eclipse of Hunt	1957-01-17	0.15	28	Controversial issue banned in three states.
676	128	731	Fallen of Price	1996-03-01	2.99	44	Contains bonus pin-up gallery.
677	245	267	Convergence of Hunt	1984-12-27	1.50	40	High print run; common in collections.
678	44	377	Convergence of Ward	1984-03-09	2.50	100	High print run; common in collections.
679	11	572	Shattered of Vale	2006-04-05	0.15	64	High print run; common in collections.
680	135	51	Nemesis of Price	2018-11-23	2.99	100	Low distribution; considered scarce.
681	77	377	Convergence of Hunt	2008-12-30	0.20	24	Double-sized anniversary issue.
682	223	690	Oblivion of Kane	1971-03-06	0.75	36	High print run; common in collections.
683	137	765	Oblivion of Ward	1950-08-13	0.25	48	High print run; common in collections.
684	111	290	Uprising of Crane	1973-03-29	0.35	48	Controversial issue banned in three states.
685	15	269	Revelation of Price	2015-07-06	3.99	36	Part of a crossover event.
686	299	663	Fracture of Voss	1975-11-02	0.10	64	Controversial issue banned in three states.
687	166	704	Uprising of Ward	2014-09-01	2.99	100	Low distribution; considered scarce.
688	38	571	Dawn of Drake	1965-07-20	1.50	36	Contains bonus pin-up gallery.
689	182	687	Shattered of Drake	2007-05-27	0.10	40	Double-sized anniversary issue.
690	196	405	Inferno of Steele	1956-10-14	0.12	100	Controversial issue banned in three states.
691	134	516	Oblivion of Flynn	2003-08-15	3.99	32	Landmark story milestone.
692	163	544	Legacy of Steele	1958-12-19	1.00	28	Part of a crossover event.
693	23	512	Chaos of Nash	1951-06-22	2.99	40	Low distribution; considered scarce.
694	136	321	Legacy of Cross	2020-11-24	1.50	64	Controversial issue banned in three states.
695	285	55	Uprising of Steele	1984-09-26	0.12	36	Controversial issue banned in three states.
696	19	267	Convergence of Fox	1982-07-19	2.99	28	Contains bonus pin-up gallery.
697	21	366	Descent of Stark	2022-12-14	3.99	64	Landmark story milestone.
698	76	358	Shadows of Stone	1978-07-19	1.25	32	Controversial issue banned in three states.
699	261	280	Reborn of Hunt	1971-06-14	0.50	100	Key first appearance issue.
700	270	185	Legacy of Voss	2000-08-08	0.75	64	Landmark story milestone.
701	169	292	Rising of Ward	1993-03-01	1.95	100	Landmark story milestone.
702	166	30	Shadows of Fox	1992-10-17	4.99	64	Low distribution; considered scarce.
703	3	45	Shattered of Fox	1955-10-12	1.50	100	Controversial issue banned in three states.
704	109	660	Vendetta of Flynn	2017-07-19	0.12	28	Double-sized anniversary issue.
705	196	409	Chaos of Cross	1952-01-29	0.75	48	Landmark story milestone.
706	11	167	Nemesis of Ward	2008-05-02	1.25	32	Landmark story milestone.
707	153	443	Vendetta of Price	1973-07-03	0.25	44	Landmark story milestone.
708	189	205	Oblivion of Fox	2023-10-01	2.50	64	Low distribution; considered scarce.
709	289	434	Shadows of Crane	2003-06-19	1.95	100	Controversial issue banned in three states.
710	223	96	Dawn of Cole	1970-07-22	1.50	64	High print run; common in collections.
711	80	540	Resurgence of Voss	2021-03-21	1.25	64	Direct edition only; no newsstand version.
712	41	490	Vendetta of Steele	2024-12-15	0.25	40	High print run; common in collections.
713	268	303	Reborn of Drake	1992-10-17	0.15	24	Double-sized anniversary issue.
714	56	436	Legacy of Kane	1960-11-11	3.99	100	Low distribution; considered scarce.
715	182	600	Shadows of Cole	1975-11-13	0.10	28	Contains bonus pin-up gallery.
716	92	187	Nemesis of Drake	2013-07-13	0.15	48	Low distribution; considered scarce.
717	161	776	Fracture of Price	2019-10-27	1.00	44	Controversial issue banned in three states.
718	109	81	Shattered of Holt	2019-01-29	0.20	48	Double-sized anniversary issue.
719	10	405	Rising of Morgan	1983-04-06	0.35	64	Contains bonus pin-up gallery.
720	208	674	Shattered of Stark	2021-12-10	1.25	100	Reprints classic story with new framing pages.
721	185	690	Nemesis of Burns	2000-09-29	0.15	32	Controversial issue banned in three states.
722	8	115	Reckoning of Stone	2015-04-13	0.10	36	Contains bonus pin-up gallery.
723	75	447	Descent of Stone	1981-11-05	0.15	40	Contains bonus pin-up gallery.
724	76	433	Reckoning of Kane	1994-04-06	0.35	32	Contains bonus pin-up gallery.
725	249	21	Fracture of Hunt	2021-04-15	0.75	36	Low distribution; considered scarce.
726	292	53	Eclipse of Morgan	2007-07-29	0.20	48	Direct edition only; no newsstand version.
727	254	593	Shattered of Grant	2018-01-24	1.25	24	Contains bonus pin-up gallery.
728	205	526	Reborn of Price	2010-06-15	4.99	36	Key first appearance issue.
729	271	433	Reborn of Flynn	1949-02-08	0.15	40	Direct edition only; no newsstand version.
730	243	507	Shattered of Nash	1983-08-16	3.99	48	Key first appearance issue.
731	83	744	Uprising of Stark	2018-08-13	1.95	64	High print run; common in collections.
732	260	602	Eclipse of Price	1995-09-17	3.99	32	Low distribution; considered scarce.
733	200	690	Inferno of Stark	1992-05-25	0.35	100	High print run; common in collections.
734	145	684	Oblivion of Steele	2015-12-20	0.35	36	Controversial issue banned in three states.
735	252	426	Oblivion of Burns	1959-04-07	0.75	36	Double-sized anniversary issue.
736	25	368	Chaos of Nash	1955-08-18	0.35	32	Double-sized anniversary issue.
737	17	346	Legacy of Kane	1959-11-10	0.75	28	Double-sized anniversary issue.
738	115	265	Eclipse of Nash	1990-08-20	0.12	80	Low distribution; considered scarce.
739	78	619	Rising of Drake	1957-07-24	3.99	64	Landmark story milestone.
740	55	626	Shattered of Kane	2011-02-16	0.12	80	Landmark story milestone.
741	86	211	Inferno of Cross	2003-04-19	1.25	64	Double-sized anniversary issue.
742	256	158	Inferno of Flynn	1970-11-28	0.25	28	High print run; common in collections.
743	225	788	Reckoning of Vale	1991-08-26	4.99	44	Low distribution; considered scarce.
744	259	88	Chaos of Nash	2010-11-03	2.99	44	High print run; common in collections.
745	78	432	Revelation of Steele	1957-11-17	2.99	48	Direct edition only; no newsstand version.
746	235	529	Inferno of Morgan	2023-02-12	3.99	32	Key first appearance issue.
747	265	87	Eclipse of Flynn	1950-03-30	2.50	32	Direct edition only; no newsstand version.
748	32	778	Dawn of Steele	1958-10-27	0.12	80	Low distribution; considered scarce.
749	215	698	Descent of Burns	1989-04-03	1.50	44	Key first appearance issue.
750	144	718	Nemesis of Fox	1946-08-03	0.50	80	Reprints classic story with new framing pages.
751	227	665	Nemesis of Stone	1957-06-27	1.25	28	Key first appearance issue.
752	276	400	Fallen of Cole	1976-07-03	1.25	36	Landmark story milestone.
753	262	320	Resurgence of Flynn	1992-07-02	0.35	24	Key first appearance issue.
754	277	248	Vendetta of Crane	1965-11-25	0.20	24	Part of a crossover event.
755	133	363	Rising of Drake	2006-09-10	0.20	64	Low distribution; considered scarce.
756	294	6	Fracture of Flynn	2018-04-07	0.75	100	Reprints classic story with new framing pages.
757	274	610	Revelation of Nash	2011-06-22	1.25	40	Reprints classic story with new framing pages.
758	72	533	Revelation of Kane	1976-12-09	1.50	80	Reprints classic story with new framing pages.
759	99	798	Inferno of Fox	2022-10-27	0.20	32	Direct edition only; no newsstand version.
760	211	95	Dawn of Crane	1955-05-09	0.25	64	High print run; common in collections.
761	229	379	Resurgence of Ward	1975-10-02	2.50	40	Reprints classic story with new framing pages.
762	256	434	Fracture of Stark	2019-02-06	2.99	32	Controversial issue banned in three states.
763	259	497	Fracture of Steele	2009-11-07	0.20	36	Contains bonus pin-up gallery.
764	243	765	Convergence of Grant	1981-09-25	1.95	28	Reprints classic story with new framing pages.
765	210	124	Inferno of Hunt	1951-11-25	1.25	24	Double-sized anniversary issue.
766	79	381	Vendetta of Nash	1996-04-13	1.25	40	Contains bonus pin-up gallery.
767	15	146	Reborn of Crane	2012-03-16	0.12	40	Low distribution; considered scarce.
768	111	758	Oblivion of Morgan	1966-01-19	0.20	80	Part of a crossover event.
769	35	428	Oblivion of Hunt	2007-04-02	1.25	100	Contains bonus pin-up gallery.
770	173	487	Shattered of Steele	2015-12-04	0.25	80	Contains bonus pin-up gallery.
771	231	153	Eclipse of Voss	1995-02-22	2.99	48	High print run; common in collections.
772	203	554	Dawn of Fox	2009-03-17	1.00	28	Controversial issue banned in three states.
773	13	646	Vendetta of Grant	2023-04-26	0.20	80	Landmark story milestone.
774	99	555	Reborn of Drake	2004-07-04	0.50	64	Double-sized anniversary issue.
775	10	675	Descent of Cross	1988-05-24	0.10	40	High print run; common in collections.
776	126	723	Reborn of Fox	1984-04-21	0.15	80	Reprints classic story with new framing pages.
777	165	604	Dawn of Stark	1981-04-02	0.10	44	Direct edition only; no newsstand version.
778	93	25	Resurgence of Flynn	2022-04-29	2.50	40	Landmark story milestone.
779	59	555	Convergence of Burns	1993-06-16	0.25	32	Low distribution; considered scarce.
780	46	315	Legacy of Cross	1961-06-17	0.12	100	Part of a crossover event.
781	93	731	Dawn of Burns	2020-02-25	2.50	28	Part of a crossover event.
782	73	332	Chaos of Ward	1973-07-08	0.20	24	High print run; common in collections.
783	123	601	Revelation of Stark	2017-07-23	2.50	28	Low distribution; considered scarce.
784	32	476	Descent of Crane	1957-02-20	0.15	64	Key first appearance issue.
785	209	240	Reckoning of Holt	2022-11-02	0.20	36	Double-sized anniversary issue.
786	65	582	Legacy of Fox	1981-04-30	0.15	80	High print run; common in collections.
787	73	554	Convergence of Vale	1971-09-30	2.99	80	Contains bonus pin-up gallery.
788	22	476	Shattered of Burns	1958-01-17	0.35	24	Key first appearance issue.
789	247	613	Chaos of Ward	1967-04-05	1.95	36	Reprints classic story with new framing pages.
790	262	47	Convergence of Grant	1968-03-28	0.15	40	Landmark story milestone.
791	203	144	Descent of Holt	1999-07-08	2.99	36	Reprints classic story with new framing pages.
792	259	326	Eclipse of Holt	2024-12-27	3.99	40	High print run; common in collections.
793	165	216	Fracture of Price	1980-11-30	1.50	24	Controversial issue banned in three states.
794	2	488	Reckoning of Morgan	2014-09-16	0.35	48	Double-sized anniversary issue.
795	251	403	Descent of Voss	2011-05-28	0.15	80	Key first appearance issue.
796	228	127	Inferno of Ward	2018-02-26	1.95	48	Controversial issue banned in three states.
797	5	474	Inferno of Stone	1968-03-12	3.99	24	High print run; common in collections.
798	11	697	Inferno of Stone	2009-02-25	0.15	100	Low distribution; considered scarce.
799	114	506	Inferno of Drake	1968-04-03	1.00	64	Reprints classic story with new framing pages.
800	108	201	Nemesis of Kane	1948-01-15	1.00	100	Double-sized anniversary issue.
801	253	566	Uprising of Hunt	1979-10-28	0.35	28	Reprints classic story with new framing pages.
802	66	131	Chaos of Hunt	1978-12-01	0.75	80	Low distribution; considered scarce.
803	99	24	Descent of Price	2009-10-29	1.00	80	Contains bonus pin-up gallery.
804	2	657	Dawn of Flynn	2014-03-14	2.99	48	Low distribution; considered scarce.
805	63	531	Fracture of Stark	2023-07-06	1.95	80	Key first appearance issue.
806	115	285	Legacy of Grant	1951-03-19	3.99	44	Key first appearance issue.
807	201	343	Shadows of Hunt	2009-05-14	0.10	36	Direct edition only; no newsstand version.
808	39	202	Convergence of Flynn	2000-06-05	1.25	28	Landmark story milestone.
809	15	443	Reckoning of Hunt	2019-10-07	1.50	40	High print run; common in collections.
810	56	245	Eclipse of Drake	1960-08-27	1.50	80	High print run; common in collections.
811	38	635	Fracture of Kane	2010-10-29	3.99	100	Landmark story milestone.
812	44	35	Nemesis of Flynn	1952-06-11	0.15	32	Key first appearance issue.
813	227	309	Shattered of Crane	1944-06-16	0.15	28	Key first appearance issue.
814	287	302	Nemesis of Ward	1946-03-04	0.20	100	Direct edition only; no newsstand version.
815	120	465	Nemesis of Fox	1982-03-28	2.99	100	Reprints classic story with new framing pages.
816	52	667	Reckoning of Fox	2015-08-14	1.50	100	High print run; common in collections.
817	56	13	Shattered of Voss	1958-07-30	0.50	100	Controversial issue banned in three states.
818	261	364	Legacy of Stark	1958-10-01	3.99	32	High print run; common in collections.
819	71	62	Fallen of Burns	1972-12-15	2.99	80	Part of a crossover event.
820	160	555	Fallen of Steele	1953-08-20	4.99	40	Reprints classic story with new framing pages.
821	176	378	Reckoning of Cole	2011-08-20	0.25	24	High print run; common in collections.
822	260	433	Inferno of Stone	1980-11-24	0.50	36	Landmark story milestone.
823	175	684	Oblivion of Fox	1974-02-14	1.50	100	Reprints classic story with new framing pages.
824	172	429	Eclipse of Cross	1980-09-20	0.20	64	Key first appearance issue.
825	254	4	Revelation of Vale	1994-11-04	3.99	100	High print run; common in collections.
826	123	753	Eclipse of Ward	2007-02-17	0.50	48	Controversial issue banned in three states.
827	4	11	Shadows of Nash	1974-01-07	0.10	80	Landmark story milestone.
828	73	451	Uprising of Hunt	1968-01-13	1.95	24	Key first appearance issue.
829	102	291	Convergence of Vale	1967-03-22	1.00	32	Part of a crossover event.
830	284	183	Uprising of Morgan	2016-09-08	0.35	40	Landmark story milestone.
831	11	389	Rising of Flynn	2007-07-17	0.50	40	Contains bonus pin-up gallery.
832	123	382	Convergence of Cole	1997-02-28	2.99	28	Landmark story milestone.
833	74	195	Uprising of Grant	2017-06-19	2.50	44	Part of a crossover event.
834	220	251	Dawn of Price	2002-04-08	0.50	80	Low distribution; considered scarce.
835	77	254	Dawn of Holt	2014-05-08	0.25	80	Reprints classic story with new framing pages.
836	251	745	Shadows of Stark	1961-10-09	0.15	32	Double-sized anniversary issue.
837	199	770	Resurgence of Nash	1963-06-21	4.99	80	Contains bonus pin-up gallery.
838	92	730	Inferno of Cole	1971-11-15	4.99	64	Contains bonus pin-up gallery.
839	138	411	Reborn of Drake	1997-02-21	0.50	36	High print run; common in collections.
840	232	241	Nemesis of Stone	2018-06-10	1.25	48	Direct edition only; no newsstand version.
841	293	384	Chaos of Grant	2013-10-05	0.15	32	Landmark story milestone.
842	152	532	Inferno of Vale	1994-11-17	0.12	64	Double-sized anniversary issue.
843	173	462	Fracture of Crane	2018-02-11	2.99	44	Contains bonus pin-up gallery.
844	163	392	Reckoning of Cross	1954-01-23	3.99	36	Low distribution; considered scarce.
845	39	85	Vendetta of Cole	2010-03-20	0.15	40	High print run; common in collections.
846	51	74	Inferno of Drake	2011-08-30	0.50	44	High print run; common in collections.
847	169	310	Chaos of Stone	2003-03-20	0.25	80	Low distribution; considered scarce.
848	5	289	Inferno of Ward	1983-11-14	2.50	100	Key first appearance issue.
849	242	780	Fallen of Ward	2018-12-30	0.75	36	High print run; common in collections.
850	243	529	Reborn of Grant	1986-03-30	3.99	64	Part of a crossover event.
851	44	193	Legacy of Crane	1975-02-01	0.50	64	Contains bonus pin-up gallery.
852	286	384	Fallen of Hunt	2011-09-04	0.25	40	Key first appearance issue.
853	256	364	Eclipse of Vale	2021-02-09	2.99	48	Direct edition only; no newsstand version.
854	276	334	Reborn of Morgan	1975-09-21	0.12	32	Controversial issue banned in three states.
855	170	645	Shattered of Price	1952-03-09	2.50	48	High print run; common in collections.
856	201	548	Nemesis of Stone	2006-06-06	4.99	28	Part of a crossover event.
857	292	655	Vendetta of Voss	2010-04-03	0.35	28	Double-sized anniversary issue.
858	91	706	Shattered of Stark	2018-05-12	0.10	32	High print run; common in collections.
859	36	291	Uprising of Vale	1982-04-24	1.25	80	Landmark story milestone.
860	233	378	Resurgence of Morgan	2016-04-27	0.35	44	Direct edition only; no newsstand version.
861	201	114	Fallen of Grant	2008-07-10	2.99	64	Landmark story milestone.
862	200	134	Uprising of Burns	1973-07-10	2.99	64	Controversial issue banned in three states.
863	295	602	Uprising of Cole	1943-09-28	3.99	40	High print run; common in collections.
864	4	457	Shadows of Ward	1973-05-27	0.75	80	Part of a crossover event.
865	292	472	Fracture of Hunt	2012-01-09	0.12	28	Low distribution; considered scarce.
866	234	718	Vendetta of Ward	1991-12-12	0.35	48	High print run; common in collections.
867	92	633	Legacy of Fox	2023-09-28	2.50	32	Reprints classic story with new framing pages.
868	49	716	Dawn of Vale	1987-08-27	0.35	40	Double-sized anniversary issue.
869	150	715	Uprising of Stark	1998-12-29	2.99	80	Landmark story milestone.
870	189	774	Rising of Cole	2018-11-10	1.50	48	Contains bonus pin-up gallery.
871	85	213	Resurgence of Drake	2007-05-04	3.99	24	Landmark story milestone.
872	237	352	Nemesis of Stone	2021-02-19	2.50	24	Key first appearance issue.
873	129	727	Fallen of Flynn	1979-02-22	3.99	64	Contains bonus pin-up gallery.
874	35	562	Revelation of Fox	2007-06-19	0.25	64	Low distribution; considered scarce.
875	83	19	Shattered of Kane	2017-12-16	0.35	40	Landmark story milestone.
876	274	401	Convergence of Voss	2010-04-25	0.10	40	Controversial issue banned in three states.
877	226	183	Uprising of Drake	1972-01-23	0.50	64	Key first appearance issue.
878	268	400	Vendetta of Fox	1989-02-25	0.12	100	Key first appearance issue.
879	25	387	Uprising of Vale	2023-04-19	1.95	36	High print run; common in collections.
880	47	432	Reckoning of Morgan	1976-02-02	1.50	36	Landmark story milestone.
881	113	99	Convergence of Cross	2021-02-25	0.12	48	Double-sized anniversary issue.
882	56	335	Eclipse of Grant	1962-07-29	0.50	100	High print run; common in collections.
883	278	439	Rising of Vale	1972-11-10	0.50	28	Part of a crossover event.
884	166	16	Nemesis of Flynn	1994-07-30	0.10	48	High print run; common in collections.
885	235	68	Chaos of Price	2008-12-08	1.95	24	Landmark story milestone.
886	112	309	Shattered of Stark	1983-11-18	0.20	80	Reprints classic story with new framing pages.
887	88	98	Shattered of Flynn	2003-08-26	2.50	32	Part of a crossover event.
888	90	780	Eclipse of Stark	2005-07-02	0.15	44	Key first appearance issue.
889	300	392	Resurgence of Vale	2021-04-04	0.10	36	Key first appearance issue.
890	64	243	Legacy of Vale	2015-11-09	0.15	24	Controversial issue banned in three states.
891	192	304	Uprising of Steele	1998-03-09	2.50	36	Key first appearance issue.
892	122	613	Fracture of Flynn	2009-01-25	0.25	40	Part of a crossover event.
893	21	425	Vendetta of Morgan	2023-11-04	0.75	44	Part of a crossover event.
894	125	553	Dawn of Vale	1975-03-27	0.75	100	Direct edition only; no newsstand version.
895	267	188	Fracture of Morgan	1952-08-10	0.15	64	Landmark story milestone.
896	99	650	Fallen of Stone	1953-09-04	0.25	28	Controversial issue banned in three states.
897	282	242	Resurgence of Voss	1985-03-02	2.99	64	Low distribution; considered scarce.
898	85	251	Legacy of Cross	2004-11-10	0.75	40	Low distribution; considered scarce.
899	296	651	Uprising of Holt	2023-01-11	4.99	28	Part of a crossover event.
900	204	172	Oblivion of Fox	1993-06-22	2.99	80	Reprints classic story with new framing pages.
901	222	494	Reckoning of Ward	1995-12-29	2.99	28	Low distribution; considered scarce.
902	276	567	Convergence of Holt	1972-06-05	2.50	64	Low distribution; considered scarce.
903	233	385	Descent of Price	2017-08-03	4.99	28	Part of a crossover event.
904	70	201	Fallen of Stone	1968-01-19	0.10	24	Double-sized anniversary issue.
905	192	415	Legacy of Ward	1998-01-08	1.95	48	Contains bonus pin-up gallery.
906	158	603	Shadows of Crane	1960-05-18	0.12	28	Direct edition only; no newsstand version.
907	290	199	Legacy of Holt	1989-08-23	1.95	80	Contains bonus pin-up gallery.
908	189	667	Nemesis of Crane	2018-08-25	0.75	36	Contains bonus pin-up gallery.
909	18	371	Reckoning of Steele	2023-02-13	1.00	100	Contains bonus pin-up gallery.
910	76	254	Shattered of Hunt	1984-05-29	0.35	24	Landmark story milestone.
911	48	408	Reborn of Voss	1991-03-30	0.50	48	Controversial issue banned in three states.
912	219	709	Vendetta of Cole	1985-09-08	2.50	100	Low distribution; considered scarce.
913	211	746	Shadows of Kane	2015-07-04	1.95	32	Low distribution; considered scarce.
914	108	408	Vendetta of Morgan	1952-03-12	0.35	64	Key first appearance issue.
915	50	793	Legacy of Cole	1944-04-07	2.99	40	Direct edition only; no newsstand version.
916	88	384	Convergence of Steele	2001-12-16	0.50	64	Controversial issue banned in three states.
917	258	462	Reborn of Stone	1981-06-22	0.35	36	Key first appearance issue.
918	94	778	Uprising of Holt	2013-01-27	2.99	64	Reprints classic story with new framing pages.
919	56	652	Convergence of Voss	1962-11-14	1.25	28	Direct edition only; no newsstand version.
920	64	66	Eclipse of Morgan	2014-06-01	0.75	64	Contains bonus pin-up gallery.
921	52	63	Chaos of Morgan	2008-03-18	0.12	28	High print run; common in collections.
922	268	385	Shattered of Cole	1988-01-30	1.00	64	Contains bonus pin-up gallery.
923	173	345	Inferno of Flynn	2018-04-07	1.50	36	Part of a crossover event.
924	205	626	Dawn of Nash	2009-03-31	1.50	28	Key first appearance issue.
925	234	412	Fallen of Morgan	1993-12-01	0.20	80	Low distribution; considered scarce.
926	128	463	Shattered of Stark	1989-07-12	2.99	36	Key first appearance issue.
927	165	649	Inferno of Drake	1979-02-04	1.50	64	High print run; common in collections.
928	249	757	Shattered of Voss	2020-06-27	1.95	48	Contains bonus pin-up gallery.
929	52	395	Vendetta of Price	2024-06-20	0.50	32	Double-sized anniversary issue.
930	293	33	Fallen of Stark	2017-08-28	0.15	40	Double-sized anniversary issue.
931	240	457	Rising of Stark	2020-12-10	0.75	36	High print run; common in collections.
932	88	676	Shadows of Kane	2014-11-23	2.99	24	Controversial issue banned in three states.
933	168	785	Chaos of Vale	1984-03-15	1.00	64	Landmark story milestone.
934	70	649	Oblivion of Voss	1970-12-23	1.50	36	Reprints classic story with new framing pages.
935	34	352	Nemesis of Ward	1962-03-22	2.99	36	High print run; common in collections.
936	133	298	Shadows of Kane	2002-04-19	0.15	44	Reprints classic story with new framing pages.
937	97	587	Inferno of Steele	1963-08-10	1.50	48	Reprints classic story with new framing pages.
938	1	64	Reborn of Grant	2000-11-19	0.50	48	Direct edition only; no newsstand version.
939	164	696	Fallen of Cole	2007-03-10	0.75	28	Direct edition only; no newsstand version.
940	5	472	Eclipse of Steele	2005-04-17	1.25	36	Contains bonus pin-up gallery.
941	234	616	Vendetta of Steele	1990-10-29	0.12	100	Part of a crossover event.
942	159	706	Rising of Holt	1967-04-08	4.99	36	Contains bonus pin-up gallery.
943	150	61	Eclipse of Steele	2012-11-23	0.50	36	Key first appearance issue.
944	92	500	Nemesis of Burns	2019-11-12	0.35	24	Double-sized anniversary issue.
945	201	433	Oblivion of Nash	2012-07-27	2.50	48	Landmark story milestone.
946	271	290	Vendetta of Stone	1953-01-28	2.50	28	Controversial issue banned in three states.
947	166	727	Vendetta of Fox	1983-11-09	0.35	100	Controversial issue banned in three states.
948	227	299	Fallen of Stone	1963-08-23	0.50	36	Key first appearance issue.
949	186	695	Fallen of Ward	1992-07-28	2.99	32	Key first appearance issue.
950	50	486	Convergence of Drake	1969-11-25	0.20	80	Part of a crossover event.
951	223	643	Nemesis of Vale	1964-05-02	0.12	28	High print run; common in collections.
952	204	310	Shattered of Cross	1995-12-17	2.50	28	Contains bonus pin-up gallery.
953	196	648	Fracture of Nash	1956-03-04	0.10	28	Landmark story milestone.
954	43	501	Resurgence of Vale	1978-12-13	0.10	100	Reprints classic story with new framing pages.
955	294	281	Rising of Hunt	2015-05-19	0.35	48	Contains bonus pin-up gallery.
956	223	586	Fallen of Kane	1967-09-11	1.50	28	Double-sized anniversary issue.
957	95	718	Reckoning of Ward	2008-05-12	4.99	28	Double-sized anniversary issue.
958	300	731	Rising of Stone	2021-07-05	0.20	32	Reprints classic story with new framing pages.
959	93	569	Fracture of Flynn	2020-01-11	0.20	24	Controversial issue banned in three states.
960	295	669	Convergence of Voss	1943-02-27	1.00	24	Landmark story milestone.
961	64	306	Inferno of Grant	2024-09-14	0.35	48	Key first appearance issue.
962	128	48	Resurgence of Burns	1986-06-27	3.99	32	Reprints classic story with new framing pages.
963	252	321	Resurgence of Nash	1972-08-04	0.50	28	Key first appearance issue.
964	122	193	Fallen of Burns	1947-04-18	0.50	32	Reprints classic story with new framing pages.
965	283	606	Inferno of Holt	1971-06-04	0.25	100	Direct edition only; no newsstand version.
966	39	267	Nemesis of Cross	2000-11-15	2.50	64	Landmark story milestone.
967	131	712	Fallen of Grant	1998-01-29	0.50	28	Low distribution; considered scarce.
968	99	382	Reborn of Cole	2013-02-04	0.35	48	Controversial issue banned in three states.
969	162	389	Reckoning of Price	1961-09-22	0.75	28	Low distribution; considered scarce.
970	64	701	Descent of Crane	2006-12-08	0.15	44	Landmark story milestone.
971	186	797	Chaos of Steele	2002-12-17	0.75	40	Key first appearance issue.
972	51	228	Nemesis of Kane	2017-06-17	0.20	32	Double-sized anniversary issue.
973	157	502	Rising of Cole	2021-08-25	1.95	100	Low distribution; considered scarce.
974	283	623	Rising of Drake	1972-01-16	0.35	44	Direct edition only; no newsstand version.
975	93	760	Descent of Grant	2021-12-07	2.50	64	Reprints classic story with new framing pages.
976	66	10	Resurgence of Steele	1987-08-15	0.25	32	Direct edition only; no newsstand version.
977	291	55	Inferno of Vale	1964-12-29	2.99	64	Controversial issue banned in three states.
978	225	480	Resurgence of Burns	1988-11-17	1.00	48	Double-sized anniversary issue.
979	118	651	Shadows of Burns	1980-09-09	2.99	44	Landmark story milestone.
980	41	748	Revelation of Voss	1992-06-10	0.35	100	Key first appearance issue.
981	44	293	Descent of Stark	2013-09-11	0.10	48	Double-sized anniversary issue.
982	70	510	Resurgence of Grant	1968-07-07	0.20	48	Key first appearance issue.
983	98	732	Legacy of Grant	2009-03-01	1.95	36	Double-sized anniversary issue.
984	22	173	Resurgence of Vale	1978-02-15	0.35	28	Part of a crossover event.
985	69	362	Dawn of Crane	1971-10-06	4.99	48	Controversial issue banned in three states.
986	192	347	Revelation of Grant	1989-07-16	0.20	40	Low distribution; considered scarce.
987	248	272	Uprising of Morgan	2013-04-17	2.50	36	Low distribution; considered scarce.
988	264	475	Shattered of Stark	2013-10-18	0.12	44	Key first appearance issue.
989	236	306	Inferno of Kane	1987-06-23	0.10	44	Controversial issue banned in three states.
990	206	10	Rising of Crane	1986-12-28	4.99	36	Landmark story milestone.
991	271	158	Legacy of Kane	1951-11-20	4.99	24	Controversial issue banned in three states.
992	129	482	Nemesis of Nash	1984-02-22	1.25	44	Direct edition only; no newsstand version.
993	94	276	Rising of Fox	2010-01-06	3.99	32	Controversial issue banned in three states.
994	182	445	Reckoning of Nash	2020-01-10	0.50	28	High print run; common in collections.
995	146	137	Nemesis of Crane	2018-03-24	1.50	24	Controversial issue banned in three states.
996	102	682	Chaos of Kane	1970-05-18	2.99	64	Double-sized anniversary issue.
997	254	699	Fallen of Flynn	2020-11-17	2.50	80	Direct edition only; no newsstand version.
998	68	111	Reckoning of Steele	1957-11-04	0.25	44	Double-sized anniversary issue.
999	7	54	Eclipse of Crane	1958-04-22	0.10	48	Contains bonus pin-up gallery.
1000	149	498	Shadows of Crane	1996-08-28	0.75	100	Controversial issue banned in three states.
1001	262	256	Chaos of Kane	1959-10-07	1.00	36	Direct edition only; no newsstand version.
1002	102	724	Rising of Cole	1970-04-26	0.35	36	Reprints classic story with new framing pages.
1003	77	124	Fallen of Ward	2012-02-23	0.12	40	High print run; common in collections.
1004	75	19	Shattered of Stone	1990-02-14	0.15	24	Direct edition only; no newsstand version.
1005	209	314	Revelation of Vale	2013-02-05	1.50	48	Contains bonus pin-up gallery.
1006	32	438	Dawn of Burns	1961-06-08	0.20	40	Part of a crossover event.
1007	144	729	Legacy of Vale	1955-09-30	1.50	24	Controversial issue banned in three states.
1008	21	54	Eclipse of Stone	2018-01-03	1.25	64	Low distribution; considered scarce.
1009	52	190	Chaos of Stark	2017-08-30	1.95	44	Low distribution; considered scarce.
1010	58	686	Reckoning of Grant	1988-09-09	0.25	44	Part of a crossover event.
1011	186	620	Inferno of Vale	2011-09-21	1.00	36	Reprints classic story with new framing pages.
1012	197	109	Fallen of Price	1948-12-23	0.20	24	Reprints classic story with new framing pages.
1013	98	722	Fracture of Kane	2013-04-30	0.15	80	Reprints classic story with new framing pages.
1014	176	743	Oblivion of Stone	2011-09-10	0.25	24	Controversial issue banned in three states.
1015	99	564	Chaos of Grant	1986-07-09	1.95	44	Contains bonus pin-up gallery.
1016	61	70	Oblivion of Crane	1987-10-13	0.10	32	Reprints classic story with new framing pages.
1017	141	297	Dawn of Hunt	1975-10-14	0.12	36	Direct edition only; no newsstand version.
1018	254	546	Resurgence of Voss	2015-09-19	0.35	64	Double-sized anniversary issue.
1019	197	411	Shattered of Holt	1952-05-17	0.50	32	Key first appearance issue.
1020	82	224	Reborn of Morgan	1992-04-22	3.99	80	Double-sized anniversary issue.
1021	133	226	Vendetta of Holt	2004-05-27	0.20	32	High print run; common in collections.
1022	24	244	Vendetta of Drake	1970-12-28	0.25	40	Controversial issue banned in three states.
1023	139	658	Revelation of Stone	1992-04-24	0.20	24	Part of a crossover event.
1024	189	86	Descent of Holt	2021-08-22	0.25	48	Reprints classic story with new framing pages.
1025	151	59	Reckoning of Nash	1974-04-13	0.75	40	Controversial issue banned in three states.
1026	132	551	Reborn of Kane	1944-05-27	2.50	40	Reprints classic story with new framing pages.
1027	283	453	Revelation of Flynn	1971-04-25	1.00	36	Reprints classic story with new framing pages.
1028	203	457	Revelation of Crane	2000-12-25	1.95	32	Contains bonus pin-up gallery.
1029	48	186	Fracture of Cross	1996-03-31	0.35	36	Reprints classic story with new framing pages.
1030	252	185	Vendetta of Morgan	1973-05-12	1.25	32	Controversial issue banned in three states.
1031	202	72	Fallen of Voss	2018-01-20	2.99	36	Contains bonus pin-up gallery.
1032	207	742	Resurgence of Steele	1997-07-01	0.10	100	Landmark story milestone.
1033	194	22	Rising of Morgan	2002-08-12	0.12	32	High print run; common in collections.
1034	43	147	Shattered of Morgan	1992-01-05	0.10	28	Double-sized anniversary issue.
1035	174	88	Uprising of Steele	2017-12-25	4.99	100	Contains bonus pin-up gallery.
1036	84	340	Oblivion of Steele	1958-06-13	0.75	24	Double-sized anniversary issue.
1037	137	557	Rising of Morgan	1952-07-09	0.12	28	Double-sized anniversary issue.
1038	152	524	Legacy of Steele	1964-03-14	0.10	36	Key first appearance issue.
1039	117	395	Fallen of Nash	2018-10-16	1.25	36	Direct edition only; no newsstand version.
1040	58	174	Rising of Vale	2024-02-14	0.20	40	Part of a crossover event.
1041	40	342	Rising of Nash	1948-06-14	0.15	24	Reprints classic story with new framing pages.
1042	78	439	Resurgence of Flynn	1949-12-29	0.35	48	Controversial issue banned in three states.
1043	155	294	Inferno of Kane	2001-01-03	1.00	64	Part of a crossover event.
1044	136	729	Shadows of Morgan	2022-07-19	0.25	32	Part of a crossover event.
1045	76	458	Oblivion of Voss	1990-07-10	0.20	100	Direct edition only; no newsstand version.
1046	143	93	Eclipse of Steele	1987-10-24	0.35	48	Part of a crossover event.
1047	164	435	Oblivion of Crane	2010-01-31	1.50	32	High print run; common in collections.
1048	197	563	Oblivion of Grant	1952-09-10	4.99	80	Double-sized anniversary issue.
1049	118	86	Reborn of Crane	1984-04-02	0.75	28	High print run; common in collections.
1050	186	209	Reckoning of Nash	1988-02-16	4.99	32	Landmark story milestone.
1051	31	370	Fallen of Burns	2018-11-01	3.99	32	Double-sized anniversary issue.
1052	216	216	Revelation of Drake	1967-10-04	0.25	28	Controversial issue banned in three states.
1053	194	27	Legacy of Nash	2010-06-11	0.12	28	Reprints classic story with new framing pages.
1054	38	609	Convergence of Morgan	1999-10-12	0.25	44	Controversial issue banned in three states.
1055	41	79	Reckoning of Hunt	1999-12-29	2.99	32	Controversial issue banned in three states.
1056	241	767	Resurgence of Burns	2019-07-28	4.99	48	Part of a crossover event.
1057	228	661	Reckoning of Burns	2023-01-19	0.20	32	Key first appearance issue.
1058	17	516	Convergence of Morgan	1964-10-14	2.50	48	Contains bonus pin-up gallery.
1059	284	265	Reborn of Cole	2017-12-29	1.25	36	Direct edition only; no newsstand version.
1060	81	95	Resurgence of Ward	2010-01-18	0.25	36	Direct edition only; no newsstand version.
1061	29	402	Convergence of Grant	1948-03-24	0.15	64	Contains bonus pin-up gallery.
1062	161	390	Convergence of Drake	2015-05-06	1.95	48	High print run; common in collections.
1063	139	107	Shadows of Nash	1994-11-12	1.50	24	High print run; common in collections.
1064	145	555	Rising of Voss	2016-10-28	0.50	100	Key first appearance issue.
1065	159	565	Uprising of Drake	1960-03-17	0.75	40	Landmark story milestone.
1066	292	46	Reborn of Stark	2015-05-03	0.12	24	Part of a crossover event.
1067	48	9	Inferno of Burns	1987-11-05	2.50	80	High print run; common in collections.
1068	162	401	Inferno of Steele	1968-11-11	0.20	44	Direct edition only; no newsstand version.
1069	258	515	Fallen of Morgan	1981-04-07	2.50	64	Reprints classic story with new framing pages.
1070	20	166	Fallen of Fox	1951-01-06	0.15	28	High print run; common in collections.
1071	111	698	Fallen of Cross	1973-01-20	1.50	64	Controversial issue banned in three states.
1072	174	369	Shattered of Crane	2016-10-24	0.12	48	High print run; common in collections.
1073	107	622	Shadows of Steele	2002-09-10	4.99	28	Key first appearance issue.
1074	74	561	Shadows of Stark	2019-06-21	0.20	64	Part of a crossover event.
1075	87	166	Shadows of Holt	1995-07-10	1.95	44	Landmark story milestone.
1076	37	728	Fracture of Holt	1979-01-14	4.99	40	Contains bonus pin-up gallery.
1077	72	583	Oblivion of Drake	1965-07-24	1.95	40	Direct edition only; no newsstand version.
1078	210	635	Fallen of Fox	2018-11-20	1.95	80	Reprints classic story with new framing pages.
1079	161	86	Legacy of Cole	2012-07-10	3.99	40	Key first appearance issue.
1080	30	251	Descent of Morgan	2019-08-15	0.25	28	Low distribution; considered scarce.
1081	193	584	Nemesis of Voss	2009-02-05	0.75	48	Contains bonus pin-up gallery.
1082	48	478	Fracture of Grant	1989-08-26	3.99	28	Landmark story milestone.
1083	93	111	Nemesis of Crane	2024-02-07	0.50	48	Part of a crossover event.
1084	34	351	Shattered of Stark	1958-07-23	0.50	64	Landmark story milestone.
1085	143	40	Descent of Steele	1989-07-19	4.99	32	High print run; common in collections.
1086	164	33	Shattered of Ward	2011-09-29	0.12	44	Direct edition only; no newsstand version.
1087	243	56	Uprising of Morgan	1985-10-15	2.99	40	Low distribution; considered scarce.
1088	91	146	Shadows of Holt	2018-12-09	2.50	28	Low distribution; considered scarce.
1089	232	430	Resurgence of Stone	2019-03-03	1.00	32	Key first appearance issue.
1090	48	351	Vendetta of Cross	1993-03-23	0.50	44	Direct edition only; no newsstand version.
1091	247	549	Convergence of Crane	1976-04-30	1.95	100	Direct edition only; no newsstand version.
1092	6	612	Uprising of Voss	1995-07-31	0.25	44	Part of a crossover event.
1093	8	470	Fallen of Stark	2014-05-17	1.50	28	Direct edition only; no newsstand version.
1094	135	740	Reckoning of Fox	2022-11-03	0.25	64	Reprints classic story with new framing pages.
1095	50	224	Uprising of Crane	1941-04-10	0.35	100	Direct edition only; no newsstand version.
1096	111	215	Uprising of Hunt	1967-11-26	0.10	44	Part of a crossover event.
1097	9	315	Resurgence of Kane	1973-10-09	4.99	64	Direct edition only; no newsstand version.
1098	211	361	Descent of Crane	1979-07-22	1.50	28	Controversial issue banned in three states.
1099	235	383	Convergence of Grant	2013-08-10	0.35	80	Direct edition only; no newsstand version.
1100	196	676	Legacy of Burns	1956-05-23	0.20	28	Landmark story milestone.
1101	46	17	Shattered of Crane	1972-07-27	0.20	64	Reprints classic story with new framing pages.
1102	279	649	Fracture of Cole	1956-03-27	0.12	40	Direct edition only; no newsstand version.
1103	109	796	Fracture of Grant	2019-07-02	2.50	28	High print run; common in collections.
1104	241	360	Fracture of Crane	2019-05-25	2.50	24	Part of a crossover event.
1105	115	291	Chaos of Holt	1992-07-14	1.25	48	High print run; common in collections.
1106	3	34	Reckoning of Morgan	1959-08-07	0.25	44	Double-sized anniversary issue.
1107	163	175	Reborn of Crane	1954-10-04	0.75	80	Direct edition only; no newsstand version.
1108	99	660	Nemesis of Drake	2004-04-15	2.99	32	Direct edition only; no newsstand version.
1109	89	326	Resurgence of Cross	2017-04-05	2.99	36	Landmark story milestone.
1110	65	122	Reborn of Ward	1999-03-29	1.00	80	Controversial issue banned in three states.
1111	166	96	Shadows of Morgan	1997-04-12	2.99	24	Reprints classic story with new framing pages.
1112	79	633	Descent of Voss	1992-03-31	2.50	24	Controversial issue banned in three states.
1113	233	192	Revelation of Vale	2018-01-03	1.25	36	Double-sized anniversary issue.
1114	126	799	Nemesis of Holt	1983-02-22	0.12	40	Landmark story milestone.
1115	74	24	Reborn of Kane	2023-01-13	0.20	64	Reprints classic story with new framing pages.
1116	63	146	Vendetta of Holt	1997-10-21	0.35	28	Landmark story milestone.
1117	254	371	Uprising of Ward	2022-11-21	0.20	64	Key first appearance issue.
1118	212	499	Shadows of Stone	1950-08-07	2.99	48	Part of a crossover event.
1119	231	185	Vendetta of Morgan	1982-03-24	0.35	100	Reprints classic story with new framing pages.
1120	17	352	Inferno of Stark	1962-04-05	0.10	32	Double-sized anniversary issue.
1121	131	198	Shattered of Morgan	1984-06-15	0.10	80	Double-sized anniversary issue.
1122	79	374	Rising of Stone	2000-09-13	0.10	44	Controversial issue banned in three states.
1123	113	746	Fallen of Holt	1949-06-27	1.00	64	High print run; common in collections.
1124	48	726	Descent of Burns	1989-08-20	3.99	64	Direct edition only; no newsstand version.
1125	263	198	Chaos of Cross	2000-11-18	0.50	40	Direct edition only; no newsstand version.
1126	53	785	Reborn of Burns	2009-03-07	0.35	36	Contains bonus pin-up gallery.
1127	222	434	Shattered of Holt	2009-01-05	1.50	100	Landmark story milestone.
1128	197	205	Reborn of Nash	1952-10-24	1.95	28	Contains bonus pin-up gallery.
1129	86	524	Chaos of Hunt	1999-07-08	2.99	40	Reprints classic story with new framing pages.
1130	272	408	Reckoning of Kane	2002-10-20	0.35	44	Direct edition only; no newsstand version.
1131	96	252	Shadows of Stone	2013-01-18	1.95	44	Controversial issue banned in three states.
1132	161	10	Eclipse of Morgan	1989-12-21	1.50	36	Contains bonus pin-up gallery.
1133	291	239	Descent of Voss	1967-06-05	2.50	40	Reprints classic story with new framing pages.
1134	109	223	Rising of Grant	2022-11-30	1.00	100	Landmark story milestone.
1135	294	432	Legacy of Flynn	2017-04-01	1.50	36	High print run; common in collections.
1136	26	506	Oblivion of Drake	2019-07-02	1.00	48	Landmark story milestone.
1137	64	176	Shattered of Flynn	2022-04-24	2.50	36	Reprints classic story with new framing pages.
1138	11	19	Reborn of Morgan	2009-03-13	3.99	40	Controversial issue banned in three states.
1139	207	547	Resurgence of Drake	1994-08-30	1.50	24	Landmark story milestone.
1140	241	426	Vendetta of Holt	2019-01-25	1.50	44	Direct edition only; no newsstand version.
1141	41	794	Eclipse of Stark	2013-12-17	0.12	48	Low distribution; considered scarce.
1142	233	657	Rising of Nash	2018-10-07	0.20	24	High print run; common in collections.
1143	25	143	Rising of Flynn	1954-12-07	2.99	36	Controversial issue banned in three states.
1144	46	742	Inferno of Grant	1962-04-15	0.10	24	Low distribution; considered scarce.
1145	23	50	Vendetta of Voss	1949-12-09	1.00	44	Reprints classic story with new framing pages.
1146	195	716	Convergence of Steele	1998-03-20	3.99	28	Controversial issue banned in three states.
1147	164	772	Reborn of Crane	2002-04-27	3.99	28	Double-sized anniversary issue.
1148	271	592	Oblivion of Stark	1950-05-08	1.00	44	Contains bonus pin-up gallery.
1149	116	271	Vendetta of Voss	1954-01-12	1.95	80	High print run; common in collections.
1150	106	77	Oblivion of Drake	1999-11-16	0.50	24	High print run; common in collections.
1151	240	193	Oblivion of Kane	2022-02-27	1.50	36	Reprints classic story with new framing pages.
1152	271	321	Vendetta of Fox	1951-11-19	0.25	80	Landmark story milestone.
1153	67	373	Nemesis of Fox	2014-06-15	0.50	48	High print run; common in collections.
1154	36	434	Convergence of Burns	1977-06-19	0.20	32	Contains bonus pin-up gallery.
1155	55	113	Revelation of Morgan	2007-11-04	3.99	32	Low distribution; considered scarce.
1156	15	678	Resurgence of Fox	2019-09-07	1.95	40	Landmark story milestone.
1157	282	363	Legacy of Stone	1979-10-09	0.25	48	Double-sized anniversary issue.
1158	221	342	Dawn of Fox	1985-11-06	1.00	44	Landmark story milestone.
1159	26	392	Legacy of Stone	2018-08-21	1.25	36	Direct edition only; no newsstand version.
1160	91	283	Resurgence of Price	2024-08-30	4.99	80	Direct edition only; no newsstand version.
1161	56	52	Revelation of Kane	1961-10-27	0.75	28	Key first appearance issue.
1162	19	245	Shadows of Grant	1977-12-20	0.20	40	High print run; common in collections.
1163	208	403	Rising of Vale	1979-02-28	1.00	64	High print run; common in collections.
1164	88	209	Inferno of Burns	2015-08-16	1.25	24	Landmark story milestone.
1165	95	718	Shattered of Stark	2017-02-23	1.25	36	Controversial issue banned in three states.
1166	162	72	Convergence of Cross	1967-04-14	1.50	64	Controversial issue banned in three states.
1167	7	439	Eclipse of Morgan	1963-08-24	0.35	40	Landmark story milestone.
1168	88	779	Reckoning of Price	2013-03-27	1.95	64	Reprints classic story with new framing pages.
1169	1	254	Oblivion of Kane	2016-10-22	0.12	24	Reprints classic story with new framing pages.
1170	149	234	Resurgence of Cole	2021-06-21	0.35	32	Landmark story milestone.
1171	52	754	Eclipse of Fox	2014-10-31	4.99	44	Double-sized anniversary issue.
1172	132	499	Chaos of Nash	2002-07-08	3.99	24	Part of a crossover event.
1173	155	342	Resurgence of Price	2001-12-18	4.99	28	Low distribution; considered scarce.
1174	266	22	Fallen of Crane	1966-09-13	0.75	32	Part of a crossover event.
1175	255	251	Reborn of Crane	1944-05-06	1.95	36	Landmark story milestone.
1176	100	655	Rising of Holt	1993-06-22	3.99	80	Controversial issue banned in three states.
1177	136	358	Eclipse of Ward	2021-10-22	2.99	40	Low distribution; considered scarce.
1178	98	594	Resurgence of Flynn	2009-12-03	0.20	48	Contains bonus pin-up gallery.
1179	291	296	Rising of Morgan	1968-07-26	4.99	32	Contains bonus pin-up gallery.
1180	77	297	Shattered of Grant	2018-09-25	0.35	40	Contains bonus pin-up gallery.
1181	148	302	Reckoning of Fox	1986-11-24	0.12	36	Low distribution; considered scarce.
1182	64	501	Vendetta of Morgan	2004-05-21	2.99	44	Key first appearance issue.
1183	26	142	Inferno of Burns	2016-05-29	0.25	28	Low distribution; considered scarce.
1184	74	443	Reborn of Voss	2018-03-16	1.25	36	Key first appearance issue.
1185	243	255	Nemesis of Crane	1988-12-15	2.50	28	Low distribution; considered scarce.
1186	155	319	Convergence of Hunt	2000-09-11	2.99	44	Reprints classic story with new framing pages.
1187	72	257	Fallen of Crane	1968-12-12	0.50	40	Low distribution; considered scarce.
1188	44	581	Fracture of Grant	1973-09-04	0.35	48	Direct edition only; no newsstand version.
1189	50	540	Fracture of Flynn	1950-06-08	1.95	64	Part of a crossover event.
1190	219	431	Legacy of Fox	2004-11-08	0.10	80	Key first appearance issue.
1191	216	774	Fallen of Price	1953-12-07	1.25	36	Reprints classic story with new framing pages.
1192	263	131	Shattered of Grant	1998-06-23	1.25	24	Direct edition only; no newsstand version.
1193	65	687	Reckoning of Fox	1990-02-24	3.99	24	Landmark story milestone.
1194	29	666	Rising of Flynn	1948-07-07	0.20	40	Reprints classic story with new framing pages.
1195	247	63	Rising of Hunt	1969-11-11	0.12	36	Double-sized anniversary issue.
1196	74	759	Oblivion of Steele	2022-04-21	0.75	32	Low distribution; considered scarce.
1197	160	497	Shattered of Stone	1952-01-07	0.20	28	Key first appearance issue.
1198	79	124	Resurgence of Kane	2018-01-31	0.75	36	Landmark story milestone.
1199	243	518	Fracture of Ward	1981-07-21	0.12	28	Low distribution; considered scarce.
1200	208	189	Revelation of Grant	1987-05-25	1.00	100	Contains bonus pin-up gallery.
1201	64	150	Reckoning of Cross	2021-05-24	0.25	36	Controversial issue banned in three states.
1202	262	717	Descent of Stone	2009-07-15	4.99	64	Low distribution; considered scarce.
1203	149	103	Reborn of Stark	2013-12-10	1.95	40	Direct edition only; no newsstand version.
1204	198	110	Fracture of Crane	2010-08-03	2.99	32	Key first appearance issue.
1205	146	124	Reborn of Ward	2020-07-25	0.10	100	Low distribution; considered scarce.
1206	18	667	Shattered of Fox	2021-03-27	0.12	44	Controversial issue banned in three states.
1207	240	284	Reckoning of Cross	2022-07-27	1.95	80	Double-sized anniversary issue.
1208	108	724	Resurgence of Ward	1949-12-15	0.15	32	Controversial issue banned in three states.
1209	181	348	Fracture of Steele	2001-04-05	1.00	40	Direct edition only; no newsstand version.
1210	35	496	Nemesis of Stark	2010-08-14	0.35	100	Double-sized anniversary issue.
1211	270	133	Eclipse of Hunt	1986-08-18	1.95	100	Reprints classic story with new framing pages.
1212	207	47	Reckoning of Cross	1996-01-13	0.75	28	Landmark story milestone.
1213	256	488	Eclipse of Vale	2022-12-12	0.75	28	Controversial issue banned in three states.
1214	197	66	Dawn of Price	1952-09-16	1.00	28	Key first appearance issue.
1215	38	782	Inferno of Price	1996-08-12	0.10	32	Part of a crossover event.
1216	56	461	Nemesis of Steele	1961-12-01	0.50	36	Low distribution; considered scarce.
1217	252	696	Vendetta of Vale	1966-10-25	0.50	32	Direct edition only; no newsstand version.
1218	271	197	Shadows of Hunt	1953-07-15	0.10	28	High print run; common in collections.
1219	18	144	Reckoning of Nash	2023-01-31	2.99	100	Double-sized anniversary issue.
1220	37	190	Resurgence of Stark	1986-04-14	0.50	36	Reprints classic story with new framing pages.
1221	243	361	Inferno of Price	1992-03-26	0.25	28	Contains bonus pin-up gallery.
1222	219	386	Shadows of Hunt	2019-02-11	0.15	32	Double-sized anniversary issue.
1223	153	121	Oblivion of Vale	1969-02-17	0.12	100	Double-sized anniversary issue.
1224	170	230	Vendetta of Holt	1949-02-16	2.50	44	Landmark story milestone.
1225	81	77	Descent of Hunt	2010-03-25	0.75	80	Reprints classic story with new framing pages.
1226	257	409	Shattered of Drake	1997-01-01	0.20	100	Contains bonus pin-up gallery.
1227	135	34	Eclipse of Crane	2017-05-03	1.00	36	Part of a crossover event.
1228	31	210	Descent of Flynn	2014-02-15	0.12	36	Contains bonus pin-up gallery.
1229	38	625	Dawn of Nash	2007-08-03	0.15	48	Reprints classic story with new framing pages.
1230	42	491	Fallen of Holt	2023-03-09	0.12	28	Key first appearance issue.
1231	255	231	Inferno of Crane	1949-09-10	4.99	40	High print run; common in collections.
1232	11	27	Uprising of Grant	2006-08-15	2.50	24	Double-sized anniversary issue.
1233	247	397	Nemesis of Steele	1957-05-04	2.99	48	Double-sized anniversary issue.
1234	71	449	Rising of Price	1979-05-16	1.95	44	High print run; common in collections.
1235	176	60	Revelation of Vale	2012-06-13	0.15	100	Key first appearance issue.
1236	117	766	Descent of Hunt	2018-08-19	0.12	24	High print run; common in collections.
1237	30	59	Fallen of Fox	2004-09-19	0.35	40	Key first appearance issue.
1238	161	617	Revelation of Burns	2010-05-15	0.25	100	Direct edition only; no newsstand version.
1239	246	126	Shadows of Voss	2012-06-30	1.00	80	High print run; common in collections.
1240	254	753	Inferno of Vale	2016-08-20	3.99	40	Part of a crossover event.
1241	283	670	Revelation of Cole	1972-04-13	1.00	44	Double-sized anniversary issue.
1242	258	56	Inferno of Crane	1981-05-05	4.99	40	Landmark story milestone.
1243	105	534	Revelation of Burns	2019-10-08	0.50	28	Part of a crossover event.
1244	73	241	Fracture of Fox	1956-08-10	0.20	24	Contains bonus pin-up gallery.
1245	18	285	Reborn of Ward	2017-01-12	1.25	28	Key first appearance issue.
1246	143	625	Nemesis of Stark	1991-10-17	0.10	48	Direct edition only; no newsstand version.
1247	228	230	Uprising of Ward	1989-12-28	0.35	48	Double-sized anniversary issue.
1248	27	313	Dawn of Grant	1999-10-25	1.95	24	Reprints classic story with new framing pages.
1249	173	772	Reborn of Stone	2010-10-11	0.10	44	Reprints classic story with new framing pages.
1250	223	747	Dawn of Kane	1970-08-04	2.50	40	Double-sized anniversary issue.
1251	238	587	Reborn of Cole	1953-10-03	1.00	32	Direct edition only; no newsstand version.
1252	240	136	Reckoning of Holt	2021-05-02	1.00	28	High print run; common in collections.
1253	278	346	Reborn of Ward	1970-08-20	0.12	100	Low distribution; considered scarce.
1254	186	676	Chaos of Price	2000-01-21	0.10	28	Low distribution; considered scarce.
1255	292	329	Chaos of Cross	2019-08-23	3.99	64	Key first appearance issue.
1256	226	478	Dawn of Nash	1956-05-25	4.99	80	High print run; common in collections.
1257	210	594	Shadows of Holt	1947-04-04	1.50	28	Contains bonus pin-up gallery.
1258	93	785	Chaos of Holt	2021-06-12	4.99	32	High print run; common in collections.
1259	90	633	Dawn of Vale	1983-08-04	0.20	24	Controversial issue banned in three states.
1260	260	594	Eclipse of Drake	2015-07-03	0.75	24	Low distribution; considered scarce.
1261	132	695	Inferno of Grant	1944-06-12	0.12	100	High print run; common in collections.
1262	180	80	Resurgence of Fox	1986-10-18	0.20	80	Landmark story milestone.
1263	122	334	Reborn of Nash	1962-04-22	2.99	28	Direct edition only; no newsstand version.
1264	145	26	Eclipse of Price	2016-08-09	1.95	44	Direct edition only; no newsstand version.
1265	192	302	Shattered of Morgan	1997-07-22	0.35	44	Key first appearance issue.
1266	149	606	Reckoning of Kane	1990-09-24	0.50	44	Double-sized anniversary issue.
1267	261	596	Inferno of Stone	1970-07-29	2.50	100	Key first appearance issue.
1268	77	781	Shadows of Voss	2015-07-19	0.75	100	Double-sized anniversary issue.
1269	295	562	Legacy of Grant	1945-07-14	0.20	80	Key first appearance issue.
1270	242	533	Fracture of Flynn	2019-07-11	1.00	36	Reprints classic story with new framing pages.
1271	151	250	Eclipse of Vale	1987-06-08	1.95	36	Contains bonus pin-up gallery.
1272	162	119	Revelation of Fox	1968-10-12	2.99	44	Landmark story milestone.
1273	181	518	Shadows of Nash	2001-02-20	4.99	100	High print run; common in collections.
1274	230	236	Reborn of Steele	1969-05-24	0.75	48	Reprints classic story with new framing pages.
1275	71	267	Vendetta of Flynn	2023-04-30	1.50	28	Landmark story milestone.
1276	210	518	Fallen of Hunt	1979-10-10	4.99	36	Controversial issue banned in three states.
1277	233	171	Rising of Crane	2016-02-01	1.00	80	Contains bonus pin-up gallery.
1278	52	35	Legacy of Morgan	2010-11-01	0.35	28	Controversial issue banned in three states.
1279	264	398	Legacy of Nash	2024-11-15	0.25	48	Double-sized anniversary issue.
1280	124	301	Rising of Flynn	1956-12-20	1.50	100	Reprints classic story with new framing pages.
1281	56	47	Shadows of Nash	1962-01-19	3.99	48	Contains bonus pin-up gallery.
1282	224	776	Oblivion of Steele	2004-12-22	0.35	100	Double-sized anniversary issue.
1283	43	8	Reborn of Hunt	1981-08-29	1.95	64	Direct edition only; no newsstand version.
1284	165	181	Resurgence of Hunt	1981-06-17	1.00	28	High print run; common in collections.
1285	153	350	Dawn of Hunt	1973-07-13	2.99	40	Part of a crossover event.
1286	197	776	Convergence of Steele	1951-07-28	0.12	36	Direct edition only; no newsstand version.
1287	266	589	Shattered of Flynn	1950-06-25	0.20	44	Low distribution; considered scarce.
1288	85	295	Chaos of Stark	2001-04-26	3.99	36	Controversial issue banned in three states.
1289	148	621	Rising of Vale	1995-08-21	1.00	32	Landmark story milestone.
1290	106	521	Convergence of Morgan	2005-03-11	0.12	80	Double-sized anniversary issue.
1291	100	501	Reckoning of Nash	1985-02-24	0.50	40	Reprints classic story with new framing pages.
1292	219	534	Fallen of Fox	2002-11-28	1.25	28	Landmark story milestone.
1293	228	506	Chaos of Voss	2007-05-23	0.25	40	Landmark story milestone.
1294	182	763	Revelation of Voss	1960-02-04	1.50	32	Double-sized anniversary issue.
1295	172	465	Resurgence of Voss	1980-03-11	1.50	24	Direct edition only; no newsstand version.
1296	52	534	Eclipse of Stone	2023-10-25	0.12	24	High print run; common in collections.
1297	71	386	Revelation of Stone	2021-08-09	1.00	64	Controversial issue banned in three states.
1298	249	752	Oblivion of Burns	2018-02-05	0.25	36	Landmark story milestone.
1299	265	741	Uprising of Morgan	2020-11-24	2.99	28	Contains bonus pin-up gallery.
1300	286	728	Convergence of Drake	2015-09-05	2.99	40	Reprints classic story with new framing pages.
1301	195	654	Inferno of Stark	1995-01-22	0.35	40	High print run; common in collections.
1302	150	502	Nemesis of Price	2017-10-04	1.95	80	Contains bonus pin-up gallery.
1303	152	225	Rising of Burns	1963-08-30	2.99	64	Part of a crossover event.
1304	127	436	Rising of Cross	2022-11-09	3.99	44	Landmark story milestone.
1305	178	408	Fallen of Stark	2006-07-12	4.99	100	Direct edition only; no newsstand version.
1306	121	298	Chaos of Cole	1990-04-20	0.50	48	Key first appearance issue.
1307	288	331	Chaos of Flynn	2024-08-15	2.99	48	Contains bonus pin-up gallery.
1308	218	267	Dawn of Holt	2022-06-21	4.99	36	Part of a crossover event.
1309	24	459	Legacy of Vale	1969-09-23	0.35	80	High print run; common in collections.
1310	57	626	Eclipse of Steele	2023-07-06	0.10	24	Direct edition only; no newsstand version.
1311	47	722	Eclipse of Nash	1980-05-17	0.15	24	Double-sized anniversary issue.
1312	108	549	Uprising of Cross	1950-01-11	2.50	36	Low distribution; considered scarce.
1313	83	340	Legacy of Stone	2019-02-05	0.75	24	Key first appearance issue.
1314	11	105	Resurgence of Ward	2011-11-27	4.99	24	Controversial issue banned in three states.
1315	145	25	Revelation of Vale	2018-05-19	0.12	40	Landmark story milestone.
1316	194	411	Fallen of Holt	2008-09-12	0.15	28	Landmark story milestone.
1317	259	721	Legacy of Morgan	2023-03-13	0.10	80	Reprints classic story with new framing pages.
1318	78	754	Reborn of Ward	1948-02-22	0.50	100	Low distribution; considered scarce.
1319	166	525	Reckoning of Burns	2017-02-21	1.00	64	High print run; common in collections.
1320	52	672	Reborn of Stark	2013-12-04	2.50	40	Direct edition only; no newsstand version.
1321	48	417	Descent of Holt	1983-12-21	4.99	40	Double-sized anniversary issue.
1322	260	392	Reckoning of Stark	1997-12-11	2.50	44	Double-sized anniversary issue.
1323	56	230	Reborn of Morgan	1960-07-15	2.50	36	Contains bonus pin-up gallery.
1324	190	577	Rising of Burns	2023-05-07	1.50	32	Landmark story milestone.
1325	49	174	Uprising of Stark	1995-02-28	0.75	28	Controversial issue banned in three states.
1326	207	485	Resurgence of Hunt	2020-08-27	0.75	24	Contains bonus pin-up gallery.
1327	130	319	Eclipse of Steele	2015-03-28	0.12	44	Reprints classic story with new framing pages.
1328	209	275	Uprising of Grant	1966-07-02	4.99	80	Contains bonus pin-up gallery.
1329	161	330	Fracture of Stark	2000-02-24	0.15	28	Direct edition only; no newsstand version.
1330	40	131	Reckoning of Cross	1947-02-09	0.20	32	High print run; common in collections.
1331	225	40	Legacy of Stark	1978-02-06	0.35	80	Contains bonus pin-up gallery.
1332	72	409	Reckoning of Burns	1978-10-03	0.20	48	Low distribution; considered scarce.
1333	139	331	Shattered of Nash	2013-06-09	0.35	32	Low distribution; considered scarce.
1334	268	629	Inferno of Cole	1990-04-17	1.00	64	Contains bonus pin-up gallery.
1335	108	765	Fallen of Cross	1949-11-07	4.99	24	Part of a crossover event.
1336	214	154	Oblivion of Voss	1940-01-05	0.10	40	High print run; common in collections.
1337	103	97	Descent of Fox	1957-10-13	1.50	28	Key first appearance issue.
1338	240	161	Shadows of Nash	2023-05-02	0.75	44	Key first appearance issue.
1339	99	292	Legacy of Hunt	1973-08-20	1.25	44	Reprints classic story with new framing pages.
1340	207	575	Descent of Stone	2004-06-05	0.15	100	Controversial issue banned in three states.
1341	53	222	Chaos of Cross	2015-10-11	1.00	100	Landmark story milestone.
1342	65	602	Nemesis of Flynn	2000-11-10	1.00	100	Contains bonus pin-up gallery.
1343	108	3	Revelation of Stone	1948-12-10	0.15	100	Controversial issue banned in three states.
1344	74	487	Reckoning of Flynn	2017-11-06	0.15	24	Controversial issue banned in three states.
1345	262	451	Legacy of Stark	2015-06-03	1.50	40	Double-sized anniversary issue.
1346	61	574	Nemesis of Ward	1983-05-27	2.50	64	Part of a crossover event.
1347	160	325	Resurgence of Voss	1953-06-18	0.50	32	Low distribution; considered scarce.
1348	74	574	Fracture of Stark	2020-11-25	1.00	28	Double-sized anniversary issue.
1349	223	183	Reckoning of Nash	1968-10-23	3.99	44	Direct edition only; no newsstand version.
1350	110	392	Inferno of Cross	2015-02-22	0.10	36	Contains bonus pin-up gallery.
1351	185	200	Reckoning of Hunt	1998-11-25	1.25	44	Landmark story milestone.
1352	189	515	Reckoning of Price	2020-11-05	1.00	24	Low distribution; considered scarce.
1353	246	45	Chaos of Holt	2000-11-12	0.12	100	Key first appearance issue.
1354	242	648	Fracture of Stark	2023-04-03	0.35	64	Double-sized anniversary issue.
1355	54	379	Reckoning of Price	1991-09-18	0.25	32	Controversial issue banned in three states.
1356	43	123	Dawn of Fox	2005-08-22	0.12	44	Landmark story milestone.
1357	279	199	Shattered of Morgan	1960-03-23	1.50	44	Controversial issue banned in three states.
1358	188	15	Nemesis of Crane	2002-04-28	0.12	28	High print run; common in collections.
1359	257	747	Chaos of Voss	1993-04-23	0.35	64	Key first appearance issue.
1360	142	204	Resurgence of Crane	2007-08-26	0.35	24	Low distribution; considered scarce.
1361	141	360	Rising of Flynn	1995-02-23	3.99	100	Landmark story milestone.
1362	290	475	Shadows of Kane	2006-11-12	0.15	32	Landmark story milestone.
1363	96	606	Reckoning of Cross	2011-03-30	0.10	36	Part of a crossover event.
1364	236	742	Revelation of Burns	1965-04-17	0.50	32	Low distribution; considered scarce.
1365	28	723	Vendetta of Cross	1998-01-06	1.00	32	Reprints classic story with new framing pages.
1366	162	232	Uprising of Holt	1961-04-14	0.50	32	Low distribution; considered scarce.
1367	133	271	Shadows of Stark	2005-12-06	1.95	100	Part of a crossover event.
1368	179	536	Fracture of Cross	2019-10-16	0.12	100	Direct edition only; no newsstand version.
1369	80	583	Uprising of Crane	2023-02-17	1.95	40	High print run; common in collections.
1370	176	565	Chaos of Voss	2012-10-28	0.50	40	High print run; common in collections.
1371	240	33	Rising of Cole	2021-06-18	0.35	64	Controversial issue banned in three states.
1372	240	331	Inferno of Hunt	2023-04-16	2.50	100	Key first appearance issue.
1373	166	645	Inferno of Morgan	1988-05-20	0.35	48	Contains bonus pin-up gallery.
1374	172	664	Rising of Cross	1981-07-21	1.95	40	Controversial issue banned in three states.
1375	240	191	Reckoning of Fox	2023-01-24	3.99	100	Reprints classic story with new framing pages.
1376	223	485	Revelation of Holt	1969-12-16	1.95	100	Part of a crossover event.
1377	248	308	Dawn of Vale	2014-07-02	0.20	48	Direct edition only; no newsstand version.
1378	138	411	Reborn of Morgan	1996-10-23	0.35	80	Controversial issue banned in three states.
1379	154	715	Resurgence of Stone	2017-10-09	0.25	32	Part of a crossover event.
1380	28	93	Vendetta of Steele	2024-07-11	1.95	64	Direct edition only; no newsstand version.
1381	85	1	Fallen of Stone	2016-08-29	0.35	40	Low distribution; considered scarce.
1382	42	242	Uprising of Crane	2019-01-27	0.15	36	Controversial issue banned in three states.
1383	285	6	Oblivion of Cross	1981-10-15	1.95	28	Contains bonus pin-up gallery.
1384	282	716	Uprising of Stark	1993-09-04	2.50	64	High print run; common in collections.
1385	50	132	Eclipse of Steele	1972-10-09	2.50	44	Low distribution; considered scarce.
1386	218	404	Descent of Voss	2024-09-11	1.95	64	Reprints classic story with new framing pages.
1387	14	624	Convergence of Vale	1992-12-21	1.95	44	Part of a crossover event.
1388	257	2	Shattered of Price	2008-06-18	2.50	28	High print run; common in collections.
1389	71	193	Dawn of Stone	2013-11-08	1.25	48	Landmark story milestone.
1390	174	670	Convergence of Crane	2017-01-28	0.25	40	Low distribution; considered scarce.
1391	199	36	Chaos of Crane	1959-10-13	0.35	32	Direct edition only; no newsstand version.
1392	265	109	Fracture of Voss	2018-11-04	1.95	28	Direct edition only; no newsstand version.
1393	7	327	Fallen of Hunt	1956-08-10	2.50	64	Key first appearance issue.
1394	249	687	Nemesis of Crane	2023-05-02	0.12	40	Direct edition only; no newsstand version.
1395	133	619	Fracture of Cole	2002-04-20	1.95	64	Part of a crossover event.
1396	274	374	Rising of Cross	2012-11-24	2.99	80	Direct edition only; no newsstand version.
1397	41	8	Eclipse of Hunt	1995-09-30	1.00	36	Double-sized anniversary issue.
1398	233	50	Fracture of Burns	2018-06-09	0.12	28	Contains bonus pin-up gallery.
1399	236	52	Shattered of Nash	1990-12-08	1.00	48	Part of a crossover event.
1400	152	25	Descent of Holt	2023-10-18	0.35	40	Part of a crossover event.
1401	214	458	Eclipse of Burns	1938-03-13	0.12	100	Landmark story milestone.
1402	183	545	Nemesis of Vale	1943-10-27	0.35	28	Double-sized anniversary issue.
1403	49	745	Fallen of Stark	1975-08-28	2.99	40	Part of a crossover event.
1404	235	633	Revelation of Cole	2019-06-15	3.99	24	Landmark story milestone.
1405	168	40	Fallen of Price	1983-09-21	0.20	48	Double-sized anniversary issue.
1406	41	653	Vendetta of Crane	2004-02-26	2.50	24	Controversial issue banned in three states.
1407	132	669	Shadows of Crane	2007-09-27	0.20	36	Reprints classic story with new framing pages.
1408	134	631	Resurgence of Grant	2009-08-07	0.75	24	Part of a crossover event.
1409	294	221	Legacy of Holt	2015-04-22	0.35	40	Double-sized anniversary issue.
1410	24	409	Convergence of Burns	1971-05-23	1.00	24	Direct edition only; no newsstand version.
1411	107	425	Fallen of Holt	1989-06-03	1.00	64	Reprints classic story with new framing pages.
1412	163	227	Revelation of Morgan	1952-02-02	1.50	36	Landmark story milestone.
1413	148	472	Reborn of Crane	2011-05-02	1.50	80	Direct edition only; no newsstand version.
1414	244	13	Eclipse of Flynn	2022-01-06	1.50	44	Contains bonus pin-up gallery.
1415	78	761	Oblivion of Stone	1956-05-12	0.35	48	Low distribution; considered scarce.
1416	207	677	Reborn of Voss	1994-06-13	4.99	80	Part of a crossover event.
1417	43	766	Resurgence of Nash	1986-08-15	1.25	40	Part of a crossover event.
1418	232	479	Reckoning of Steele	2001-07-07	0.35	100	Part of a crossover event.
1419	290	426	Reckoning of Burns	1995-09-06	4.99	36	Direct edition only; no newsstand version.
1420	276	388	Shattered of Kane	1971-12-15	0.20	48	High print run; common in collections.
1421	109	585	Vendetta of Cross	2018-03-30	0.35	48	Double-sized anniversary issue.
1422	210	770	Uprising of Crane	1973-08-01	1.00	44	Part of a crossover event.
1423	55	704	Eclipse of Cole	2000-08-04	2.50	36	Direct edition only; no newsstand version.
1424	254	476	Vendetta of Fox	2018-12-13	0.35	32	Direct edition only; no newsstand version.
1425	148	546	Eclipse of Fox	1984-02-24	0.35	28	Direct edition only; no newsstand version.
1426	298	429	Legacy of Crane	1957-04-29	0.50	24	Reprints classic story with new framing pages.
1427	115	625	Shattered of Cole	1959-06-07	0.15	100	Reprints classic story with new framing pages.
1428	210	333	Shattered of Vale	1944-01-19	0.35	100	Contains bonus pin-up gallery.
1429	47	24	Shattered of Ward	1978-01-28	0.50	32	Contains bonus pin-up gallery.
1430	189	180	Oblivion of Stone	2020-09-07	1.50	32	Low distribution; considered scarce.
1431	34	212	Reborn of Fox	1955-05-07	3.99	36	Reprints classic story with new framing pages.
1432	228	182	Fracture of Cole	1998-11-07	0.20	100	Part of a crossover event.
1433	82	474	Shadows of Morgan	1962-12-20	0.12	48	Double-sized anniversary issue.
1434	241	73	Legacy of Holt	2022-04-28	0.20	100	Double-sized anniversary issue.
1435	13	493	Dawn of Burns	2011-05-05	2.50	24	Part of a crossover event.
1436	205	645	Fracture of Crane	2010-09-27	0.20	28	Controversial issue banned in three states.
1437	135	772	Rising of Cross	2023-07-03	1.95	48	Part of a crossover event.
1438	73	495	Uprising of Holt	1965-11-26	0.20	44	Landmark story milestone.
1439	235	727	Oblivion of Vale	2024-03-02	1.00	44	Low distribution; considered scarce.
1440	228	462	Chaos of Hunt	2002-10-31	1.00	100	Key first appearance issue.
1441	72	535	Vendetta of Morgan	1966-08-22	0.75	44	Reprints classic story with new framing pages.
1442	186	315	Convergence of Hunt	2001-01-23	1.25	64	Contains bonus pin-up gallery.
1443	151	762	Fallen of Steele	1970-06-19	1.25	48	Low distribution; considered scarce.
1444	117	217	Reborn of Burns	2014-04-25	0.25	100	Key first appearance issue.
1445	133	739	Resurgence of Cole	2005-01-31	2.50	64	Reprints classic story with new framing pages.
1446	88	660	Fallen of Hunt	2005-09-20	1.50	80	Part of a crossover event.
1447	194	664	Convergence of Cole	2004-11-19	4.99	32	Contains bonus pin-up gallery.
1448	195	685	Shadows of Flynn	1975-04-12	0.75	40	High print run; common in collections.
1449	115	285	Shattered of Kane	1960-06-19	0.50	44	Contains bonus pin-up gallery.
1450	236	654	Reckoning of Cole	2009-01-31	0.75	36	Part of a crossover event.
1451	17	642	Rising of Flynn	1974-11-16	0.15	40	Double-sized anniversary issue.
1452	274	760	Descent of Voss	2011-06-30	0.12	64	Reprints classic story with new framing pages.
1453	268	251	Chaos of Cross	1990-10-12	0.75	36	Contains bonus pin-up gallery.
1454	91	624	Chaos of Grant	2018-06-14	1.00	28	High print run; common in collections.
1455	33	536	Vendetta of Drake	1981-09-29	0.50	36	High print run; common in collections.
1456	300	489	Fracture of Kane	2021-08-18	0.12	44	Landmark story milestone.
1457	101	120	Fracture of Voss	2017-06-15	4.99	36	Landmark story milestone.
1458	278	221	Shattered of Stark	1977-03-21	1.25	100	Key first appearance issue.
1459	298	115	Fracture of Stone	1954-10-27	3.99	24	Low distribution; considered scarce.
1460	209	278	Oblivion of Cross	2019-12-14	1.50	80	Contains bonus pin-up gallery.
1461	264	661	Vendetta of Holt	2019-05-14	0.75	44	Low distribution; considered scarce.
1462	288	317	Fracture of Kane	2012-07-26	0.35	64	Key first appearance issue.
1463	164	482	Oblivion of Cross	2010-06-06	0.35	28	Direct edition only; no newsstand version.
1464	156	454	Eclipse of Grant	1953-06-26	0.35	36	Landmark story milestone.
1465	119	315	Resurgence of Burns	2002-10-13	1.50	80	Contains bonus pin-up gallery.
1466	53	308	Shattered of Stone	2013-09-18	0.25	44	Controversial issue banned in three states.
1467	99	406	Convergence of Cross	2017-10-04	0.35	44	Double-sized anniversary issue.
1468	243	799	Chaos of Vale	1990-05-09	1.00	64	Low distribution; considered scarce.
1469	190	314	Eclipse of Nash	2019-08-17	1.50	64	Low distribution; considered scarce.
1470	218	403	Legacy of Morgan	2024-04-26	2.50	24	Direct edition only; no newsstand version.
1471	182	144	Fracture of Holt	2010-12-09	0.10	36	High print run; common in collections.
1472	132	383	Reckoning of Flynn	1969-06-12	2.99	48	Part of a crossover event.
1473	286	221	Shattered of Cole	2015-06-22	3.99	40	Landmark story milestone.
1474	39	165	Eclipse of Stark	1999-10-25	4.99	24	Direct edition only; no newsstand version.
1475	250	287	Shattered of Hunt	1986-10-20	2.50	24	Landmark story milestone.
1476	29	283	Descent of Nash	1948-12-02	3.99	40	Landmark story milestone.
1477	242	768	Shadows of Flynn	2002-01-09	2.99	32	Controversial issue banned in three states.
1478	154	205	Descent of Voss	2016-10-01	3.99	36	Part of a crossover event.
1479	294	782	Chaos of Grant	2016-02-17	1.25	24	Controversial issue banned in three states.
1480	35	729	Eclipse of Nash	2010-12-03	3.99	36	Controversial issue banned in three states.
1481	165	234	Fracture of Nash	1981-08-17	1.50	36	Low distribution; considered scarce.
1482	131	144	Rising of Crane	1980-01-15	2.99	48	Contains bonus pin-up gallery.
1483	25	62	Resurgence of Nash	2001-05-28	0.10	100	Direct edition only; no newsstand version.
1484	17	335	Descent of Stark	1979-08-15	1.25	100	Part of a crossover event.
1485	35	579	Shadows of Grant	2007-06-04	0.20	80	Controversial issue banned in three states.
1486	263	588	Fracture of Price	1972-11-14	0.50	28	Direct edition only; no newsstand version.
1487	142	463	Fallen of Flynn	2004-06-12	0.15	32	Reprints classic story with new framing pages.
1488	174	541	Legacy of Morgan	2017-04-09	2.50	100	Low distribution; considered scarce.
1489	4	400	Reckoning of Morgan	1974-10-01	0.75	44	Direct edition only; no newsstand version.
1490	78	229	Reborn of Flynn	1951-10-22	3.99	36	Reprints classic story with new framing pages.
1491	182	591	Fallen of Stone	2017-02-19	0.25	36	Low distribution; considered scarce.
1492	93	27	Descent of Price	2020-07-25	0.12	32	Double-sized anniversary issue.
1493	179	336	Eclipse of Vale	1994-02-08	0.50	36	Low distribution; considered scarce.
1494	84	278	Revelation of Stone	1959-10-04	1.95	24	Controversial issue banned in three states.
1495	226	385	Reckoning of Fox	1961-07-10	0.50	48	Key first appearance issue.
1496	229	409	Uprising of Stone	1983-11-02	2.50	100	Landmark story milestone.
1497	48	519	Reborn of Cole	1981-11-08	0.20	32	High print run; common in collections.
1498	62	759	Shattered of Nash	1944-05-15	1.50	48	High print run; common in collections.
1499	108	520	Inferno of Stark	1948-07-04	1.00	80	Landmark story milestone.
1500	234	8	Nemesis of Crane	1990-02-03	2.50	28	Part of a crossover event.
1501	185	67	Legacy of Burns	1996-06-23	0.75	28	Direct edition only; no newsstand version.
1502	242	282	Eclipse of Drake	1996-09-16	0.25	36	Controversial issue banned in three states.
1503	290	132	Resurgence of Steele	1986-03-17	0.25	64	Key first appearance issue.
1504	32	758	Vendetta of Nash	1954-09-15	2.99	32	Direct edition only; no newsstand version.
1505	89	532	Fallen of Cross	2015-12-24	1.95	28	Controversial issue banned in three states.
1506	16	209	Vendetta of Ward	1971-07-31	1.95	40	Reprints classic story with new framing pages.
1507	165	27	Eclipse of Morgan	1979-02-28	4.99	24	Controversial issue banned in three states.
1508	209	553	Nemesis of Price	1970-03-04	0.35	32	Landmark story milestone.
1509	8	229	Shadows of Crane	2018-10-27	0.15	28	Contains bonus pin-up gallery.
1510	238	550	Fracture of Steele	1953-08-28	0.10	40	Contains bonus pin-up gallery.
1511	241	132	Eclipse of Grant	2020-11-18	1.95	100	Landmark story milestone.
1512	245	767	Reborn of Stone	2001-02-08	0.25	36	Double-sized anniversary issue.
1513	67	231	Shadows of Kane	2013-08-07	2.50	40	Reprints classic story with new framing pages.
1514	54	232	Chaos of Cross	2001-03-16	1.25	44	Contains bonus pin-up gallery.
1515	267	592	Chaos of Steele	1954-10-19	1.50	48	Part of a crossover event.
1516	75	755	Dawn of Ward	1996-12-27	0.12	36	Controversial issue banned in three states.
1517	8	650	Dawn of Vale	2014-03-17	0.35	48	Part of a crossover event.
1518	6	493	Oblivion of Nash	1995-10-31	0.50	100	Direct edition only; no newsstand version.
1519	232	465	Shattered of Holt	1960-04-10	3.99	28	Low distribution; considered scarce.
1520	264	346	Convergence of Holt	2020-07-26	1.50	64	Double-sized anniversary issue.
1521	234	99	Eclipse of Cole	1993-09-20	1.00	28	Part of a crossover event.
1522	219	27	Descent of Steele	2020-08-15	0.20	36	Contains bonus pin-up gallery.
1523	57	564	Vendetta of Steele	2001-05-24	1.95	40	Contains bonus pin-up gallery.
1524	224	85	Resurgence of Cross	2016-10-26	2.50	80	High print run; common in collections.
1525	73	795	Reckoning of Stone	1964-12-13	1.95	80	Reprints classic story with new framing pages.
1526	78	538	Dawn of Grant	1957-11-25	1.95	80	High print run; common in collections.
1527	272	384	Convergence of Kane	1994-06-25	0.35	100	High print run; common in collections.
1528	78	208	Chaos of Drake	1955-07-06	2.50	40	Direct edition only; no newsstand version.
1529	268	488	Fracture of Flynn	1992-09-21	0.25	40	Key first appearance issue.
1530	39	726	Descent of Burns	2000-07-19	0.50	100	Reprints classic story with new framing pages.
1531	35	774	Legacy of Steele	2007-05-02	0.25	64	Controversial issue banned in three states.
1532	125	164	Legacy of Ward	1983-07-21	0.50	36	Part of a crossover event.
1533	37	283	Fallen of Ward	1981-02-24	0.20	100	Controversial issue banned in three states.
1534	106	146	Chaos of Flynn	2003-12-22	0.10	28	Double-sized anniversary issue.
1535	160	106	Shattered of Stark	1953-06-20	0.75	64	Low distribution; considered scarce.
1536	64	158	Shadows of Flynn	2022-05-20	1.00	24	Direct edition only; no newsstand version.
1537	131	642	Fracture of Crane	1984-01-23	0.35	64	Low distribution; considered scarce.
1538	116	106	Shadows of Price	1958-11-12	1.95	36	Contains bonus pin-up gallery.
1539	222	59	Rising of Holt	2007-12-01	1.00	40	Double-sized anniversary issue.
1540	169	683	Chaos of Nash	2010-10-28	0.15	24	Landmark story milestone.
1541	249	600	Oblivion of Vale	2018-09-21	2.99	40	Landmark story milestone.
1542	250	622	Reborn of Ward	1990-04-15	2.50	24	Reprints classic story with new framing pages.
1543	56	659	Rising of Hunt	1961-04-24	0.20	28	High print run; common in collections.
1544	185	689	Shattered of Crane	1999-07-05	2.50	24	Part of a crossover event.
1545	226	588	Resurgence of Drake	1976-08-31	2.50	48	Key first appearance issue.
1546	111	186	Reckoning of Flynn	1970-05-11	0.20	40	Direct edition only; no newsstand version.
1547	15	260	Inferno of Nash	2019-03-30	1.95	36	Low distribution; considered scarce.
1548	229	333	Fracture of Holt	1975-01-27	0.35	36	Double-sized anniversary issue.
1549	281	330	Nemesis of Nash	2020-07-16	0.35	64	Landmark story milestone.
1550	171	632	Descent of Vale	2016-11-21	1.50	40	Landmark story milestone.
1551	47	416	Eclipse of Price	1979-08-02	4.99	32	Direct edition only; no newsstand version.
1552	104	725	Oblivion of Nash	2011-12-09	1.50	64	Part of a crossover event.
1553	82	331	Reckoning of Kane	1956-02-14	0.50	100	Low distribution; considered scarce.
1554	260	775	Descent of Grant	2002-07-29	0.35	48	Reprints classic story with new framing pages.
1555	39	96	Shadows of Price	1995-10-27	2.50	40	Controversial issue banned in three states.
1556	175	363	Nemesis of Steele	1977-12-22	2.50	28	Low distribution; considered scarce.
1557	292	332	Revelation of Fox	1993-09-08	0.12	36	Double-sized anniversary issue.
1558	80	27	Oblivion of Vale	2011-04-13	0.75	36	High print run; common in collections.
1559	226	149	Reckoning of Burns	1965-09-08	0.75	24	Reprints classic story with new framing pages.
1560	248	425	Descent of Grant	2014-12-03	0.50	48	Controversial issue banned in three states.
1561	266	410	Reborn of Ward	1964-01-22	1.00	44	Low distribution; considered scarce.
1562	221	374	Revelation of Flynn	1985-01-28	1.95	28	Controversial issue banned in three states.
1563	165	253	Descent of Hunt	1982-12-09	0.25	28	Double-sized anniversary issue.
1564	244	322	Rising of Price	2021-01-06	0.75	44	Double-sized anniversary issue.
1565	115	276	Reborn of Drake	1988-09-28	3.99	100	Contains bonus pin-up gallery.
1566	255	447	Shadows of Cross	1950-08-17	0.10	80	Contains bonus pin-up gallery.
1567	287	59	Inferno of Stark	1959-08-03	0.25	28	Part of a crossover event.
1568	34	283	Reborn of Holt	1963-01-23	0.10	100	Contains bonus pin-up gallery.
1569	221	406	Uprising of Fox	1983-10-01	1.25	80	Low distribution; considered scarce.
1570	170	584	Resurgence of Crane	1950-04-22	0.25	80	Reprints classic story with new framing pages.
1571	162	625	Dawn of Nash	1952-02-25	0.20	28	Reprints classic story with new framing pages.
1572	33	424	Convergence of Stone	1983-12-21	0.75	100	Controversial issue banned in three states.
1573	93	665	Oblivion of Kane	2020-03-01	1.50	28	Landmark story milestone.
1574	207	718	Nemesis of Crane	2018-10-01	2.50	64	Controversial issue banned in three states.
1575	176	99	Vendetta of Nash	2011-01-10	0.35	48	Low distribution; considered scarce.
1576	256	189	Chaos of Ward	1970-02-21	0.50	36	Part of a crossover event.
1577	42	463	Rising of Cole	2020-10-23	1.00	24	Reprints classic story with new framing pages.
1578	32	61	Inferno of Kane	1962-06-30	0.35	24	Double-sized anniversary issue.
1579	7	335	Nemesis of Burns	1953-02-08	0.10	100	Reprints classic story with new framing pages.
1580	192	177	Uprising of Price	1988-07-22	4.99	32	Double-sized anniversary issue.
1581	112	100	Fallen of Price	1977-12-22	1.95	100	Controversial issue banned in three states.
1582	226	520	Fallen of Fox	1963-12-18	0.10	100	Key first appearance issue.
1583	276	124	Vendetta of Burns	1988-12-03	0.20	44	Controversial issue banned in three states.
1584	266	103	Oblivion of Stone	1945-07-05	0.25	100	Part of a crossover event.
1585	233	459	Rising of Grant	2018-03-07	0.15	44	High print run; common in collections.
1586	188	246	Oblivion of Stone	1968-09-06	2.50	24	Part of a crossover event.
1587	31	676	Reborn of Kane	2021-10-10	0.15	44	Double-sized anniversary issue.
1588	289	720	Descent of Cole	2002-11-25	2.50	80	High print run; common in collections.
1589	145	139	Fracture of Stone	2018-08-05	1.25	48	Direct edition only; no newsstand version.
1590	223	85	Oblivion of Morgan	1969-06-16	4.99	28	Part of a crossover event.
1591	288	625	Nemesis of Burns	2011-09-19	4.99	40	Key first appearance issue.
1592	271	43	Uprising of Voss	1953-08-30	1.25	100	Reprints classic story with new framing pages.
1593	278	657	Eclipse of Drake	1967-11-21	0.10	24	Low distribution; considered scarce.
1594	198	361	Descent of Drake	1964-11-20	2.99	80	Double-sized anniversary issue.
1595	92	380	Dawn of Stone	1988-08-22	0.20	64	Controversial issue banned in three states.
1596	114	328	Shadows of Stone	1978-12-24	4.99	36	Reprints classic story with new framing pages.
1597	8	391	Uprising of Kane	2012-01-06	1.25	24	High print run; common in collections.
1598	170	400	Revelation of Nash	1949-12-29	2.50	24	Controversial issue banned in three states.
1599	73	637	Chaos of Crane	1966-01-16	1.25	36	Low distribution; considered scarce.
1600	210	11	Legacy of Crane	2003-12-06	2.50	40	High print run; common in collections.
1601	250	615	Reckoning of Ward	1986-11-04	0.12	64	Controversial issue banned in three states.
1602	115	653	Rising of Kane	1953-04-29	0.35	64	Landmark story milestone.
1603	94	336	Convergence of Holt	2010-01-08	2.50	40	Double-sized anniversary issue.
1604	147	584	Chaos of Kane	1955-05-22	0.20	48	High print run; common in collections.
1605	45	510	Uprising of Steele	2020-10-08	0.12	64	Contains bonus pin-up gallery.
1606	56	235	Dawn of Ward	1958-08-17	0.35	28	Landmark story milestone.
1607	124	631	Inferno of Fox	1950-10-12	0.25	64	Reprints classic story with new framing pages.
1608	22	786	Uprising of Stone	1980-08-04	1.50	24	Reprints classic story with new framing pages.
1609	8	350	Chaos of Cross	2014-06-05	1.95	64	High print run; common in collections.
1610	29	390	Fallen of Burns	1949-03-12	0.15	36	Controversial issue banned in three states.
1611	100	674	Fracture of Morgan	1992-07-14	3.99	28	High print run; common in collections.
1612	271	571	Convergence of Steele	1950-08-13	1.50	24	Landmark story milestone.
1613	34	531	Descent of Morgan	1959-08-07	0.35	44	Part of a crossover event.
1614	20	107	Revelation of Morgan	1944-06-08	2.50	24	Reprints classic story with new framing pages.
1615	30	397	Reborn of Kane	2021-04-01	0.75	24	Reprints classic story with new framing pages.
1616	280	21	Oblivion of Hunt	2001-04-26	2.50	40	Reprints classic story with new framing pages.
1617	199	767	Revelation of Stark	1959-02-01	1.00	44	Contains bonus pin-up gallery.
1618	246	157	Fracture of Grant	2024-03-29	1.95	36	Controversial issue banned in three states.
1619	147	398	Chaos of Cross	1952-11-29	1.95	24	Direct edition only; no newsstand version.
1620	154	44	Fracture of Crane	1997-06-17	0.75	48	Controversial issue banned in three states.
1621	181	416	Legacy of Crane	1985-05-02	3.99	64	Contains bonus pin-up gallery.
1622	199	373	Eclipse of Flynn	1959-05-26	2.50	32	Double-sized anniversary issue.
1623	106	223	Uprising of Hunt	2001-10-04	0.50	100	Part of a crossover event.
1624	238	783	Legacy of Nash	1955-02-24	1.25	36	Direct edition only; no newsstand version.
1625	73	112	Descent of Fox	1976-02-04	1.25	100	Direct edition only; no newsstand version.
1626	27	223	Eclipse of Grant	1989-06-22	0.35	48	Double-sized anniversary issue.
1627	222	454	Reckoning of Stone	1997-02-02	2.50	100	Controversial issue banned in three states.
1628	140	697	Reborn of Steele	1994-05-14	2.50	100	High print run; common in collections.
1629	78	325	Fracture of Vale	1955-03-24	0.25	64	Part of a crossover event.
1630	272	644	Dawn of Kane	2019-12-26	0.15	28	Key first appearance issue.
1631	5	340	Shadows of Flynn	1961-09-25	1.95	36	Controversial issue banned in three states.
1632	110	68	Inferno of Price	2016-06-13	1.50	100	Contains bonus pin-up gallery.
1633	244	721	Convergence of Burns	2012-03-10	1.25	28	Double-sized anniversary issue.
1634	82	156	Convergence of Crane	2021-10-25	0.20	80	Reprints classic story with new framing pages.
1635	210	576	Descent of Stark	1956-03-14	1.00	36	Landmark story milestone.
1636	76	100	Dawn of Steele	1992-12-16	2.50	64	Direct edition only; no newsstand version.
1637	245	786	Reckoning of Hunt	1986-08-24	1.95	64	Reprints classic story with new framing pages.
1638	293	459	Reckoning of Stark	2014-01-14	1.95	44	Landmark story milestone.
1639	190	182	Fallen of Price	2018-10-10	1.25	48	Controversial issue banned in three states.
1640	57	650	Eclipse of Burns	2004-11-03	0.15	44	Reprints classic story with new framing pages.
1641	254	637	Reborn of Crane	1985-09-19	0.35	44	Low distribution; considered scarce.
1642	99	287	Resurgence of Morgan	1995-01-23	4.99	44	Controversial issue banned in three states.
1643	27	245	Vendetta of Holt	1999-07-26	3.99	48	Part of a crossover event.
1644	21	768	Fracture of Voss	2021-01-22	1.50	80	Key first appearance issue.
1645	67	11	Reborn of Morgan	2018-12-31	1.25	48	High print run; common in collections.
1646	241	398	Dawn of Holt	2022-04-06	2.50	44	Part of a crossover event.
1647	263	417	Eclipse of Steele	2003-02-01	1.95	40	Double-sized anniversary issue.
1648	99	289	Chaos of Voss	1992-11-08	3.99	28	Part of a crossover event.
1649	261	24	Fallen of Kane	1955-07-19	0.75	28	Controversial issue banned in three states.
1650	192	158	Reborn of Vale	1988-06-16	0.15	28	Key first appearance issue.
1651	7	633	Shadows of Steele	1960-08-26	3.99	44	Landmark story milestone.
1652	63	722	Fallen of Stone	1995-07-10	0.15	32	Landmark story milestone.
1653	47	444	Revelation of Stone	1976-01-08	0.12	28	Direct edition only; no newsstand version.
1654	165	543	Uprising of Stark	1982-07-04	0.50	64	Reprints classic story with new framing pages.
1655	96	295	Reborn of Drake	2018-01-18	3.99	32	Double-sized anniversary issue.
1656	4	181	Uprising of Holt	1973-03-23	0.25	80	Reprints classic story with new framing pages.
1657	97	720	Shadows of Stone	1963-10-13	0.35	44	High print run; common in collections.
1658	84	651	Reborn of Burns	1959-06-05	2.99	80	Low distribution; considered scarce.
1659	112	257	Inferno of Vale	1985-04-07	0.10	40	Low distribution; considered scarce.
1660	83	64	Shadows of Stark	2017-05-13	1.95	24	Reprints classic story with new framing pages.
1661	221	691	Fracture of Morgan	1983-06-13	0.15	44	Reprints classic story with new framing pages.
1662	186	583	Chaos of Flynn	1990-12-15	3.99	44	Contains bonus pin-up gallery.
1663	190	308	Oblivion of Flynn	2023-08-09	0.50	36	Reprints classic story with new framing pages.
1664	88	708	Inferno of Crane	1998-12-16	3.99	64	Part of a crossover event.
1665	207	476	Fracture of Steele	2013-10-19	0.25	48	Direct edition only; no newsstand version.
1666	13	325	Nemesis of Steele	1984-07-04	2.50	44	Key first appearance issue.
1667	223	155	Reborn of Cross	1964-11-16	0.50	28	Key first appearance issue.
1668	201	154	Chaos of Flynn	2015-08-05	0.50	24	Contains bonus pin-up gallery.
1669	201	311	Descent of Holt	2008-07-20	0.75	36	Contains bonus pin-up gallery.
1670	256	446	Convergence of Stark	2000-10-31	0.12	44	Landmark story milestone.
1671	35	723	Oblivion of Price	2008-10-24	1.25	32	High print run; common in collections.
1672	266	222	Legacy of Stark	1960-03-03	0.10	40	Controversial issue banned in three states.
1673	174	319	Shattered of Crane	2017-10-07	0.20	100	Controversial issue banned in three states.
1674	272	350	Inferno of Steele	1999-08-24	1.95	100	Contains bonus pin-up gallery.
1675	33	458	Inferno of Crane	1981-02-06	0.75	36	Part of a crossover event.
1676	120	650	Oblivion of Holt	1989-01-04	1.50	100	Part of a crossover event.
1677	100	330	Reborn of Vale	1987-11-08	0.75	36	Contains bonus pin-up gallery.
1678	289	20	Eclipse of Cole	2000-07-15	0.20	48	Controversial issue banned in three states.
1679	165	542	Oblivion of Fox	1979-06-16	1.00	28	Contains bonus pin-up gallery.
1680	200	198	Chaos of Steele	2024-09-29	1.95	24	Contains bonus pin-up gallery.
1681	127	649	Reckoning of Flynn	2013-01-03	1.95	100	Contains bonus pin-up gallery.
1682	288	280	Eclipse of Stark	1996-07-22	1.50	100	Double-sized anniversary issue.
1683	103	662	Uprising of Price	1959-03-30	0.20	40	Key first appearance issue.
1684	100	517	Vendetta of Vale	1996-09-28	2.50	48	Key first appearance issue.
1685	153	210	Fallen of Burns	1970-12-05	0.10	24	Direct edition only; no newsstand version.
1686	41	477	Fallen of Fox	2005-07-15	2.50	80	Controversial issue banned in three states.
1687	228	322	Rising of Holt	2022-01-08	3.99	40	High print run; common in collections.
1688	233	167	Reborn of Steele	2017-08-06	1.50	24	Landmark story milestone.
1689	27	566	Oblivion of Nash	1992-04-28	0.25	44	Direct edition only; no newsstand version.
1690	282	644	Legacy of Flynn	1977-02-21	2.50	32	Part of a crossover event.
1691	18	290	Eclipse of Hunt	2021-03-21	0.12	80	Key first appearance issue.
1692	68	66	Shadows of Steele	1992-07-23	0.25	28	Double-sized anniversary issue.
1693	84	95	Inferno of Nash	1957-08-20	1.50	28	Direct edition only; no newsstand version.
1694	176	505	Nemesis of Grant	2010-05-23	0.12	80	Direct edition only; no newsstand version.
1695	203	562	Shadows of Stone	2000-12-14	3.99	32	Landmark story milestone.
1696	134	246	Dawn of Grant	2006-03-14	0.10	24	High print run; common in collections.
1697	246	44	Revelation of Vale	1984-11-25	0.25	32	Double-sized anniversary issue.
1698	164	397	Nemesis of Morgan	2006-03-30	1.25	64	Key first appearance issue.
1699	213	70	Dawn of Stone	2020-03-02	0.12	36	High print run; common in collections.
1700	299	8	Inferno of Voss	1974-10-03	1.95	80	Controversial issue banned in three states.
1701	204	156	Descent of Morgan	1989-10-10	1.25	40	Double-sized anniversary issue.
1702	192	398	Convergence of Stone	1998-06-17	1.00	44	High print run; common in collections.
1703	168	403	Rising of Burns	1978-09-05	3.99	24	Contains bonus pin-up gallery.
1704	263	210	Convergence of Kane	2001-05-25	0.12	48	Landmark story milestone.
1705	106	778	Reborn of Burns	2001-03-30	0.50	100	Low distribution; considered scarce.
1706	185	56	Revelation of Hunt	1998-03-15	1.00	36	Double-sized anniversary issue.
1707	13	13	Uprising of Cross	1999-10-20	1.50	36	Contains bonus pin-up gallery.
1708	199	469	Nemesis of Price	1956-05-05	0.35	64	Contains bonus pin-up gallery.
1709	288	293	Revelation of Voss	2016-10-07	0.20	24	Key first appearance issue.
1710	26	12	Chaos of Morgan	2019-10-22	1.25	64	Direct edition only; no newsstand version.
1711	291	100	Dawn of Nash	1960-02-27	0.50	36	Direct edition only; no newsstand version.
1712	191	287	Legacy of Morgan	2005-05-31	1.25	24	Landmark story milestone.
1713	155	270	Fracture of Stone	1995-08-04	0.20	24	Contains bonus pin-up gallery.
1714	90	116	Shadows of Vale	1977-08-24	3.99	100	Double-sized anniversary issue.
1715	140	24	Reborn of Stark	1989-01-11	0.15	32	High print run; common in collections.
1716	34	695	Nemesis of Morgan	1959-06-17	0.12	64	Direct edition only; no newsstand version.
1717	239	180	Reckoning of Hunt	2019-08-17	0.12	28	Low distribution; considered scarce.
1718	145	208	Chaos of Morgan	2020-05-16	1.00	36	High print run; common in collections.
1719	230	666	Dawn of Hunt	1960-01-16	2.99	80	Contains bonus pin-up gallery.
1720	119	294	Inferno of Voss	1999-01-23	1.95	64	Contains bonus pin-up gallery.
1721	279	383	Inferno of Grant	1957-09-04	0.25	44	Part of a crossover event.
1722	209	595	Nemesis of Nash	1981-08-10	3.99	44	Low distribution; considered scarce.
1723	76	692	Descent of Crane	1995-03-09	1.95	48	Landmark story milestone.
1724	130	341	Inferno of Fox	2009-02-01	3.99	80	Controversial issue banned in three states.
1725	22	519	Fallen of Price	1973-05-29	1.50	80	Controversial issue banned in three states.
1726	294	211	Nemesis of Voss	2011-07-26	2.99	28	Double-sized anniversary issue.
1727	279	533	Rising of Hunt	1954-12-10	0.10	40	Double-sized anniversary issue.
1728	85	701	Eclipse of Stark	2006-03-04	0.20	44	Part of a crossover event.
1729	281	536	Nemesis of Vale	2014-11-10	1.95	48	Landmark story milestone.
1730	116	660	Fracture of Steele	1960-03-08	0.50	24	Double-sized anniversary issue.
1731	56	148	Shadows of Burns	1960-10-11	0.75	48	Low distribution; considered scarce.
1732	108	654	Rising of Stone	1951-01-14	0.10	24	Key first appearance issue.
1733	152	213	Convergence of Voss	1965-11-11	0.15	40	Contains bonus pin-up gallery.
1734	61	367	Nemesis of Morgan	1987-06-19	1.25	44	Direct edition only; no newsstand version.
1735	192	312	Legacy of Price	1991-09-04	4.99	100	Reprints classic story with new framing pages.
1736	22	33	Oblivion of Flynn	1980-01-16	1.95	24	Low distribution; considered scarce.
1737	243	771	Descent of Kane	1989-08-10	2.99	100	Reprints classic story with new framing pages.
1738	180	28	Nemesis of Drake	2020-12-27	4.99	28	Contains bonus pin-up gallery.
1739	130	85	Revelation of Kane	2008-01-25	3.99	48	Part of a crossover event.
1740	124	481	Dawn of Flynn	1954-07-16	1.25	80	Contains bonus pin-up gallery.
1741	111	421	Rising of Morgan	1970-11-18	0.25	100	Key first appearance issue.
1742	260	71	Resurgence of Cross	2015-11-15	3.99	40	Reprints classic story with new framing pages.
1743	199	670	Dawn of Holt	1961-01-06	0.20	80	Contains bonus pin-up gallery.
1744	90	301	Convergence of Drake	1997-04-07	1.25	100	Part of a crossover event.
1745	219	704	Fallen of Voss	1972-11-02	0.50	64	Contains bonus pin-up gallery.
1746	128	397	Convergence of Ward	1973-04-04	0.12	40	Controversial issue banned in three states.
1747	115	700	Reborn of Stark	1977-07-05	0.75	64	Landmark story milestone.
1748	52	143	Fallen of Price	2011-09-09	0.10	64	Contains bonus pin-up gallery.
1749	188	441	Reckoning of Cole	2018-09-14	1.95	80	Landmark story milestone.
1750	215	35	Chaos of Crane	1989-08-28	2.99	28	Landmark story milestone.
1751	45	681	Inferno of Stark	1994-07-29	2.50	80	High print run; common in collections.
1752	71	25	Convergence of Voss	1979-11-10	0.35	36	Contains bonus pin-up gallery.
1753	280	571	Chaos of Stark	2014-09-30	0.15	32	Reprints classic story with new framing pages.
1754	212	574	Dawn of Vale	1954-05-24	0.50	32	Low distribution; considered scarce.
1755	69	12	Inferno of Drake	1970-05-20	0.10	28	Double-sized anniversary issue.
1756	137	544	Reckoning of Burns	1952-04-14	0.25	44	High print run; common in collections.
1757	246	219	Uprising of Stark	2018-12-10	4.99	64	High print run; common in collections.
1758	51	398	Descent of Grant	2012-11-13	0.15	32	Controversial issue banned in three states.
1759	262	779	Shadows of Stark	1956-01-17	0.15	100	Controversial issue banned in three states.
1760	127	772	Legacy of Nash	2022-01-22	0.75	40	Direct edition only; no newsstand version.
1761	31	44	Eclipse of Ward	2020-09-07	0.10	36	Part of a crossover event.
1762	201	621	Revelation of Steele	2015-02-02	4.99	100	Double-sized anniversary issue.
1763	209	774	Convergence of Vale	2023-12-17	1.25	64	Landmark story milestone.
1764	222	32	Legacy of Voss	2015-11-28	0.15	32	Key first appearance issue.
1765	190	403	Chaos of Fox	2021-02-10	1.50	40	Double-sized anniversary issue.
1766	168	482	Resurgence of Stark	1980-10-27	2.50	100	Double-sized anniversary issue.
1767	294	481	Eclipse of Voss	2011-07-17	4.99	44	Double-sized anniversary issue.
1768	265	647	Shadows of Holt	1999-04-19	1.00	40	Low distribution; considered scarce.
1769	263	321	Eclipse of Vale	1985-06-10	0.50	44	Low distribution; considered scarce.
1770	99	344	Resurgence of Crane	2023-01-30	1.00	40	Reprints classic story with new framing pages.
1771	218	787	Shattered of Steele	2020-02-11	1.25	36	Part of a crossover event.
1772	278	329	Uprising of Fox	1976-05-26	0.35	28	Low distribution; considered scarce.
1773	127	613	Eclipse of Cross	2012-08-12	4.99	44	High print run; common in collections.
1774	201	735	Chaos of Hunt	2015-11-12	3.99	80	Part of a crossover event.
1775	75	621	Shadows of Holt	1982-06-05	0.20	48	Double-sized anniversary issue.
1776	202	69	Uprising of Holt	2017-01-07	4.99	64	Double-sized anniversary issue.
1777	299	524	Reborn of Crane	1973-07-21	0.50	40	Key first appearance issue.
1778	219	502	Shattered of Kane	2019-05-08	4.99	48	Direct edition only; no newsstand version.
1779	161	144	Convergence of Kane	1989-09-18	1.95	24	Key first appearance issue.
1780	36	111	Descent of Grant	1977-06-11	1.00	32	Landmark story milestone.
1781	217	41	Reborn of Drake	1961-05-19	0.10	28	Part of a crossover event.
1782	142	441	Revelation of Vale	2000-05-17	0.75	100	Reprints classic story with new framing pages.
1783	293	566	Inferno of Vale	2014-12-28	0.25	24	Double-sized anniversary issue.
1784	300	781	Revelation of Cross	2020-11-20	2.50	36	Double-sized anniversary issue.
1785	9	94	Reborn of Price	1970-08-06	1.00	64	Landmark story milestone.
1786	49	417	Revelation of Vale	1981-01-16	3.99	100	Controversial issue banned in three states.
1787	89	287	Rising of Morgan	2016-03-27	0.75	40	Direct edition only; no newsstand version.
1788	297	615	Nemesis of Fox	1949-08-27	0.50	36	Landmark story milestone.
1789	42	730	Fracture of Fox	2021-08-01	0.25	48	Reprints classic story with new framing pages.
1790	195	555	Chaos of Stone	1976-01-25	4.99	48	Double-sized anniversary issue.
1791	176	22	Oblivion of Cole	2011-10-22	2.50	64	Reprints classic story with new framing pages.
1792	106	148	Shadows of Price	2003-03-08	2.50	32	Direct edition only; no newsstand version.
1793	107	322	Inferno of Ward	1993-11-21	1.00	36	Low distribution; considered scarce.
1794	119	615	Oblivion of Morgan	2006-07-06	0.75	28	Contains bonus pin-up gallery.
1795	12	586	Inferno of Nash	1996-06-11	2.50	24	Contains bonus pin-up gallery.
1796	224	457	Legacy of Voss	2024-06-25	2.99	40	Part of a crossover event.
1797	118	376	Chaos of Stark	1979-01-27	0.35	32	High print run; common in collections.
1798	300	530	Shattered of Cole	2021-10-22	0.50	24	Direct edition only; no newsstand version.
1799	187	779	Revelation of Voss	1963-01-29	0.35	28	Reprints classic story with new framing pages.
1800	284	257	Shadows of Cole	2016-02-21	1.00	64	Controversial issue banned in three states.
1801	151	447	Chaos of Cross	1970-03-06	0.75	48	Low distribution; considered scarce.
1802	86	69	Revelation of Voss	2021-05-08	0.12	100	Controversial issue banned in three states.
1803	148	482	Legacy of Cross	2008-07-30	0.75	24	High print run; common in collections.
1804	40	792	Rising of Holt	1945-05-18	0.35	80	Landmark story milestone.
1805	237	780	Inferno of Cross	2022-02-07	0.25	80	Controversial issue banned in three states.
1806	126	9	Eclipse of Cross	1983-10-29	1.00	80	Key first appearance issue.
1807	257	59	Nemesis of Steele	2001-04-25	0.35	24	Contains bonus pin-up gallery.
1808	80	248	Shattered of Nash	2004-12-07	1.00	64	High print run; common in collections.
1809	233	728	Rising of Vale	2016-12-24	0.35	100	Key first appearance issue.
1810	35	140	Reckoning of Burns	2009-02-11	3.99	80	Contains bonus pin-up gallery.
1811	203	555	Nemesis of Cole	2018-09-08	3.99	80	Part of a crossover event.
1812	296	770	Chaos of Cole	2022-07-18	2.99	32	Double-sized anniversary issue.
1813	256	38	Uprising of Voss	1973-04-29	1.95	40	Landmark story milestone.
1814	212	385	Vendetta of Nash	1978-04-28	0.10	44	Contains bonus pin-up gallery.
1815	102	17	Uprising of Crane	1973-06-01	0.25	64	Reprints classic story with new framing pages.
1816	72	406	Revelation of Steele	1973-07-18	0.10	36	Contains bonus pin-up gallery.
1817	130	409	Fracture of Fox	2016-12-01	1.95	36	Contains bonus pin-up gallery.
1818	67	53	Revelation of Steele	2016-08-30	0.20	40	Part of a crossover event.
1819	28	477	Nemesis of Crane	1996-09-22	0.15	100	Low distribution; considered scarce.
1820	182	565	Oblivion of Drake	1998-12-26	4.99	28	Part of a crossover event.
1821	170	318	Resurgence of Cross	1950-02-01	0.10	28	Controversial issue banned in three states.
1822	288	62	Reckoning of Cole	2002-02-04	0.50	80	Part of a crossover event.
1823	13	414	Eclipse of Price	2012-03-22	3.99	44	Reprints classic story with new framing pages.
1824	168	377	Dawn of Cole	1979-10-13	0.20	64	Contains bonus pin-up gallery.
1825	222	38	Descent of Hunt	2012-01-21	0.15	32	Direct edition only; no newsstand version.
1826	170	732	Fracture of Holt	1952-09-14	0.25	32	High print run; common in collections.
1827	48	283	Nemesis of Vale	1991-03-22	0.12	24	Low distribution; considered scarce.
1828	7	200	Legacy of Hunt	1955-12-26	0.50	48	Controversial issue banned in three states.
1829	219	582	Chaos of Stone	2012-01-29	0.10	28	Controversial issue banned in three states.
1830	20	745	Oblivion of Voss	1949-11-29	0.75	64	Controversial issue banned in three states.
1831	253	82	Fracture of Flynn	1978-07-24	1.95	64	Low distribution; considered scarce.
1832	296	562	Eclipse of Flynn	2024-04-06	0.25	100	Double-sized anniversary issue.
1833	143	609	Revelation of Vale	1991-07-10	0.10	48	Contains bonus pin-up gallery.
1834	140	522	Vendetta of Stark	1989-09-06	2.50	24	Reprints classic story with new framing pages.
1835	154	110	Fallen of Grant	2002-07-23	0.75	36	High print run; common in collections.
1836	238	101	Descent of Cole	1950-09-20	1.95	48	Direct edition only; no newsstand version.
1837	215	307	Shadows of Vale	1988-11-09	0.35	100	Contains bonus pin-up gallery.
1838	34	322	Dawn of Crane	1963-09-10	2.50	48	Controversial issue banned in three states.
1839	213	32	Eclipse of Nash	2019-04-23	0.20	40	High print run; common in collections.
1840	250	406	Reborn of Stone	1989-07-07	2.50	48	High print run; common in collections.
1841	147	626	Convergence of Flynn	1954-06-16	0.35	100	Part of a crossover event.
1842	193	104	Shadows of Voss	2005-09-19	0.10	32	Double-sized anniversary issue.
1843	220	95	Fallen of Drake	1999-01-18	0.10	64	Controversial issue banned in three states.
1844	17	299	Inferno of Nash	1962-12-27	0.15	24	Controversial issue banned in three states.
1845	159	103	Dawn of Hunt	1963-05-28	0.15	24	Reprints classic story with new framing pages.
1846	1	175	Nemesis of Stark	1990-04-01	0.20	40	Reprints classic story with new framing pages.
1847	150	539	Shadows of Price	2023-08-10	1.25	32	Landmark story milestone.
1848	237	267	Convergence of Cole	2022-05-26	0.20	64	Reprints classic story with new framing pages.
1849	115	291	Dawn of Ward	2008-10-25	1.50	32	Contains bonus pin-up gallery.
1850	232	522	Vendetta of Burns	1973-03-09	2.50	48	High print run; common in collections.
1851	159	335	Uprising of Vale	1970-12-10	3.99	32	Controversial issue banned in three states.
1852	19	61	Reborn of Kane	1973-10-12	0.25	28	Contains bonus pin-up gallery.
1853	65	741	Shadows of Burns	1967-05-26	1.50	44	Reprints classic story with new framing pages.
1854	123	446	Legacy of Kane	2007-03-16	1.25	36	Contains bonus pin-up gallery.
1855	18	161	Nemesis of Stone	2018-01-31	1.95	28	Key first appearance issue.
1856	17	399	Convergence of Stark	1968-04-24	3.99	48	Part of a crossover event.
1857	231	335	Legacy of Flynn	1980-12-17	0.35	24	Controversial issue banned in three states.
1858	129	96	Oblivion of Flynn	1992-08-26	0.25	24	Controversial issue banned in three states.
1859	123	619	Oblivion of Holt	2010-01-01	0.50	32	Direct edition only; no newsstand version.
1860	20	647	Inferno of Flynn	1938-06-01	1.95	44	Key first appearance issue.
1861	54	791	Resurgence of Stone	2011-08-29	0.50	32	Part of a crossover event.
1862	259	544	Nemesis of Cole	2013-02-18	0.50	48	Key first appearance issue.
1863	233	552	Fracture of Drake	2017-08-17	1.25	44	Key first appearance issue.
1864	209	643	Shadows of Stark	2018-11-14	2.99	64	Reprints classic story with new framing pages.
1865	293	323	Reborn of Vale	2014-08-03	3.99	40	Low distribution; considered scarce.
1866	20	685	Reborn of Holt	1948-04-17	2.50	40	Key first appearance issue.
1867	272	42	Revelation of Fox	1997-04-13	0.75	48	Key first appearance issue.
1868	221	78	Chaos of Grant	1983-04-08	2.99	24	Double-sized anniversary issue.
1869	157	680	Dawn of Stark	2021-09-06	0.50	80	Double-sized anniversary issue.
1870	148	241	Nemesis of Grant	1989-03-13	1.50	32	Double-sized anniversary issue.
1871	103	702	Legacy of Voss	1950-02-28	1.50	36	Contains bonus pin-up gallery.
1872	11	133	Chaos of Cross	2007-02-12	1.25	40	Direct edition only; no newsstand version.
1873	83	209	Convergence of Nash	2019-05-24	0.20	40	Low distribution; considered scarce.
1874	278	562	Shadows of Voss	1979-07-06	0.25	28	Key first appearance issue.
1875	123	798	Chaos of Cross	1969-12-02	0.20	64	Part of a crossover event.
1876	63	785	Descent of Fox	2015-06-14	0.20	64	Reprints classic story with new framing pages.
1877	143	86	Inferno of Voss	1991-05-28	1.95	32	Direct edition only; no newsstand version.
1878	97	257	Reckoning of Price	1973-03-26	0.15	28	Controversial issue banned in three states.
1879	75	165	Resurgence of Grant	1986-05-06	0.50	64	Part of a crossover event.
1880	16	399	Legacy of Kane	1969-10-25	2.50	36	Controversial issue banned in three states.
1881	98	653	Oblivion of Hunt	2022-12-06	0.15	36	Contains bonus pin-up gallery.
1882	286	397	Eclipse of Nash	2021-04-08	0.50	24	Key first appearance issue.
1883	232	4	Reborn of Nash	1957-11-16	0.10	44	Part of a crossover event.
1884	213	8	Eclipse of Fox	2022-05-29	0.15	32	Landmark story milestone.
1885	267	785	Rising of Hunt	1955-04-19	0.25	64	Contains bonus pin-up gallery.
1886	284	744	Eclipse of Kane	2017-07-18	0.12	44	High print run; common in collections.
1887	160	436	Vendetta of Drake	1953-07-03	0.20	24	Low distribution; considered scarce.
1888	71	389	Fallen of Holt	1992-03-04	1.50	48	Landmark story milestone.
1889	272	77	Oblivion of Burns	2003-04-27	1.25	48	Key first appearance issue.
1890	14	336	Convergence of Voss	1994-05-24	0.25	80	Reprints classic story with new framing pages.
1891	52	117	Rising of Holt	2016-02-17	1.50	44	Landmark story milestone.
1892	94	218	Reborn of Voss	2010-06-18	0.75	24	Low distribution; considered scarce.
1893	160	773	Descent of Voss	1953-07-17	1.25	80	Low distribution; considered scarce.
1894	52	771	Dawn of Burns	2017-01-19	2.99	28	Part of a crossover event.
1895	138	54	Fallen of Voss	2011-06-28	0.20	100	Key first appearance issue.
1896	55	489	Dawn of Stark	2020-12-21	1.95	48	Double-sized anniversary issue.
1897	55	163	Reborn of Grant	1964-09-17	0.75	28	Part of a crossover event.
1898	87	665	Reborn of Kane	1985-08-11	0.10	64	High print run; common in collections.
1899	65	756	Resurgence of Vale	1969-03-12	2.99	24	Double-sized anniversary issue.
1900	140	748	Uprising of Stark	1992-06-20	0.75	24	Direct edition only; no newsstand version.
1901	109	683	Nemesis of Stone	2023-11-17	1.25	44	Controversial issue banned in three states.
1902	208	422	Reborn of Burns	1996-12-31	1.00	36	Reprints classic story with new framing pages.
1903	64	262	Shattered of Stark	2020-11-06	0.10	28	Direct edition only; no newsstand version.
1904	98	708	Fallen of Hunt	2014-09-04	0.35	100	Landmark story milestone.
1905	128	729	Dawn of Vale	1978-12-11	0.75	24	Landmark story milestone.
1906	203	224	Chaos of Kane	1999-12-19	0.10	36	Landmark story milestone.
1907	8	110	Eclipse of Stone	2020-04-09	3.99	32	Controversial issue banned in three states.
1908	64	333	Legacy of Ward	2018-07-17	1.00	64	High print run; common in collections.
1909	75	399	Inferno of Stone	1980-04-10	0.75	64	Contains bonus pin-up gallery.
1910	141	51	Chaos of Morgan	1989-08-16	2.99	64	Controversial issue banned in three states.
1911	32	767	Fracture of Cole	1951-05-04	1.25	36	Direct edition only; no newsstand version.
1912	57	145	Vendetta of Holt	2008-11-18	0.35	48	Key first appearance issue.
1913	243	67	Reborn of Fox	1992-11-17	1.95	40	High print run; common in collections.
1914	231	705	Chaos of Stark	1984-01-05	2.50	40	Controversial issue banned in three states.
1915	246	449	Fallen of Morgan	1992-11-22	0.75	64	Direct edition only; no newsstand version.
1916	113	522	Fallen of Kane	1991-07-02	1.00	44	Double-sized anniversary issue.
1917	131	279	Resurgence of Burns	1983-06-08	2.50	24	Landmark story milestone.
1918	291	248	Vendetta of Holt	1957-10-22	0.75	80	Reprints classic story with new framing pages.
1919	295	188	Oblivion of Cole	1944-12-21	0.10	32	Key first appearance issue.
1920	168	430	Reborn of Flynn	1991-11-05	0.10	64	High print run; common in collections.
1921	96	751	Vendetta of Crane	2001-11-13	1.00	40	Reprints classic story with new framing pages.
1922	103	412	Shattered of Hunt	1957-01-19	1.95	28	Direct edition only; no newsstand version.
1923	242	201	Revelation of Flynn	2024-01-07	0.12	44	Part of a crossover event.
1924	242	546	Eclipse of Stark	2006-10-26	0.75	48	Double-sized anniversary issue.
1925	9	106	Reborn of Steele	1968-09-16	0.75	48	Key first appearance issue.
1926	105	423	Descent of Voss	2021-08-14	0.20	80	Contains bonus pin-up gallery.
1927	70	756	Uprising of Stone	1956-11-25	1.95	28	Key first appearance issue.
1928	132	602	Legacy of Kane	1944-01-19	1.00	100	Contains bonus pin-up gallery.
1929	108	349	Revelation of Price	1948-07-10	0.20	28	Low distribution; considered scarce.
1930	275	780	Revelation of Drake	2022-06-10	4.99	40	Double-sized anniversary issue.
1931	86	502	Uprising of Crane	1998-04-15	1.50	28	Landmark story milestone.
1932	258	235	Reborn of Holt	1992-01-27	0.10	48	Part of a crossover event.
1933	183	570	Convergence of Morgan	1953-02-22	0.20	100	Key first appearance issue.
1934	141	177	Convergence of Vale	1978-08-21	0.12	32	High print run; common in collections.
1935	108	136	Vendetta of Fox	1949-02-08	0.12	64	High print run; common in collections.
1936	69	121	Uprising of Nash	1966-05-09	1.25	48	Controversial issue banned in three states.
1937	33	163	Oblivion of Ward	1985-09-04	0.10	32	Part of a crossover event.
1938	18	180	Legacy of Kane	2019-12-24	0.15	32	High print run; common in collections.
1939	38	426	Rising of Crane	1970-10-17	0.75	32	Low distribution; considered scarce.
1940	267	569	Resurgence of Hunt	1957-01-02	1.50	64	Controversial issue banned in three states.
1941	273	581	Uprising of Fox	1998-04-04	2.99	32	Reprints classic story with new framing pages.
1942	228	324	Chaos of Price	2000-07-10	0.50	24	High print run; common in collections.
1943	208	385	Descent of Fox	1970-07-07	0.15	100	Landmark story milestone.
1944	65	236	Descent of Kane	1958-10-29	4.99	48	Reprints classic story with new framing pages.
1945	70	531	Convergence of Grant	1949-05-15	0.75	32	High print run; common in collections.
1946	26	622	Descent of Voss	2017-11-07	0.75	80	Double-sized anniversary issue.
1947	43	538	Descent of Voss	1998-06-04	1.00	40	Part of a crossover event.
1948	282	183	Dawn of Crane	1982-02-09	4.99	36	Controversial issue banned in three states.
1949	113	652	Shadows of Cole	2004-09-09	0.25	100	Contains bonus pin-up gallery.
1950	37	739	Descent of Voss	1989-12-08	1.50	64	Controversial issue banned in three states.
1951	142	346	Reckoning of Drake	2013-01-01	0.10	24	Key first appearance issue.
1952	16	331	Convergence of Hunt	1966-12-09	0.15	28	High print run; common in collections.
1953	247	450	Descent of Nash	1959-05-29	0.12	100	Key first appearance issue.
1954	77	321	Nemesis of Kane	2014-12-04	1.25	40	Low distribution; considered scarce.
1955	82	559	Fallen of Price	1948-08-18	4.99	40	Contains bonus pin-up gallery.
1956	268	155	Convergence of Burns	1988-11-09	0.12	44	Direct edition only; no newsstand version.
1957	241	520	Legacy of Fox	2018-06-15	0.10	24	Reprints classic story with new framing pages.
1958	26	678	Chaos of Vale	2015-01-06	2.50	44	Part of a crossover event.
1959	46	742	Resurgence of Holt	1966-02-09	0.25	48	Direct edition only; no newsstand version.
1960	289	242	Legacy of Steele	1992-10-04	1.00	80	High print run; common in collections.
1961	165	678	Dawn of Nash	1981-01-26	1.25	32	Reprints classic story with new framing pages.
1962	193	566	Dawn of Stark	2003-11-18	0.12	48	High print run; common in collections.
1963	124	617	Shattered of Grant	1950-03-15	3.99	100	Part of a crossover event.
1964	9	190	Fallen of Voss	1978-10-17	0.12	40	Key first appearance issue.
1965	63	259	Resurgence of Kane	2010-07-28	0.10	40	Low distribution; considered scarce.
1966	91	486	Oblivion of Vale	2024-02-21	0.50	48	High print run; common in collections.
1967	271	66	Nemesis of Holt	1952-08-19	0.75	32	Landmark story milestone.
1968	73	634	Vendetta of Cross	1972-12-11	1.25	48	Low distribution; considered scarce.
1969	82	249	Legacy of Steele	1942-11-10	1.95	80	Direct edition only; no newsstand version.
1970	110	318	Chaos of Voss	2014-03-03	3.99	24	Direct edition only; no newsstand version.
1971	150	400	Convergence of Nash	2024-05-01	1.95	40	Key first appearance issue.
1972	96	235	Inferno of Flynn	2015-02-03	0.35	40	High print run; common in collections.
1973	12	482	Nemesis of Burns	1982-10-18	2.99	40	Low distribution; considered scarce.
1974	263	544	Resurgence of Morgan	2016-08-25	0.75	28	Part of a crossover event.
1975	124	715	Resurgence of Cole	1953-06-22	0.35	40	Part of a crossover event.
1976	69	625	Dawn of Flynn	1971-03-23	0.12	40	Key first appearance issue.
1977	150	210	Uprising of Stone	2006-09-17	1.95	36	Double-sized anniversary issue.
1978	132	323	Rising of Ward	1995-09-03	0.75	32	Landmark story milestone.
1979	47	729	Shattered of Fox	1976-07-12	3.99	28	Double-sized anniversary issue.
1980	25	204	Revelation of Hunt	2008-05-29	0.15	36	Contains bonus pin-up gallery.
1981	111	415	Eclipse of Vale	1965-07-05	0.12	48	Key first appearance issue.
1982	40	769	Shattered of Cole	1945-06-21	4.99	44	Direct edition only; no newsstand version.
1983	49	513	Legacy of Grant	1990-09-17	0.10	24	Controversial issue banned in three states.
1984	107	28	Reckoning of Hunt	2007-05-27	0.20	44	Direct edition only; no newsstand version.
1985	58	612	Resurgence of Morgan	1991-06-23	0.75	48	Part of a crossover event.
1986	242	720	Oblivion of Holt	2024-07-25	1.25	100	Landmark story milestone.
1987	213	636	Uprising of Ward	2014-01-13	1.95	100	Part of a crossover event.
1988	69	79	Vendetta of Price	1966-08-26	0.15	28	Double-sized anniversary issue.
1989	295	112	Descent of Burns	1943-08-11	0.75	36	Direct edition only; no newsstand version.
1990	272	352	Reckoning of Hunt	2008-05-30	0.25	48	High print run; common in collections.
1991	88	741	Convergence of Stone	2016-04-12	0.25	28	High print run; common in collections.
1992	232	344	Eclipse of Crane	1965-09-03	0.15	28	Low distribution; considered scarce.
1993	19	134	Resurgence of Grant	1978-08-05	2.99	24	Part of a crossover event.
1994	11	244	Oblivion of Ward	2009-10-14	2.99	48	Key first appearance issue.
1995	266	120	Fallen of Crane	1942-04-22	0.10	24	High print run; common in collections.
1996	29	209	Inferno of Ward	1949-12-01	2.50	100	Landmark story milestone.
1997	14	158	Fracture of Voss	1996-08-30	1.50	36	Landmark story milestone.
1998	90	261	Eclipse of Nash	1986-10-22	0.12	48	Double-sized anniversary issue.
1999	282	447	Reborn of Kane	1984-03-23	4.99	64	Direct edition only; no newsstand version.
2000	288	147	Shattered of Stone	2018-11-23	1.00	40	Key first appearance issue.
2001	60	312	Descent of Morgan	1962-09-18	3.99	36	Part of a crossover event.
2002	153	489	Descent of Cole	1970-08-30	0.25	48	Key first appearance issue.
2003	109	661	Inferno of Price	2019-08-16	0.20	24	Landmark story milestone.
2004	190	708	Reckoning of Price	2023-01-24	0.12	80	Part of a crossover event.
2005	290	725	Shadows of Burns	1999-01-11	1.25	100	Controversial issue banned in three states.
2006	9	262	Reborn of Cross	1977-02-28	2.50	100	Reprints classic story with new framing pages.
2007	216	640	Reborn of Ward	2014-10-11	1.25	80	Reprints classic story with new framing pages.
2008	234	535	Vendetta of Steele	1990-07-03	1.95	100	Direct edition only; no newsstand version.
2009	292	151	Eclipse of Hunt	2001-02-18	0.20	40	Key first appearance issue.
2010	257	318	Reborn of Price	2009-11-26	0.50	32	High print run; common in collections.
2011	56	800	Revelation of Burns	1959-01-14	0.25	48	Direct edition only; no newsstand version.
2012	289	57	Legacy of Price	2002-07-23	0.10	80	Contains bonus pin-up gallery.
2013	80	656	Rising of Fox	2016-11-07	2.99	24	Contains bonus pin-up gallery.
2014	90	317	Descent of Vale	1986-09-08	0.75	44	Reprints classic story with new framing pages.
2015	186	533	Fallen of Grant	1998-12-11	0.10	40	Key first appearance issue.
2016	177	680	Rising of Steele	2003-04-13	2.99	44	Key first appearance issue.
2017	282	416	Reborn of Nash	1982-08-09	0.25	48	Low distribution; considered scarce.
2018	48	587	Nemesis of Nash	1991-02-26	2.99	28	High print run; common in collections.
2019	8	494	Legacy of Kane	2023-08-08	0.25	36	Double-sized anniversary issue.
2020	161	769	Rising of Holt	2009-03-21	0.50	40	Direct edition only; no newsstand version.
2021	278	247	Reborn of Burns	1967-05-05	1.00	24	Key first appearance issue.
2022	85	771	Revelation of Morgan	2017-06-17	0.10	80	Direct edition only; no newsstand version.
2023	201	399	Shadows of Drake	2024-11-08	0.20	48	Double-sized anniversary issue.
2024	104	84	Uprising of Price	2007-09-07	1.50	24	Key first appearance issue.
2025	34	541	Dawn of Price	1959-03-17	1.00	28	Low distribution; considered scarce.
2026	38	330	Dawn of Fox	2023-03-09	2.99	32	Double-sized anniversary issue.
2027	101	454	Legacy of Steele	2022-02-16	0.12	44	High print run; common in collections.
2028	144	18	Oblivion of Fox	1952-02-12	3.99	100	Low distribution; considered scarce.
2029	201	60	Fracture of Steele	2008-08-22	2.50	48	Controversial issue banned in three states.
2030	71	20	Descent of Voss	1999-11-30	4.99	64	Direct edition only; no newsstand version.
2031	25	579	Shattered of Voss	1968-06-10	1.00	24	Direct edition only; no newsstand version.
2032	269	547	Chaos of Voss	2011-02-17	0.50	36	High print run; common in collections.
2033	233	92	Fallen of Flynn	2017-04-20	1.95	32	High print run; common in collections.
2034	177	112	Fracture of Grant	2003-01-02	0.15	64	Key first appearance issue.
2035	105	169	Rising of Voss	2023-10-06	0.35	24	Direct edition only; no newsstand version.
2036	58	769	Legacy of Vale	1999-08-20	1.50	32	Contains bonus pin-up gallery.
2037	254	588	Inferno of Ward	2009-07-01	0.20	36	High print run; common in collections.
2038	230	684	Descent of Burns	1961-08-31	1.25	40	Reprints classic story with new framing pages.
2039	26	173	Reborn of Flynn	2019-01-26	0.12	32	Direct edition only; no newsstand version.
2040	151	45	Rising of Crane	1978-06-12	1.00	40	Key first appearance issue.
2041	122	210	Chaos of Kane	1984-07-11	2.50	64	Double-sized anniversary issue.
2042	56	475	Oblivion of Cole	1958-10-18	0.35	32	Landmark story milestone.
2043	8	655	Shadows of Stark	2014-08-15	0.35	28	High print run; common in collections.
2044	134	430	Convergence of Hunt	2019-04-20	1.50	64	Reprints classic story with new framing pages.
2045	225	777	Legacy of Vale	1983-06-29	0.75	28	Double-sized anniversary issue.
2046	91	698	Eclipse of Crane	2024-02-05	0.10	44	High print run; common in collections.
2047	294	461	Reckoning of Stark	2018-06-01	2.99	48	Landmark story milestone.
2048	233	717	Dawn of Ward	2018-09-06	4.99	36	Direct edition only; no newsstand version.
2049	266	16	Inferno of Morgan	1944-07-28	2.50	80	Controversial issue banned in three states.
2050	44	176	Convergence of Vale	2006-02-11	1.95	44	Controversial issue banned in three states.
2051	45	696	Inferno of Morgan	2006-04-16	1.50	80	Contains bonus pin-up gallery.
2052	54	415	Reborn of Steele	2001-11-19	0.15	80	Controversial issue banned in three states.
2053	38	143	Eclipse of Hunt	2008-03-12	2.50	64	Reprints classic story with new framing pages.
2054	21	605	Descent of Holt	2024-04-02	0.75	48	Reprints classic story with new framing pages.
2055	278	560	Reckoning of Cross	1970-06-23	0.25	24	Part of a crossover event.
2056	18	709	Revelation of Grant	2020-10-14	2.99	100	Low distribution; considered scarce.
2057	260	664	Fallen of Burns	2002-03-08	1.50	100	Double-sized anniversary issue.
2058	284	68	Shadows of Burns	2017-10-06	1.95	64	Double-sized anniversary issue.
2059	260	770	Dawn of Fox	2017-01-28	0.15	44	Controversial issue banned in three states.
2060	121	412	Fracture of Ward	2013-05-27	4.99	36	Double-sized anniversary issue.
2061	96	631	Fracture of Holt	1998-03-06	2.50	28	Reprints classic story with new framing pages.
2062	33	643	Fracture of Stark	1985-01-13	4.99	48	Double-sized anniversary issue.
2063	77	589	Legacy of Cole	2020-12-26	4.99	32	Controversial issue banned in three states.
2064	164	591	Uprising of Stark	2010-07-30	0.12	80	Part of a crossover event.
2065	269	409	Convergence of Vale	1996-01-06	1.95	24	Low distribution; considered scarce.
2066	16	774	Nemesis of Ward	1970-01-16	1.50	64	Reprints classic story with new framing pages.
2067	20	690	Rising of Cross	1939-05-17	1.00	80	Controversial issue banned in three states.
2068	176	275	Chaos of Cross	2012-02-07	2.50	64	Reprints classic story with new framing pages.
2069	202	144	Inferno of Price	2018-02-06	1.25	32	High print run; common in collections.
2070	69	758	Reborn of Holt	1971-12-22	2.50	36	High print run; common in collections.
2071	280	106	Eclipse of Ward	2023-09-08	0.35	40	Landmark story milestone.
2072	168	546	Eclipse of Stark	1975-05-16	0.35	44	Direct edition only; no newsstand version.
2073	86	176	Nemesis of Hunt	2023-10-25	0.75	36	Part of a crossover event.
2074	272	703	Inferno of Kane	2014-04-09	0.75	80	Landmark story milestone.
2075	287	401	Inferno of Nash	1960-12-09	0.10	64	Double-sized anniversary issue.
2076	135	573	Eclipse of Morgan	2021-05-02	1.50	64	Low distribution; considered scarce.
2077	134	8	Uprising of Burns	2006-01-21	0.20	80	Reprints classic story with new framing pages.
2078	39	493	Shattered of Stark	1988-02-27	0.35	24	High print run; common in collections.
2079	268	596	Revelation of Holt	1991-09-28	0.12	28	Part of a crossover event.
2080	108	315	Shadows of Flynn	1950-03-18	1.25	64	Landmark story milestone.
2081	168	208	Rising of Stone	1981-09-14	0.35	44	Reprints classic story with new framing pages.
2082	110	488	Resurgence of Kane	2017-09-15	0.75	48	Contains bonus pin-up gallery.
2083	163	17	Shattered of Holt	1951-07-07	0.25	28	Low distribution; considered scarce.
2084	45	795	Inferno of Cross	1974-02-27	3.99	48	Reprints classic story with new framing pages.
2085	271	713	Reborn of Cole	1949-09-07	4.99	80	Key first appearance issue.
2086	68	490	Reckoning of Holt	2015-12-25	1.95	32	High print run; common in collections.
2087	264	572	Inferno of Ward	2024-10-25	0.35	32	Part of a crossover event.
2088	286	427	Dawn of Flynn	2020-08-08	2.99	64	Double-sized anniversary issue.
2089	227	306	Convergence of Steele	1954-07-16	4.99	44	Double-sized anniversary issue.
2090	173	555	Eclipse of Hunt	2011-07-18	2.99	44	Part of a crossover event.
2091	148	515	Fallen of Burns	1991-12-22	0.20	28	Direct edition only; no newsstand version.
2092	171	140	Reckoning of Drake	2009-07-28	0.12	32	Low distribution; considered scarce.
2093	191	601	Revelation of Voss	2012-04-19	0.75	32	Landmark story milestone.
2094	167	71	Uprising of Morgan	2016-10-11	1.50	44	Contains bonus pin-up gallery.
2095	18	209	Legacy of Grant	2019-11-08	0.35	28	Low distribution; considered scarce.
2096	156	533	Resurgence of Price	1970-07-07	2.50	48	Reprints classic story with new framing pages.
2097	252	512	Revelation of Crane	1960-03-26	3.99	64	Low distribution; considered scarce.
2098	212	765	Reckoning of Steele	1957-06-06	1.95	80	Controversial issue banned in three states.
2099	189	215	Shadows of Cole	2021-03-25	0.50	32	Double-sized anniversary issue.
2100	55	137	Uprising of Voss	2007-02-15	0.25	36	Reprints classic story with new framing pages.
2101	74	8	Vendetta of Price	2023-03-27	0.15	24	Direct edition only; no newsstand version.
2102	5	533	Revelation of Crane	1965-01-23	1.00	64	Controversial issue banned in three states.
2103	105	567	Fracture of Nash	2023-01-09	0.10	80	Controversial issue banned in three states.
2104	242	532	Shadows of Fox	2014-02-14	0.35	32	Part of a crossover event.
2105	246	329	Chaos of Nash	2003-10-29	1.00	64	Controversial issue banned in three states.
2106	195	585	Dawn of Flynn	1987-11-20	0.25	100	Landmark story milestone.
2107	262	795	Fracture of Ward	2016-04-07	0.75	28	Direct edition only; no newsstand version.
2108	28	187	Fracture of Kane	2005-08-23	4.99	32	Landmark story milestone.
2109	235	221	Uprising of Fox	2019-06-02	0.50	100	Reprints classic story with new framing pages.
2110	96	334	Convergence of Cross	1998-04-25	0.25	100	Reprints classic story with new framing pages.
2111	110	176	Rising of Crane	2017-08-15	1.50	100	Landmark story milestone.
2112	156	567	Descent of Steele	1966-03-14	0.75	32	Part of a crossover event.
2113	187	592	Descent of Stone	1967-06-27	1.50	80	Low distribution; considered scarce.
2114	137	126	Oblivion of Fox	1951-05-06	4.99	36	Controversial issue banned in three states.
2115	202	254	Reckoning of Hunt	2018-08-17	1.50	40	Low distribution; considered scarce.
2116	296	626	Rising of Cross	2023-08-03	3.99	100	Reprints classic story with new framing pages.
2117	225	192	Reborn of Cross	1973-02-14	3.99	28	Controversial issue banned in three states.
2118	29	253	Shattered of Fox	1948-11-09	4.99	28	High print run; common in collections.
2119	252	335	Fallen of Hunt	1972-11-17	0.75	32	Controversial issue banned in three states.
2120	15	138	Inferno of Ward	2011-03-19	0.12	80	High print run; common in collections.
2121	89	46	Chaos of Grant	2015-03-19	4.99	100	Contains bonus pin-up gallery.
2122	266	519	Reborn of Fox	1960-08-01	1.95	36	Part of a crossover event.
2123	264	190	Revelation of Grant	2021-01-06	2.50	24	Key first appearance issue.
2124	104	285	Vendetta of Vale	2006-05-23	2.50	28	Reprints classic story with new framing pages.
2125	294	113	Fracture of Voss	2013-08-06	1.95	32	High print run; common in collections.
2126	293	24	Fallen of Hunt	2013-01-18	0.35	100	Part of a crossover event.
2127	13	311	Uprising of Stark	1980-04-18	1.00	80	High print run; common in collections.
2128	30	202	Reckoning of Hunt	2016-09-23	2.99	64	Landmark story milestone.
2129	108	608	Oblivion of Voss	1951-11-07	0.20	32	Direct edition only; no newsstand version.
2130	25	155	Fallen of Kane	2010-10-25	0.50	32	Landmark story milestone.
2131	236	478	Fallen of Drake	1994-10-17	0.20	100	Landmark story milestone.
2132	60	392	Nemesis of Kane	1961-04-06	0.25	32	Key first appearance issue.
2133	62	739	Dawn of Fox	1944-09-24	0.25	44	Double-sized anniversary issue.
2134	225	203	Shattered of Stone	1984-02-27	0.12	40	Reprints classic story with new framing pages.
2135	99	390	Eclipse of Stone	1987-09-16	0.10	32	Contains bonus pin-up gallery.
2136	155	534	Rising of Steele	2002-09-17	1.25	32	Landmark story milestone.
2137	47	24	Descent of Ward	1977-08-05	0.25	44	Key first appearance issue.
2138	296	138	Fallen of Price	2021-08-30	1.25	48	Controversial issue banned in three states.
2139	9	199	Inferno of Nash	1980-04-06	2.50	28	Key first appearance issue.
2140	110	132	Reborn of Stark	2016-11-15	0.10	28	High print run; common in collections.
2141	233	146	Chaos of Stone	2016-08-30	2.99	44	Double-sized anniversary issue.
2142	168	376	Nemesis of Burns	1991-03-17	0.25	36	Key first appearance issue.
2143	133	761	Fallen of Morgan	2001-11-03	0.25	64	Key first appearance issue.
2144	217	371	Shattered of Cross	1954-01-17	4.99	36	Double-sized anniversary issue.
2145	254	62	Convergence of Price	1997-06-20	0.12	64	Landmark story milestone.
2146	221	605	Reckoning of Crane	1985-05-22	0.75	32	Controversial issue banned in three states.
2147	145	666	Rising of Flynn	2020-12-15	1.50	40	Controversial issue banned in three states.
2148	4	719	Vendetta of Drake	1973-08-16	0.75	24	Landmark story milestone.
2149	9	372	Nemesis of Stark	1980-10-26	3.99	44	Direct edition only; no newsstand version.
2150	158	67	Inferno of Fox	1959-12-21	1.95	44	Low distribution; considered scarce.
2151	218	253	Chaos of Stark	2019-12-08	0.20	32	Low distribution; considered scarce.
2152	237	3	Rising of Drake	2021-06-08	0.12	28	Double-sized anniversary issue.
2153	63	213	Reckoning of Crane	1994-09-27	0.75	28	Contains bonus pin-up gallery.
2154	205	782	Shadows of Stark	2008-02-06	0.35	48	Double-sized anniversary issue.
2155	22	14	Resurgence of Kane	1982-06-03	1.95	64	Landmark story milestone.
2156	76	738	Rising of Flynn	1974-05-15	0.12	64	Landmark story milestone.
2157	101	44	Legacy of Fox	2018-10-21	0.20	36	Key first appearance issue.
2158	237	235	Eclipse of Voss	2022-12-30	0.12	40	Part of a crossover event.
2159	272	504	Vendetta of Stone	1999-05-12	2.50	32	Landmark story milestone.
2160	101	18	Reborn of Crane	1997-02-10	0.35	44	Double-sized anniversary issue.
2161	271	364	Fracture of Crane	1952-10-17	2.99	100	Low distribution; considered scarce.
2162	255	210	Rising of Grant	1944-05-01	0.10	44	High print run; common in collections.
2163	103	413	Convergence of Fox	1956-10-22	1.00	48	Direct edition only; no newsstand version.
2164	224	81	Inferno of Hunt	1998-09-05	0.15	80	High print run; common in collections.
2165	71	20	Dawn of Drake	2011-08-13	1.00	48	Direct edition only; no newsstand version.
2166	218	319	Eclipse of Hunt	2019-02-15	0.10	28	Landmark story milestone.
2167	26	603	Oblivion of Fox	2017-07-04	0.20	40	Key first appearance issue.
2168	11	600	Revelation of Grant	2008-12-11	0.15	100	Low distribution; considered scarce.
2169	294	323	Revelation of Voss	2010-01-13	1.50	32	Key first appearance issue.
2170	131	39	Reborn of Burns	2001-07-06	4.99	48	Reprints classic story with new framing pages.
2171	271	655	Revelation of Voss	1951-10-07	0.50	64	Reprints classic story with new framing pages.
2172	225	425	Nemesis of Price	1978-05-25	1.25	28	Direct edition only; no newsstand version.
2173	196	153	Uprising of Stark	1952-03-26	1.25	24	Contains bonus pin-up gallery.
2174	246	273	Revelation of Vale	2008-08-12	0.35	44	Direct edition only; no newsstand version.
2175	94	755	Resurgence of Hunt	2006-05-13	1.25	100	Reprints classic story with new framing pages.
2176	59	457	Reckoning of Voss	2016-05-22	1.00	32	Direct edition only; no newsstand version.
2177	72	220	Fracture of Drake	1961-03-07	3.99	80	Controversial issue banned in three states.
2178	55	421	Dawn of Cross	1948-12-27	0.10	40	Landmark story milestone.
2179	280	241	Inferno of Price	2001-10-03	3.99	32	Landmark story milestone.
2180	43	23	Descent of Cole	2007-11-15	1.25	80	Key first appearance issue.
2181	37	409	Chaos of Burns	1995-07-09	0.25	32	Landmark story milestone.
2182	232	365	Resurgence of Cole	2019-12-19	0.75	100	Contains bonus pin-up gallery.
2183	260	449	Reckoning of Grant	2009-07-14	0.35	24	Key first appearance issue.
2184	133	429	Oblivion of Flynn	2001-07-11	4.99	28	Controversial issue banned in three states.
2185	97	577	Shadows of Burns	1969-07-13	2.50	28	Landmark story milestone.
2186	81	512	Reborn of Holt	2012-09-23	0.35	100	Direct edition only; no newsstand version.
2187	287	155	Fracture of Ward	1956-04-27	4.99	24	Low distribution; considered scarce.
2188	23	364	Revelation of Kane	1992-10-29	1.00	28	Reprints classic story with new framing pages.
2189	217	364	Legacy of Drake	1953-02-03	4.99	80	High print run; common in collections.
2190	91	291	Descent of Grant	2023-06-20	0.75	44	Direct edition only; no newsstand version.
2191	182	798	Fracture of Hunt	1962-08-08	2.50	32	Low distribution; considered scarce.
2192	24	432	Vendetta of Price	1971-05-23	2.50	48	Double-sized anniversary issue.
2193	128	627	Legacy of Morgan	1984-11-17	1.00	64	Double-sized anniversary issue.
2194	160	67	Fracture of Morgan	1952-06-04	0.25	80	Part of a crossover event.
2195	53	146	Convergence of Nash	2000-04-24	0.75	48	Low distribution; considered scarce.
2196	278	129	Reckoning of Cole	1976-04-05	0.75	40	Double-sized anniversary issue.
2197	205	714	Resurgence of Vale	2010-12-22	0.12	48	Controversial issue banned in three states.
2198	133	492	Fallen of Cole	2005-06-07	3.99	100	Reprints classic story with new framing pages.
2199	35	23	Shattered of Voss	2009-05-20	0.15	40	Landmark story milestone.
2200	110	601	Revelation of Nash	2014-04-08	0.35	36	Direct edition only; no newsstand version.
2201	56	219	Oblivion of Crane	1959-04-22	0.10	44	Controversial issue banned in three states.
2202	128	261	Eclipse of Grant	1974-12-19	0.20	48	Part of a crossover event.
2203	12	369	Chaos of Burns	1986-06-05	4.99	32	Low distribution; considered scarce.
2204	64	440	Eclipse of Drake	2006-05-15	0.50	40	Low distribution; considered scarce.
2205	15	427	Nemesis of Voss	2021-09-21	4.99	64	Landmark story milestone.
2206	265	717	Chaos of Price	1955-05-17	0.12	80	Double-sized anniversary issue.
2207	2	473	Descent of Steele	2014-02-15	0.20	40	Landmark story milestone.
2208	227	424	Resurgence of Kane	1954-02-24	0.75	44	Reprints classic story with new framing pages.
2209	95	642	Nemesis of Holt	2007-05-24	2.99	100	Double-sized anniversary issue.
2210	128	406	Shattered of Grant	1999-02-05	3.99	40	Double-sized anniversary issue.
2211	196	320	Shadows of Flynn	1962-09-21	1.50	100	Low distribution; considered scarce.
2212	161	114	Rising of Price	1983-06-04	0.25	100	Controversial issue banned in three states.
2213	30	704	Oblivion of Nash	2021-12-12	0.75	48	Key first appearance issue.
2214	180	73	Oblivion of Voss	1987-03-05	2.99	24	High print run; common in collections.
2215	276	790	Descent of Ward	1985-11-19	0.50	48	Part of a crossover event.
2216	128	727	Fallen of Kane	1991-06-06	1.00	44	Part of a crossover event.
2217	29	498	Reckoning of Drake	1949-02-15	0.10	100	Reprints classic story with new framing pages.
2218	155	306	Resurgence of Hunt	1995-07-11	1.00	32	Key first appearance issue.
2219	151	386	Nemesis of Holt	1987-08-24	2.99	48	Contains bonus pin-up gallery.
2220	211	335	Legacy of Holt	1952-06-26	0.35	24	Low distribution; considered scarce.
2221	162	373	Oblivion of Fox	1961-07-02	1.50	80	Key first appearance issue.
2222	293	316	Eclipse of Vale	2017-01-19	0.50	80	Reprints classic story with new framing pages.
2223	15	134	Revelation of Nash	2018-07-15	1.00	48	Direct edition only; no newsstand version.
2224	67	789	Legacy of Flynn	2014-01-24	1.25	24	Landmark story milestone.
2225	204	343	Shattered of Price	1999-03-11	1.95	36	Key first appearance issue.
2226	5	692	Legacy of Cross	2019-05-02	0.35	28	Controversial issue banned in three states.
2227	78	186	Fracture of Crane	1952-08-06	4.99	64	Low distribution; considered scarce.
2228	206	783	Eclipse of Price	1985-10-03	0.15	48	Key first appearance issue.
2229	54	182	Chaos of Kane	1993-07-19	0.15	44	Double-sized anniversary issue.
2230	129	530	Nemesis of Drake	1997-12-05	0.10	80	Key first appearance issue.
2231	56	603	Resurgence of Ward	1960-08-29	4.99	64	Double-sized anniversary issue.
2232	66	82	Convergence of Hunt	1984-10-14	1.95	64	Key first appearance issue.
2233	140	139	Legacy of Holt	1991-01-02	0.35	48	Landmark story milestone.
2234	76	169	Dawn of Stone	1977-12-23	1.00	36	Contains bonus pin-up gallery.
2235	176	441	Inferno of Hunt	2011-04-12	2.50	80	Key first appearance issue.
2236	237	359	Convergence of Nash	2022-02-08	1.00	80	Controversial issue banned in three states.
2237	159	127	Descent of Vale	1958-11-13	1.50	40	Part of a crossover event.
2238	138	33	Legacy of Holt	1949-03-25	1.25	44	Low distribution; considered scarce.
2239	240	758	Fallen of Stone	2021-11-24	0.15	28	Controversial issue banned in three states.
2240	100	731	Fracture of Burns	1988-06-16	4.99	100	Landmark story milestone.
2241	231	793	Nemesis of Stone	1994-08-31	0.75	40	Controversial issue banned in three states.
2242	251	32	Uprising of Grant	1958-03-24	2.50	32	Landmark story milestone.
2243	244	732	Reckoning of Grant	2012-11-11	0.12	28	Reprints classic story with new framing pages.
2244	199	43	Chaos of Flynn	1954-07-16	0.50	24	Direct edition only; no newsstand version.
2245	118	737	Descent of Cole	1981-07-30	0.25	40	Reprints classic story with new framing pages.
2246	118	236	Vendetta of Morgan	1981-11-06	0.12	28	Double-sized anniversary issue.
2247	36	452	Oblivion of Cole	1982-10-12	1.25	80	Landmark story milestone.
2248	218	177	Chaos of Holt	2021-11-15	1.00	44	Low distribution; considered scarce.
2249	135	55	Descent of Stone	2021-10-18	1.95	28	Contains bonus pin-up gallery.
2250	112	722	Descent of Kane	1987-05-27	0.10	44	High print run; common in collections.
2251	64	550	Fracture of Cole	2008-08-06	1.00	80	Direct edition only; no newsstand version.
2252	291	436	Reborn of Cole	1978-12-26	0.25	100	Key first appearance issue.
2253	157	493	Reborn of Steele	2020-11-18	4.99	28	Low distribution; considered scarce.
2254	231	260	Nemesis of Vale	1981-03-03	0.12	28	Reprints classic story with new framing pages.
2255	277	728	Chaos of Cross	1967-04-11	1.00	32	High print run; common in collections.
2256	286	607	Fracture of Cross	2016-01-29	0.75	36	Reprints classic story with new framing pages.
2257	53	116	Descent of Stark	1989-10-09	0.10	48	Controversial issue banned in three states.
2258	291	177	Resurgence of Cole	1962-06-05	0.12	100	Double-sized anniversary issue.
2259	109	150	Rising of Drake	2018-11-19	0.20	24	Controversial issue banned in three states.
2260	118	3	Reckoning of Voss	1974-11-19	2.50	64	Direct edition only; no newsstand version.
2261	195	47	Reckoning of Cole	1984-04-13	4.99	48	Landmark story milestone.
2262	6	86	Vendetta of Stone	1995-04-15	1.95	48	Landmark story milestone.
2263	148	742	Revelation of Grant	1986-10-08	1.25	44	High print run; common in collections.
2264	44	523	Dawn of Stark	1999-11-25	1.00	48	Double-sized anniversary issue.
2265	71	323	Vendetta of Crane	1986-06-30	1.50	28	Key first appearance issue.
2266	2	751	Reckoning of Fox	2013-07-23	2.50	32	Key first appearance issue.
2267	190	338	Reborn of Ward	2021-02-16	3.99	28	Part of a crossover event.
2268	11	447	Legacy of Ward	2006-07-08	2.99	40	Landmark story milestone.
2269	38	663	Nemesis of Nash	1958-03-04	1.25	28	Landmark story milestone.
2270	116	2	Fracture of Grant	1956-03-01	1.50	28	Direct edition only; no newsstand version.
2271	138	634	Oblivion of Drake	2014-04-19	0.10	44	Double-sized anniversary issue.
2272	100	430	Descent of Stone	1994-08-23	1.25	80	Controversial issue banned in three states.
2273	194	744	Reborn of Hunt	2005-12-25	2.50	32	Direct edition only; no newsstand version.
2274	236	541	Revelation of Grant	1959-05-21	2.99	80	Double-sized anniversary issue.
2275	267	580	Rising of Stark	1956-02-16	4.99	100	Landmark story milestone.
2276	187	380	Reborn of Crane	1962-09-08	0.35	44	Contains bonus pin-up gallery.
2277	40	466	Nemesis of Morgan	1948-03-12	0.75	32	Key first appearance issue.
2278	45	442	Inferno of Fox	1982-11-27	0.35	48	Key first appearance issue.
2279	155	567	Reckoning of Hunt	1994-11-19	1.95	32	Landmark story milestone.
2280	237	344	Resurgence of Flynn	2021-01-09	0.20	64	Contains bonus pin-up gallery.
2281	234	724	Shadows of Steele	1991-08-19	4.99	40	Direct edition only; no newsstand version.
2282	95	99	Descent of Grant	1978-09-11	0.25	40	Landmark story milestone.
2283	207	447	Chaos of Cross	1999-03-08	0.35	32	Reprints classic story with new framing pages.
2284	245	525	Reborn of Voss	1993-12-29	3.99	24	Low distribution; considered scarce.
2285	188	136	Rising of Grant	1979-11-25	1.95	40	Part of a crossover event.
2286	249	327	Legacy of Cole	2016-07-04	0.25	24	Reprints classic story with new framing pages.
2287	73	376	Oblivion of Morgan	1960-08-31	0.10	24	Landmark story milestone.
2288	205	722	Eclipse of Crane	2007-06-19	1.00	24	Contains bonus pin-up gallery.
2289	88	140	Chaos of Stark	2002-09-27	0.35	80	Controversial issue banned in three states.
2290	287	336	Chaos of Morgan	1958-09-15	0.12	28	Contains bonus pin-up gallery.
2291	267	530	Convergence of Cross	1956-04-24	1.00	64	High print run; common in collections.
2292	47	430	Shadows of Ward	1976-10-06	1.95	24	Contains bonus pin-up gallery.
2293	34	360	Descent of Drake	1955-08-30	0.15	28	Reprints classic story with new framing pages.
2294	191	626	Convergence of Fox	2002-01-17	0.20	28	Part of a crossover event.
2295	96	83	Dawn of Nash	2016-03-04	0.75	64	Key first appearance issue.
2296	292	205	Dawn of Drake	1996-02-09	3.99	28	Direct edition only; no newsstand version.
2297	161	5	Oblivion of Holt	1980-04-26	0.15	80	Reprints classic story with new framing pages.
2298	160	729	Eclipse of Burns	1953-07-29	0.75	32	Reprints classic story with new framing pages.
2299	268	424	Reborn of Grant	1993-04-02	0.50	48	Part of a crossover event.
2300	68	264	Chaos of Stark	2001-05-24	0.20	48	Landmark story milestone.
2301	264	486	Uprising of Burns	2016-03-03	0.15	36	Landmark story milestone.
2302	19	341	Dawn of Steele	1977-10-13	1.95	80	Reprints classic story with new framing pages.
2303	207	702	Convergence of Voss	2002-12-13	3.99	40	High print run; common in collections.
2304	185	263	Resurgence of Vale	1997-11-29	1.50	32	Direct edition only; no newsstand version.
2305	272	416	Chaos of Grant	1989-09-17	2.99	24	Direct edition only; no newsstand version.
2306	230	603	Descent of Vale	1964-05-06	1.00	40	Double-sized anniversary issue.
2307	258	561	Vendetta of Cross	1983-05-19	1.50	36	Direct edition only; no newsstand version.
2308	153	142	Descent of Drake	1972-07-20	1.50	44	Key first appearance issue.
2309	229	284	Dawn of Ward	1983-12-19	1.95	64	Reprints classic story with new framing pages.
2310	172	82	Inferno of Ward	1981-11-27	0.35	36	Reprints classic story with new framing pages.
2311	94	10	Shattered of Drake	2012-03-05	1.50	44	Landmark story milestone.
2312	22	645	Vendetta of Morgan	1980-02-18	0.20	36	Landmark story milestone.
2313	43	474	Resurgence of Ward	1976-12-24	0.20	100	Key first appearance issue.
2314	73	303	Fracture of Ward	1969-09-26	0.12	32	Controversial issue banned in three states.
2315	13	735	Shattered of Nash	2008-06-07	0.75	44	Low distribution; considered scarce.
2316	43	1	Shadows of Steele	1983-11-22	0.35	64	Part of a crossover event.
2317	290	61	Reckoning of Cross	1994-01-06	2.99	24	Landmark story milestone.
2318	164	346	Uprising of Cross	2001-06-28	1.95	100	Low distribution; considered scarce.
2319	226	33	Fracture of Burns	1971-03-30	0.12	64	Landmark story milestone.
2320	227	133	Fracture of Price	1950-07-31	0.12	44	Reprints classic story with new framing pages.
2321	188	29	Revelation of Voss	2013-10-07	0.12	24	Direct edition only; no newsstand version.
2322	148	637	Uprising of Burns	2014-05-23	0.10	36	Reprints classic story with new framing pages.
2323	61	285	Inferno of Steele	1978-01-25	0.12	36	Direct edition only; no newsstand version.
2324	24	627	Vendetta of Voss	1970-11-03	0.15	80	Low distribution; considered scarce.
2325	49	670	Eclipse of Price	1979-12-07	0.35	80	Part of a crossover event.
2326	178	769	Revelation of Nash	2012-03-06	1.50	32	Key first appearance issue.
2327	186	73	Dawn of Drake	2005-05-26	2.99	64	Reprints classic story with new framing pages.
2328	296	660	Reckoning of Ward	2018-02-23	2.99	80	Key first appearance issue.
2329	38	397	Fracture of Stark	2006-01-19	1.00	24	High print run; common in collections.
2330	246	274	Fallen of Stone	2005-06-21	0.50	100	Low distribution; considered scarce.
2331	158	716	Inferno of Vale	1959-01-12	0.10	24	Direct edition only; no newsstand version.
2332	252	387	Convergence of Flynn	1967-04-14	1.50	24	High print run; common in collections.
2333	83	357	Reckoning of Voss	2020-07-20	4.99	36	Direct edition only; no newsstand version.
2334	161	134	Nemesis of Cross	2001-11-20	1.25	28	Contains bonus pin-up gallery.
2335	276	189	Reborn of Drake	1974-09-19	0.35	100	Controversial issue banned in three states.
2336	113	227	Vendetta of Flynn	2012-10-23	0.20	28	Key first appearance issue.
2337	17	41	Legacy of Drake	1982-08-18	1.95	36	Key first appearance issue.
2338	277	523	Chaos of Vale	1967-08-23	0.10	32	Landmark story milestone.
2339	46	403	Fracture of Vale	1966-08-12	0.25	100	Key first appearance issue.
2340	145	468	Eclipse of Hunt	2018-10-02	3.99	44	Reprints classic story with new framing pages.
2341	96	176	Reborn of Hunt	2000-12-08	2.99	40	Controversial issue banned in three states.
2342	203	237	Revelation of Crane	1996-01-31	0.35	24	Controversial issue banned in three states.
2343	235	363	Resurgence of Cross	2012-04-19	0.15	40	Contains bonus pin-up gallery.
2344	238	712	Shattered of Steele	1949-04-12	0.10	64	Landmark story milestone.
2345	47	353	Convergence of Vale	1980-06-28	0.10	32	High print run; common in collections.
2346	221	102	Shattered of Cross	1983-12-11	0.15	44	Double-sized anniversary issue.
2347	64	741	Reckoning of Nash	2023-12-06	0.20	48	Landmark story milestone.
2348	58	217	Descent of Nash	2019-03-01	1.50	80	Double-sized anniversary issue.
2349	42	321	Reborn of Fox	2023-08-08	4.99	32	Landmark story milestone.
2350	196	530	Dawn of Drake	1962-06-21	1.50	36	Contains bonus pin-up gallery.
2351	274	717	Shattered of Stone	2010-08-02	0.15	80	Direct edition only; no newsstand version.
2352	80	596	Oblivion of Cross	2021-10-23	1.00	44	Low distribution; considered scarce.
2353	28	99	Resurgence of Steele	2010-06-28	0.35	64	Controversial issue banned in three states.
2354	1	182	Descent of Stone	1977-11-04	1.25	80	Controversial issue banned in three states.
2355	118	679	Fallen of Drake	1973-01-25	1.00	28	Low distribution; considered scarce.
2356	143	286	Uprising of Steele	1989-09-24	0.20	28	Direct edition only; no newsstand version.
2357	185	617	Uprising of Morgan	1999-06-23	0.25	24	Controversial issue banned in three states.
2358	19	52	Chaos of Steele	1976-08-29	0.75	32	Controversial issue banned in three states.
2359	225	368	Fallen of Kane	1995-05-05	0.75	44	High print run; common in collections.
2360	22	516	Shadows of Crane	1963-11-11	1.50	24	Direct edition only; no newsstand version.
2361	130	202	Reckoning of Drake	2014-11-17	1.95	100	High print run; common in collections.
2362	226	471	Inferno of Ward	1976-06-30	0.20	100	Double-sized anniversary issue.
2363	115	787	Shadows of Morgan	1958-11-05	0.35	100	Landmark story milestone.
2364	213	703	Shadows of Stark	2021-08-28	1.25	48	Reprints classic story with new framing pages.
2365	21	597	Resurgence of Stone	2019-10-14	0.20	24	Low distribution; considered scarce.
2366	127	555	Chaos of Voss	2024-08-21	2.50	48	Controversial issue banned in three states.
2367	78	208	Rising of Crane	1947-10-27	4.99	24	Double-sized anniversary issue.
2368	29	416	Descent of Nash	1949-01-21	2.99	48	Contains bonus pin-up gallery.
2369	21	240	Nemesis of Steele	2022-04-19	0.15	100	Double-sized anniversary issue.
2370	202	371	Dawn of Burns	2019-01-12	1.25	40	Low distribution; considered scarce.
2371	19	442	Nemesis of Stone	1981-11-21	1.25	100	High print run; common in collections.
2372	116	427	Inferno of Morgan	1959-05-14	1.25	100	Direct edition only; no newsstand version.
2373	86	195	Fallen of Cross	2018-05-08	2.50	32	Direct edition only; no newsstand version.
2374	61	303	Fallen of Holt	1979-12-26	0.50	48	Controversial issue banned in three states.
2375	176	273	Fallen of Kane	2011-10-19	0.12	80	Contains bonus pin-up gallery.
2376	51	418	Fallen of Vale	2022-12-20	1.25	28	Reprints classic story with new framing pages.
2377	293	270	Revelation of Stone	2016-04-06	1.50	36	Controversial issue banned in three states.
2378	145	192	Inferno of Drake	2020-03-02	1.95	80	High print run; common in collections.
2379	116	267	Uprising of Drake	1955-10-03	0.75	28	Landmark story milestone.
2380	188	542	Oblivion of Ward	2015-12-21	0.10	44	Low distribution; considered scarce.
2381	190	798	Nemesis of Hunt	2023-03-28	1.00	64	Part of a crossover event.
2382	233	601	Chaos of Flynn	2018-04-02	0.50	44	High print run; common in collections.
2383	224	578	Oblivion of Holt	2008-08-17	2.50	48	Reprints classic story with new framing pages.
2384	258	66	Legacy of Stone	1987-07-29	1.00	32	Landmark story milestone.
2385	91	293	Inferno of Morgan	2021-11-06	0.10	100	Part of a crossover event.
2386	157	90	Eclipse of Cross	2021-06-04	2.50	100	Controversial issue banned in three states.
2387	166	590	Nemesis of Ward	2012-04-20	1.25	64	Controversial issue banned in three states.
2388	58	14	Fracture of Holt	2001-06-27	0.25	36	Part of a crossover event.
2389	61	186	Nemesis of Kane	1983-12-17	1.25	24	Low distribution; considered scarce.
2390	279	201	Revelation of Cross	1967-02-02	2.99	28	Low distribution; considered scarce.
2391	163	219	Dawn of Fox	1954-06-19	2.99	36	Contains bonus pin-up gallery.
2392	116	698	Reckoning of Morgan	1954-03-04	0.20	64	Double-sized anniversary issue.
2393	183	146	Rising of Voss	1946-09-30	1.95	80	Contains bonus pin-up gallery.
2394	48	326	Convergence of Stone	1986-08-07	1.95	40	Controversial issue banned in three states.
2395	222	472	Chaos of Holt	2011-09-04	4.99	24	Landmark story milestone.
2396	255	659	Convergence of Morgan	1946-03-05	2.99	44	Controversial issue banned in three states.
2397	114	474	Fracture of Steele	1972-12-22	2.99	48	Part of a crossover event.
2398	209	200	Fracture of Morgan	1982-11-23	0.20	40	Key first appearance issue.
2399	24	718	Inferno of Steele	1971-07-12	3.99	80	Landmark story milestone.
2400	13	334	Resurgence of Drake	2004-12-19	0.12	24	Controversial issue banned in three states.
2401	248	747	Fallen of Voss	2011-12-31	1.25	32	Part of a crossover event.
2402	238	123	Legacy of Morgan	1951-03-10	1.25	36	Reprints classic story with new framing pages.
2403	64	782	Nemesis of Cole	2011-10-06	0.15	64	Controversial issue banned in three states.
2404	18	125	Uprising of Ward	2016-03-23	1.95	44	Controversial issue banned in three states.
2405	266	181	Reckoning of Price	1955-07-13	0.35	100	Contains bonus pin-up gallery.
2406	127	131	Inferno of Price	2015-09-18	1.95	36	High print run; common in collections.
2407	76	155	Fracture of Vale	1980-07-31	0.50	80	Reprints classic story with new framing pages.
2408	90	295	Inferno of Stark	1977-01-24	0.75	44	High print run; common in collections.
2409	67	434	Legacy of Voss	2014-07-17	1.95	24	Contains bonus pin-up gallery.
2410	204	51	Descent of Fox	1987-01-21	0.12	80	Controversial issue banned in three states.
2411	200	510	Rising of Cole	2009-06-20	0.35	36	Direct edition only; no newsstand version.
2412	20	15	Oblivion of Kane	1942-06-05	0.25	48	Landmark story milestone.
2413	182	567	Revelation of Grant	2010-11-07	0.35	28	Contains bonus pin-up gallery.
2414	223	547	Chaos of Ward	1966-11-18	4.99	36	Part of a crossover event.
2415	227	135	Fallen of Stone	1953-10-13	0.50	32	Controversial issue banned in three states.
2416	83	521	Reckoning of Kane	2020-12-29	1.25	40	Controversial issue banned in three states.
2417	178	687	Reborn of Steele	1994-04-05	0.35	32	Part of a crossover event.
2418	208	387	Convergence of Price	1949-02-16	1.50	36	Part of a crossover event.
2419	26	249	Oblivion of Vale	2017-03-08	0.15	28	Double-sized anniversary issue.
2420	29	407	Oblivion of Holt	1948-07-10	0.20	36	Key first appearance issue.
2421	249	323	Revelation of Grant	2023-07-03	1.25	28	Double-sized anniversary issue.
2422	166	14	Shadows of Vale	1992-04-27	2.50	32	Direct edition only; no newsstand version.
2423	30	294	Nemesis of Vale	2014-05-30	4.99	44	Direct edition only; no newsstand version.
2424	33	749	Chaos of Stark	1982-10-05	0.12	44	Part of a crossover event.
2425	129	75	Convergence of Voss	1999-07-06	1.95	28	Direct edition only; no newsstand version.
2426	138	80	Reborn of Flynn	1951-06-18	1.50	48	Low distribution; considered scarce.
2427	9	687	Shadows of Hunt	1979-10-10	2.50	100	High print run; common in collections.
2428	165	561	Oblivion of Nash	1981-07-12	0.35	24	Contains bonus pin-up gallery.
2429	1	19	Chaos of Cross	1985-04-20	2.99	32	Key first appearance issue.
2430	37	99	Fallen of Voss	1993-04-03	0.25	40	Landmark story milestone.
2431	104	250	Legacy of Price	2018-10-27	2.50	64	Double-sized anniversary issue.
2432	291	416	Dawn of Hunt	1973-05-12	4.99	36	Landmark story milestone.
2433	85	503	Oblivion of Vale	2015-02-15	0.15	100	Controversial issue banned in three states.
2434	68	668	Nemesis of Morgan	1987-04-13	3.99	44	Reprints classic story with new framing pages.
2435	272	637	Oblivion of Grant	2010-12-27	2.99	44	High print run; common in collections.
2436	107	702	Reborn of Burns	2003-02-25	0.50	28	Reprints classic story with new framing pages.
2437	47	789	Nemesis of Flynn	1979-07-14	1.25	36	Key first appearance issue.
2438	263	653	Eclipse of Cross	2016-11-16	0.75	28	Controversial issue banned in three states.
2439	24	124	Reborn of Voss	1968-11-20	1.95	24	Part of a crossover event.
2440	249	279	Vendetta of Hunt	2020-03-28	3.99	40	Contains bonus pin-up gallery.
2441	4	52	Reckoning of Steele	1974-12-30	2.99	80	Contains bonus pin-up gallery.
2442	203	317	Descent of Crane	2007-09-26	4.99	48	Low distribution; considered scarce.
2443	294	608	Fracture of Burns	2015-01-09	0.15	48	High print run; common in collections.
2444	198	437	Dawn of Holt	1979-03-07	1.50	24	Key first appearance issue.
2445	209	362	Eclipse of Vale	1987-12-01	4.99	36	Key first appearance issue.
2446	198	579	Legacy of Price	1972-06-08	0.35	64	Contains bonus pin-up gallery.
2447	41	651	Reborn of Nash	1993-12-06	0.25	100	Direct edition only; no newsstand version.
2448	115	211	Dawn of Nash	1975-10-22	3.99	24	Controversial issue banned in three states.
2449	189	113	Convergence of Cole	2021-12-03	0.35	64	Direct edition only; no newsstand version.
2450	106	307	Revelation of Voss	2003-10-14	1.50	100	Low distribution; considered scarce.
2451	269	574	Reborn of Flynn	2009-12-03	2.50	44	Low distribution; considered scarce.
2452	212	446	Revelation of Burns	2002-12-25	1.50	40	Low distribution; considered scarce.
2453	114	727	Chaos of Voss	1969-11-23	1.25	100	Landmark story milestone.
2454	203	618	Reborn of Vale	2019-07-17	0.75	40	Low distribution; considered scarce.
2455	297	292	Revelation of Hunt	1945-01-20	1.00	48	Low distribution; considered scarce.
2456	9	778	Descent of Cross	1978-10-17	0.25	36	Key first appearance issue.
2457	169	431	Fallen of Price	2014-06-14	4.99	36	Reprints classic story with new framing pages.
2458	273	790	Resurgence of Hunt	1996-08-23	1.00	28	High print run; common in collections.
2459	81	9	Reborn of Fox	2008-02-29	0.25	24	Controversial issue banned in three states.
2460	59	780	Dawn of Stark	2010-06-23	1.50	40	Double-sized anniversary issue.
2461	179	294	Legacy of Nash	1999-08-24	1.50	64	Reprints classic story with new framing pages.
2462	68	129	Dawn of Vale	2017-10-10	0.10	24	Low distribution; considered scarce.
2463	143	444	Vendetta of Ward	1990-03-06	0.15	32	Reprints classic story with new framing pages.
2464	115	56	Reckoning of Steele	1997-10-30	1.95	28	Controversial issue banned in three states.
2465	59	752	Fracture of Flynn	1998-02-25	2.50	44	Double-sized anniversary issue.
2466	201	339	Reborn of Flynn	2009-04-09	4.99	24	Double-sized anniversary issue.
2467	221	588	Shattered of Stone	1983-06-11	0.15	40	Part of a crossover event.
2468	283	194	Chaos of Flynn	1972-05-07	2.50	48	High print run; common in collections.
2469	44	229	Descent of Grant	1953-07-02	1.95	24	High print run; common in collections.
2470	152	196	Legacy of Cross	1971-06-21	0.25	24	High print run; common in collections.
2471	100	469	Vendetta of Cross	1991-12-15	1.00	48	High print run; common in collections.
2472	56	309	Revelation of Fox	1958-02-08	2.99	80	Direct edition only; no newsstand version.
2473	277	34	Descent of Flynn	1963-04-25	0.25	100	Low distribution; considered scarce.
2474	196	52	Fallen of Voss	1963-01-25	4.99	64	Low distribution; considered scarce.
2475	33	270	Uprising of Drake	1983-08-12	1.25	36	Part of a crossover event.
2476	30	234	Descent of Nash	2006-06-25	0.12	32	Controversial issue banned in three states.
2477	287	288	Legacy of Ward	1958-09-03	1.50	32	Contains bonus pin-up gallery.
2478	173	204	Uprising of Steele	2006-02-25	0.25	100	High print run; common in collections.
2479	5	17	Fallen of Flynn	1969-03-25	2.50	100	Landmark story milestone.
2480	111	11	Revelation of Morgan	1966-04-17	0.75	36	Low distribution; considered scarce.
2481	210	452	Shadows of Kane	1984-01-11	2.99	64	Part of a crossover event.
2482	6	438	Fallen of Stark	1992-10-24	1.95	44	High print run; common in collections.
2483	30	285	Inferno of Stone	2006-11-22	0.12	28	Controversial issue banned in three states.
2484	119	570	Chaos of Stark	2011-01-18	0.35	36	Key first appearance issue.
2485	111	734	Fallen of Drake	1967-01-14	0.25	80	Low distribution; considered scarce.
2486	235	596	Reckoning of Voss	2005-07-11	3.99	32	Controversial issue banned in three states.
2487	68	54	Inferno of Drake	1974-04-04	3.99	48	Low distribution; considered scarce.
2488	280	748	Rising of Stark	2018-10-01	4.99	44	Low distribution; considered scarce.
2489	212	638	Shattered of Cross	1953-07-01	1.00	24	Direct edition only; no newsstand version.
2490	185	555	Revelation of Grant	2000-03-05	3.99	32	Contains bonus pin-up gallery.
2491	76	518	Shadows of Cross	1988-03-25	0.25	44	Reprints classic story with new framing pages.
2492	21	705	Eclipse of Ward	2024-07-23	2.50	80	Low distribution; considered scarce.
2493	131	743	Fallen of Vale	2001-09-30	4.99	36	High print run; common in collections.
2494	232	788	Shadows of Cross	1992-06-11	0.20	32	Landmark story milestone.
2495	45	123	Resurgence of Fox	1975-03-25	0.12	36	Part of a crossover event.
2496	284	761	Shattered of Drake	2017-03-01	0.15	64	Key first appearance issue.
2497	249	711	Dawn of Vale	2019-04-08	0.25	44	Landmark story milestone.
2498	129	183	Shattered of Flynn	1989-12-03	0.20	64	Landmark story milestone.
2499	89	146	Oblivion of Ward	2015-12-26	1.00	36	High print run; common in collections.
2500	286	187	Convergence of Morgan	2021-03-11	1.95	40	Controversial issue banned in three states.
2501	74	385	Convergence of Ward	2017-04-07	1.50	40	Reprints classic story with new framing pages.
2502	196	200	Reckoning of Grant	1954-04-25	0.50	36	Low distribution; considered scarce.
2503	151	454	Reckoning of Burns	1973-10-10	4.99	80	Reprints classic story with new framing pages.
2504	298	13	Chaos of Fox	1953-09-16	0.10	32	Key first appearance issue.
2505	192	700	Nemesis of Cole	2000-10-07	1.95	28	Reprints classic story with new framing pages.
2506	161	699	Fracture of Stark	1995-12-31	1.00	100	Controversial issue banned in three states.
2507	204	650	Uprising of Cross	1994-08-01	1.50	48	High print run; common in collections.
2508	138	464	Oblivion of Stark	1961-08-06	1.50	32	Controversial issue banned in three states.
2509	184	18	Legacy of Voss	1988-10-12	2.50	44	Double-sized anniversary issue.
2510	43	620	Fallen of Morgan	1980-09-19	1.95	100	Controversial issue banned in three states.
2511	78	120	Shadows of Flynn	1952-05-30	2.99	36	Key first appearance issue.
2512	78	324	Reborn of Ward	1953-02-15	0.75	48	High print run; common in collections.
2513	238	662	Legacy of Cross	1950-09-24	1.25	32	Key first appearance issue.
2514	221	78	Eclipse of Holt	1985-02-11	0.10	80	Part of a crossover event.
2515	50	210	Rising of Vale	1955-06-15	0.12	24	Low distribution; considered scarce.
2516	294	230	Convergence of Voss	2015-12-30	0.15	32	Controversial issue banned in three states.
2517	49	79	Inferno of Burns	1977-10-03	0.20	44	Double-sized anniversary issue.
2518	79	557	Legacy of Grant	2010-07-14	4.99	48	Low distribution; considered scarce.
2519	5	782	Reborn of Kane	1966-05-01	1.50	40	Double-sized anniversary issue.
2520	276	399	Vendetta of Burns	1970-04-25	0.25	24	Key first appearance issue.
2521	199	584	Resurgence of Stark	1952-12-26	3.99	80	Contains bonus pin-up gallery.
2522	126	322	Resurgence of Flynn	1984-04-30	2.50	48	Low distribution; considered scarce.
2523	205	794	Rising of Price	2008-06-27	2.99	32	High print run; common in collections.
2524	152	185	Rising of Price	2014-01-28	0.25	48	Controversial issue banned in three states.
2525	92	198	Convergence of Morgan	1949-09-26	1.25	28	Key first appearance issue.
2526	146	627	Chaos of Grant	2018-12-01	0.50	28	Low distribution; considered scarce.
2527	249	582	Rising of Voss	2021-09-24	4.99	100	Contains bonus pin-up gallery.
2528	79	603	Shattered of Price	2009-03-23	1.00	100	Double-sized anniversary issue.
2529	50	165	Resurgence of Stone	1996-06-19	0.20	80	Key first appearance issue.
2530	30	443	Legacy of Crane	2007-12-02	0.10	32	Key first appearance issue.
2531	32	357	Uprising of Cross	1950-02-14	1.50	36	Double-sized anniversary issue.
2532	203	99	Reckoning of Flynn	2002-06-17	0.12	44	Controversial issue banned in three states.
2533	139	543	Revelation of Grant	2000-12-16	0.10	44	Double-sized anniversary issue.
2534	83	631	Convergence of Hunt	2019-05-06	0.12	24	Contains bonus pin-up gallery.
2535	204	715	Legacy of Cross	1996-12-23	3.99	48	High print run; common in collections.
2536	117	570	Uprising of Cole	2015-12-28	2.50	36	High print run; common in collections.
2537	248	765	Shadows of Cole	2014-07-28	1.50	28	Double-sized anniversary issue.
2538	207	408	Fracture of Kane	2000-12-10	0.75	48	Double-sized anniversary issue.
2539	157	1	Shadows of Stone	2020-04-21	0.25	80	Controversial issue banned in three states.
2540	103	232	Shattered of Steele	1960-02-04	0.20	80	Double-sized anniversary issue.
2541	115	192	Fracture of Price	1978-05-04	0.15	80	Contains bonus pin-up gallery.
2542	167	416	Oblivion of Stark	2015-02-10	2.50	28	Key first appearance issue.
2543	217	645	Inferno of Hunt	2010-10-12	0.35	24	Double-sized anniversary issue.
2544	268	670	Chaos of Vale	1989-02-15	0.15	100	Controversial issue banned in three states.
2545	240	456	Legacy of Kane	2023-05-27	3.99	80	Landmark story milestone.
2546	181	594	Descent of Vale	1994-10-17	1.25	44	Contains bonus pin-up gallery.
2547	92	692	Reckoning of Steele	2008-11-20	2.50	48	Part of a crossover event.
2548	205	394	Convergence of Price	2010-12-27	1.95	100	Landmark story milestone.
2549	71	459	Uprising of Burns	1998-01-15	0.35	44	Part of a crossover event.
2550	115	280	Legacy of Morgan	2001-01-14	3.99	40	Controversial issue banned in three states.
2551	297	623	Reckoning of Fox	1949-08-30	1.00	64	Controversial issue banned in three states.
2552	211	605	Vendetta of Voss	1985-12-14	3.99	100	Reprints classic story with new framing pages.
2553	203	23	Descent of Morgan	2015-09-24	3.99	40	Contains bonus pin-up gallery.
2554	131	703	Shattered of Hunt	1994-10-15	1.25	48	Low distribution; considered scarce.
2555	39	199	Shattered of Cole	2023-09-02	1.25	28	Direct edition only; no newsstand version.
2556	237	296	Fracture of Cole	2020-05-11	1.50	36	Direct edition only; no newsstand version.
2557	298	547	Rising of Ward	1956-01-07	1.25	100	Double-sized anniversary issue.
2558	15	297	Eclipse of Morgan	2014-12-13	0.35	80	Direct edition only; no newsstand version.
2559	6	176	Rising of Drake	1990-04-30	0.35	48	Controversial issue banned in three states.
2560	235	407	Nemesis of Burns	2004-11-16	0.12	24	Double-sized anniversary issue.
2561	92	548	Chaos of Nash	1967-04-10	0.20	36	Key first appearance issue.
2562	285	587	Descent of Stone	1989-03-17	0.12	44	Contains bonus pin-up gallery.
2563	157	554	Descent of Vale	2021-11-13	4.99	40	Landmark story milestone.
2564	284	426	Revelation of Morgan	2016-12-21	0.25	64	Part of a crossover event.
2565	7	1	Uprising of Drake	1954-01-23	1.95	48	Direct edition only; no newsstand version.
2566	53	798	Shattered of Nash	2009-07-25	0.50	24	Part of a crossover event.
2567	199	100	Descent of Holt	1955-07-27	0.50	64	Double-sized anniversary issue.
2568	151	460	Reborn of Drake	1976-09-08	4.99	24	Landmark story milestone.
2569	272	166	Legacy of Drake	2008-03-05	0.10	28	High print run; common in collections.
2570	219	705	Rising of Drake	1996-05-28	0.75	40	Low distribution; considered scarce.
2571	156	135	Shattered of Price	1967-08-13	0.12	48	Contains bonus pin-up gallery.
2572	141	352	Legacy of Grant	1999-11-04	2.50	44	Controversial issue banned in three states.
2573	155	387	Fallen of Steele	1994-06-08	0.20	44	Part of a crossover event.
2574	224	141	Eclipse of Crane	2013-06-05	0.35	32	Controversial issue banned in three states.
2575	64	340	Revelation of Stone	2002-05-10	1.25	64	Key first appearance issue.
2576	133	315	Oblivion of Ward	2006-08-06	1.25	80	Low distribution; considered scarce.
2577	167	612	Revelation of Price	2017-02-01	2.99	44	Controversial issue banned in three states.
2578	50	238	Descent of Vale	2014-02-01	1.50	24	Contains bonus pin-up gallery.
2579	42	295	Eclipse of Nash	2018-07-16	0.50	28	Controversial issue banned in three states.
2580	29	759	Revelation of Ward	1947-01-07	0.25	32	Landmark story milestone.
2581	35	243	Fallen of Fox	2009-08-25	4.99	32	Direct edition only; no newsstand version.
2582	139	658	Descent of Vale	2014-01-17	1.95	80	Part of a crossover event.
2583	165	333	Convergence of Cross	1982-02-08	1.25	32	Part of a crossover event.
2584	72	104	Nemesis of Kane	1974-01-09	1.50	64	Part of a crossover event.
2585	44	69	Dawn of Flynn	1987-04-01	0.12	80	Key first appearance issue.
2586	186	614	Shadows of Holt	2001-11-02	3.99	64	Low distribution; considered scarce.
2587	138	236	Inferno of Stone	1987-04-24	1.95	32	Low distribution; considered scarce.
2588	225	750	Vendetta of Kane	1996-09-22	3.99	28	Part of a crossover event.
2589	298	720	Reborn of Fox	1953-05-14	0.50	40	Low distribution; considered scarce.
2590	105	342	Revelation of Stark	2019-03-17	0.10	36	High print run; common in collections.
2591	64	432	Shadows of Voss	2011-10-08	0.50	36	Double-sized anniversary issue.
2592	94	39	Resurgence of Stark	2008-10-15	0.35	80	Landmark story milestone.
2593	181	492	Descent of Stark	1983-10-23	0.50	24	Low distribution; considered scarce.
2594	285	189	Eclipse of Voss	1984-07-03	1.50	32	Landmark story milestone.
2595	228	314	Legacy of Flynn	2019-01-07	0.50	44	High print run; common in collections.
2596	248	52	Rising of Cole	2015-09-28	0.20	44	Direct edition only; no newsstand version.
2597	245	300	Chaos of Ward	1987-06-08	4.99	28	Contains bonus pin-up gallery.
2598	227	167	Reborn of Ward	1958-12-30	0.15	40	High print run; common in collections.
2599	108	406	Fallen of Hunt	1952-07-24	1.00	48	Direct edition only; no newsstand version.
2600	135	54	Shattered of Hunt	2020-10-30	0.10	24	Landmark story milestone.
2601	25	610	Descent of Flynn	2001-10-02	4.99	36	Reprints classic story with new framing pages.
2602	9	240	Eclipse of Cross	1978-12-01	0.20	28	Double-sized anniversary issue.
2603	210	535	Vendetta of Burns	2001-07-13	0.35	40	Direct edition only; no newsstand version.
2604	142	527	Resurgence of Burns	2010-07-06	3.99	100	Part of a crossover event.
2605	225	575	Inferno of Stark	1980-08-28	1.50	100	Part of a crossover event.
2606	267	531	Rising of Hunt	1950-06-02	0.12	32	Controversial issue banned in three states.
2607	37	764	Reborn of Fox	1990-10-15	0.15	32	Low distribution; considered scarce.
2608	271	193	Shattered of Fox	1952-01-12	0.15	64	Key first appearance issue.
2609	169	542	Vendetta of Holt	2018-01-16	1.50	28	Low distribution; considered scarce.
2610	106	509	Convergence of Cole	2003-10-09	2.50	80	Landmark story milestone.
2611	43	744	Uprising of Morgan	1984-05-07	0.50	80	Double-sized anniversary issue.
2612	175	445	Descent of Kane	1980-06-07	0.15	100	High print run; common in collections.
2613	252	82	Chaos of Flynn	1969-01-31	0.10	24	Reprints classic story with new framing pages.
2614	294	171	Rising of Fox	2017-01-25	3.99	100	Key first appearance issue.
2615	190	152	Descent of Crane	2021-07-16	2.99	100	High print run; common in collections.
2616	114	383	Shadows of Flynn	1981-06-17	0.10	64	Key first appearance issue.
2617	164	130	Nemesis of Morgan	2003-05-18	0.20	28	Reprints classic story with new framing pages.
2618	124	599	Shadows of Morgan	1958-08-29	0.75	80	Controversial issue banned in three states.
2619	294	315	Fallen of Flynn	2015-04-27	1.95	28	High print run; common in collections.
2620	219	588	Dawn of Cole	1966-10-16	1.50	80	Landmark story milestone.
2621	258	126	Dawn of Burns	1995-02-01	1.50	24	Controversial issue banned in three states.
2622	154	732	Fracture of Stone	2000-07-08	2.50	28	Part of a crossover event.
2623	272	211	Nemesis of Ward	2009-04-04	0.25	64	Landmark story milestone.
2624	112	358	Resurgence of Price	2008-12-02	2.50	100	High print run; common in collections.
2625	108	248	Shattered of Drake	1949-12-24	0.10	44	Double-sized anniversary issue.
2626	165	93	Inferno of Burns	1981-05-31	3.99	36	Landmark story milestone.
2627	172	385	Revelation of Hunt	1982-08-27	4.99	100	Controversial issue banned in three states.
2628	183	119	Rising of Ward	1950-10-11	1.25	36	Direct edition only; no newsstand version.
2629	22	521	Revelation of Stark	1964-01-05	4.99	32	Contains bonus pin-up gallery.
2630	15	558	Shattered of Crane	2012-07-21	2.50	48	Key first appearance issue.
2631	176	303	Convergence of Cole	2011-05-26	0.15	48	Low distribution; considered scarce.
2632	132	722	Legacy of Voss	1949-02-28	0.12	28	Reprints classic story with new framing pages.
2633	237	650	Uprising of Flynn	2020-10-24	1.25	48	Low distribution; considered scarce.
2634	22	128	Dawn of Stone	1974-09-30	0.10	32	Contains bonus pin-up gallery.
2635	110	271	Fallen of Stark	2013-02-03	2.99	36	Direct edition only; no newsstand version.
2636	69	105	Chaos of Holt	1971-09-17	1.00	64	Landmark story milestone.
2637	271	593	Revelation of Hunt	1953-03-27	1.50	36	Key first appearance issue.
2638	295	589	Dawn of Crane	1944-04-23	4.99	48	Low distribution; considered scarce.
2639	2	178	Convergence of Cole	2014-08-07	1.00	100	Double-sized anniversary issue.
2640	233	328	Inferno of Kane	2017-07-06	0.75	44	Double-sized anniversary issue.
2641	233	503	Rising of Fox	2016-10-05	1.00	36	Key first appearance issue.
2642	218	574	Rising of Kane	2024-03-14	2.50	40	Key first appearance issue.
2643	104	214	Reborn of Cole	2012-11-04	0.15	80	Contains bonus pin-up gallery.
2644	106	482	Fracture of Nash	2005-02-24	0.75	36	High print run; common in collections.
2645	208	780	Oblivion of Fox	1969-06-22	0.10	40	Landmark story milestone.
2646	120	620	Reckoning of Price	1982-03-11	0.20	44	High print run; common in collections.
2647	263	430	Reckoning of Cross	2022-02-21	0.25	48	Controversial issue banned in three states.
2648	179	171	Dawn of Holt	2002-11-12	0.15	32	High print run; common in collections.
2649	44	36	Inferno of Fox	2001-11-01	3.99	32	Key first appearance issue.
2650	138	287	Shadows of Morgan	2012-12-31	0.12	64	Reprints classic story with new framing pages.
2651	140	579	Uprising of Cross	1987-02-13	1.00	44	High print run; common in collections.
2652	283	61	Shattered of Stark	1969-11-05	1.25	28	Controversial issue banned in three states.
2653	74	558	Fracture of Morgan	2019-02-08	4.99	32	Direct edition only; no newsstand version.
2654	131	210	Convergence of Cross	1997-04-02	1.95	28	Contains bonus pin-up gallery.
2655	153	190	Vendetta of Morgan	1969-08-13	1.00	36	Controversial issue banned in three states.
2656	215	111	Descent of Price	1987-07-24	0.12	24	High print run; common in collections.
2657	157	539	Legacy of Kane	2021-01-26	2.50	36	Key first appearance issue.
2658	244	153	Descent of Ward	1997-07-16	3.99	32	Key first appearance issue.
2659	78	33	Shattered of Flynn	1946-10-15	0.75	48	Direct edition only; no newsstand version.
2660	70	585	Inferno of Stone	1950-02-22	2.99	80	Reprints classic story with new framing pages.
2661	16	348	Fracture of Stark	1966-02-10	1.50	24	Key first appearance issue.
2662	50	250	Fallen of Flynn	1982-05-27	0.10	24	Contains bonus pin-up gallery.
2663	111	473	Shadows of Stone	1970-11-25	0.12	64	Controversial issue banned in three states.
2664	83	112	Uprising of Grant	2017-07-11	2.50	100	Key first appearance issue.
2665	261	78	Nemesis of Stark	1963-08-08	0.25	32	Landmark story milestone.
2666	13	324	Chaos of Crane	1994-10-11	0.20	64	Landmark story milestone.
2667	292	561	Shadows of Stark	1997-07-02	0.10	64	Low distribution; considered scarce.
2668	157	417	Dawn of Steele	2020-09-07	0.75	40	Low distribution; considered scarce.
2669	68	370	Fallen of Voss	1964-06-23	2.50	24	Controversial issue banned in three states.
2670	176	220	Reborn of Holt	2011-01-06	0.15	32	Key first appearance issue.
2671	299	313	Fracture of Stark	1973-07-10	0.35	48	Reprints classic story with new framing pages.
2672	12	691	Convergence of Crane	1988-05-04	1.95	44	Landmark story milestone.
2673	116	134	Oblivion of Crane	1963-05-09	0.15	64	Reprints classic story with new framing pages.
2674	154	25	Fallen of Holt	2015-12-30	1.95	44	Reprints classic story with new framing pages.
2675	277	115	Nemesis of Drake	1966-12-07	0.25	28	Landmark story milestone.
2676	295	114	Eclipse of Grant	1945-09-28	0.15	32	Direct edition only; no newsstand version.
2677	277	776	Vendetta of Price	1967-07-16	2.99	40	Contains bonus pin-up gallery.
2678	285	527	Legacy of Steele	1984-03-13	0.50	64	Direct edition only; no newsstand version.
2679	31	513	Resurgence of Holt	2011-03-21	1.25	64	Low distribution; considered scarce.
2680	13	768	Revelation of Fox	2017-11-10	0.15	100	Landmark story milestone.
2681	293	503	Vendetta of Price	2012-05-13	0.25	28	Direct edition only; no newsstand version.
2682	154	52	Nemesis of Hunt	1992-12-15	0.50	48	Reprints classic story with new framing pages.
2683	66	334	Revelation of Holt	1984-11-07	1.00	80	Direct edition only; no newsstand version.
2684	139	41	Resurgence of Cross	2010-02-22	0.20	36	Reprints classic story with new framing pages.
2685	271	327	Chaos of Crane	1951-04-21	0.35	32	Key first appearance issue.
2686	87	171	Uprising of Stark	1974-12-01	0.25	24	Part of a crossover event.
2687	169	214	Uprising of Morgan	1992-01-25	0.12	24	Key first appearance issue.
2688	281	386	Revelation of Burns	2017-08-22	2.50	64	High print run; common in collections.
2689	57	5	Reckoning of Cole	2023-06-18	0.15	28	Low distribution; considered scarce.
2690	61	3	Reckoning of Hunt	1987-02-10	0.15	48	Reprints classic story with new framing pages.
2691	78	143	Oblivion of Stone	1951-04-10	3.99	100	Double-sized anniversary issue.
2692	296	758	Shattered of Drake	2023-02-27	2.50	24	Double-sized anniversary issue.
2693	173	557	Shadows of Grant	2012-06-19	2.99	64	Low distribution; considered scarce.
2694	199	42	Dawn of Morgan	1954-06-30	1.00	36	High print run; common in collections.
2695	223	100	Revelation of Fox	1963-08-31	0.15	28	Double-sized anniversary issue.
2696	44	95	Shattered of Grant	1975-07-24	1.95	40	Part of a crossover event.
2697	257	778	Reborn of Burns	1993-03-05	0.25	24	High print run; common in collections.
2698	134	71	Inferno of Stone	1996-07-16	1.50	36	Low distribution; considered scarce.
2699	212	31	Fracture of Flynn	1980-11-18	2.50	100	Reprints classic story with new framing pages.
2700	129	596	Chaos of Ward	1986-09-17	2.99	64	Controversial issue banned in three states.
2701	28	60	Descent of Steele	1985-04-14	1.00	24	Controversial issue banned in three states.
2702	277	706	Resurgence of Steele	1964-01-11	0.25	36	Double-sized anniversary issue.
2703	229	786	Vendetta of Morgan	1987-05-19	0.25	48	Controversial issue banned in three states.
2704	18	355	Resurgence of Voss	2019-12-15	4.99	40	Part of a crossover event.
2705	70	233	Inferno of Stone	1967-12-22	2.99	40	Controversial issue banned in three states.
2706	114	466	Reckoning of Morgan	1970-09-22	1.25	28	Controversial issue banned in three states.
2707	49	143	Descent of Flynn	1995-02-14	0.20	80	Landmark story milestone.
2708	215	644	Convergence of Flynn	1987-05-23	1.95	100	Key first appearance issue.
2709	147	118	Dawn of Drake	1957-12-01	3.99	100	Controversial issue banned in three states.
2710	113	271	Legacy of Crane	1946-12-20	0.10	24	Landmark story milestone.
2711	66	249	Resurgence of Steele	2001-03-10	3.99	28	Key first appearance issue.
2712	46	764	Convergence of Stone	1974-03-24	0.25	100	Direct edition only; no newsstand version.
2713	36	92	Fallen of Morgan	1980-09-27	1.00	80	Part of a crossover event.
2714	6	754	Legacy of Crane	1994-03-01	1.50	36	Low distribution; considered scarce.
2715	160	743	Dawn of Burns	1953-01-25	0.35	32	Contains bonus pin-up gallery.
2716	215	650	Vendetta of Ward	1988-03-24	0.10	28	Reprints classic story with new framing pages.
2717	46	243	Reckoning of Nash	1965-06-20	4.99	36	Low distribution; considered scarce.
2718	252	266	Revelation of Nash	1960-05-04	2.99	28	Contains bonus pin-up gallery.
2719	210	174	Convergence of Flynn	1989-12-22	0.20	32	Contains bonus pin-up gallery.
2720	94	464	Reckoning of Cole	2008-06-02	2.50	48	Direct edition only; no newsstand version.
2721	180	157	Fallen of Holt	2012-11-26	0.15	100	Contains bonus pin-up gallery.
2722	210	559	Fracture of Cole	2018-06-19	1.00	100	Low distribution; considered scarce.
2723	243	83	Convergence of Hunt	1991-06-24	0.12	36	Part of a crossover event.
2724	8	423	Rising of Cole	2011-10-27	1.25	80	Reprints classic story with new framing pages.
2725	248	150	Fallen of Vale	2013-05-19	1.50	40	High print run; common in collections.
2726	158	315	Legacy of Ward	1947-03-16	0.25	28	Controversial issue banned in three states.
2727	45	653	Legacy of Holt	2001-03-03	1.95	32	Part of a crossover event.
2728	132	177	Reckoning of Ward	1994-07-28	1.00	40	Landmark story milestone.
2729	64	687	Shattered of Stark	2006-07-15	0.50	80	Double-sized anniversary issue.
2730	42	151	Fracture of Vale	2022-12-16	0.10	48	High print run; common in collections.
2731	158	346	Reborn of Burns	1951-01-21	0.35	28	Double-sized anniversary issue.
2732	265	601	Legacy of Grant	1968-11-14	0.10	48	Direct edition only; no newsstand version.
2733	133	356	Rising of Kane	2001-03-16	0.12	32	Landmark story milestone.
2734	83	380	Vendetta of Stone	2021-07-28	1.00	28	Controversial issue banned in three states.
2735	127	122	Nemesis of Drake	2008-08-28	1.25	100	Double-sized anniversary issue.
2736	218	246	Oblivion of Steele	2018-01-18	0.20	80	Direct edition only; no newsstand version.
2737	28	208	Convergence of Drake	1983-08-16	0.50	28	Reprints classic story with new framing pages.
2738	229	607	Shattered of Price	1986-05-09	0.12	28	Landmark story milestone.
2739	142	14	Uprising of Burns	1994-09-23	4.99	28	High print run; common in collections.
2740	55	707	Oblivion of Kane	2008-04-21	3.99	80	Direct edition only; no newsstand version.
2741	24	646	Nemesis of Steele	1968-08-02	1.95	100	Key first appearance issue.
2742	260	101	Reborn of Burns	1999-03-07	3.99	80	Part of a crossover event.
2743	187	644	Rising of Voss	1962-03-19	0.50	64	Part of a crossover event.
2744	115	543	Convergence of Kane	1977-04-18	0.10	64	Controversial issue banned in three states.
2745	286	693	Fracture of Cole	2022-11-08	0.10	64	Controversial issue banned in three states.
2746	240	779	Dawn of Vale	2023-05-11	3.99	28	Direct edition only; no newsstand version.
2747	55	29	Descent of Cole	1979-04-15	0.20	100	Contains bonus pin-up gallery.
2748	80	208	Shattered of Hunt	2004-10-27	2.50	40	Contains bonus pin-up gallery.
2749	252	124	Descent of Stone	1974-05-19	4.99	44	High print run; common in collections.
2750	21	430	Descent of Kane	2023-01-07	0.10	32	Low distribution; considered scarce.
2751	281	690	Descent of Nash	2006-05-03	1.95	64	Double-sized anniversary issue.
2752	17	174	Chaos of Burns	1957-08-30	0.50	32	High print run; common in collections.
2753	203	167	Rising of Ward	2002-05-10	0.12	48	Reprints classic story with new framing pages.
2754	196	361	Fracture of Holt	1962-05-15	2.50	64	Key first appearance issue.
2755	200	699	Inferno of Voss	1994-09-12	2.99	100	Landmark story milestone.
2756	126	374	Fallen of Voss	1981-06-25	1.50	24	Landmark story milestone.
2757	209	149	Nemesis of Voss	1992-10-02	0.10	64	Key first appearance issue.
2758	112	373	Dawn of Cole	1964-09-23	1.00	32	Low distribution; considered scarce.
2759	109	767	Rising of Price	2024-11-18	0.75	100	Controversial issue banned in three states.
2760	148	300	Resurgence of Voss	2008-04-21	0.75	24	Key first appearance issue.
2761	155	757	Legacy of Price	1995-03-15	0.15	24	Part of a crossover event.
2762	118	151	Rising of Nash	1969-02-06	0.15	48	Contains bonus pin-up gallery.
2763	187	398	Vendetta of Ward	1974-05-04	0.75	36	Reprints classic story with new framing pages.
2764	169	318	Descent of Voss	2002-06-09	0.15	24	Part of a crossover event.
2765	9	780	Chaos of Stark	1969-08-28	2.99	40	Controversial issue banned in three states.
2766	252	600	Legacy of Kane	1968-05-04	1.50	64	High print run; common in collections.
2767	283	329	Rising of Steele	1972-10-12	0.15	64	Contains bonus pin-up gallery.
2768	169	138	Revelation of Hunt	1996-06-01	1.95	100	Contains bonus pin-up gallery.
2769	260	350	Inferno of Holt	1984-10-31	0.25	48	Key first appearance issue.
2770	237	233	Nemesis of Morgan	2019-11-26	0.25	40	Low distribution; considered scarce.
2771	223	791	Chaos of Crane	1969-04-18	3.99	64	Controversial issue banned in three states.
2772	19	67	Fracture of Kane	1980-01-12	0.10	64	High print run; common in collections.
2773	32	475	Rising of Nash	1961-03-20	2.50	40	Contains bonus pin-up gallery.
2774	273	771	Revelation of Stark	1996-07-11	0.12	36	Landmark story milestone.
2775	250	315	Revelation of Cole	1987-07-26	0.10	32	Contains bonus pin-up gallery.
2776	152	309	Resurgence of Flynn	1961-07-16	3.99	32	Direct edition only; no newsstand version.
2777	26	577	Convergence of Flynn	2015-11-28	1.00	48	Double-sized anniversary issue.
2778	207	462	Convergence of Grant	1999-08-14	1.25	24	Contains bonus pin-up gallery.
2779	214	257	Fallen of Morgan	1942-10-22	3.99	48	High print run; common in collections.
2780	74	70	Uprising of Flynn	2021-05-12	0.50	80	Direct edition only; no newsstand version.
2781	244	709	Fallen of Nash	2015-09-25	0.25	36	Double-sized anniversary issue.
2782	221	487	Shattered of Drake	1985-10-29	2.99	24	Low distribution; considered scarce.
2783	265	403	Reborn of Vale	1990-12-13	0.35	24	Part of a crossover event.
2784	190	266	Reckoning of Nash	2020-08-21	0.10	80	Reprints classic story with new framing pages.
2785	75	205	Reborn of Crane	1992-04-10	0.15	44	Reprints classic story with new framing pages.
2786	231	264	Reckoning of Flynn	1994-03-31	0.50	44	Direct edition only; no newsstand version.
2787	231	755	Oblivion of Cole	1977-08-04	3.99	64	Part of a crossover event.
2788	177	163	Legacy of Voss	1996-06-04	0.10	36	Double-sized anniversary issue.
2789	133	186	Oblivion of Stone	2002-08-26	2.50	32	Contains bonus pin-up gallery.
2790	106	62	Convergence of Cross	2001-01-08	0.25	64	Landmark story milestone.
2791	55	77	Fracture of Nash	2009-04-29	4.99	48	Reprints classic story with new framing pages.
2792	62	110	Legacy of Cross	1944-05-18	0.12	40	Controversial issue banned in three states.
2793	279	117	Vendetta of Holt	1962-05-06	2.50	100	Double-sized anniversary issue.
2794	120	384	Convergence of Kane	1982-09-23	2.99	100	Key first appearance issue.
2795	107	184	Convergence of Morgan	2002-02-10	0.35	48	Reprints classic story with new framing pages.
2796	282	98	Chaos of Cross	1976-08-15	2.50	40	Contains bonus pin-up gallery.
2797	40	433	Descent of Morgan	1945-05-05	0.15	64	Contains bonus pin-up gallery.
2798	10	222	Shadows of Ward	2024-05-04	0.50	64	Key first appearance issue.
2799	176	34	Vendetta of Hunt	2010-01-23	0.50	36	Controversial issue banned in three states.
2800	212	470	Convergence of Holt	2018-12-03	1.00	48	Reprints classic story with new framing pages.
2801	115	116	Fracture of Cross	2023-07-05	1.00	64	Direct edition only; no newsstand version.
2802	124	569	Reckoning of Grant	1961-07-17	0.75	100	Key first appearance issue.
2803	204	333	Chaos of Drake	2001-12-18	0.35	44	Reprints classic story with new framing pages.
2804	282	112	Shattered of Vale	1990-07-31	0.75	32	Contains bonus pin-up gallery.
2805	81	506	Convergence of Grant	2015-07-03	0.15	32	Reprints classic story with new framing pages.
2806	61	228	Inferno of Drake	1986-09-11	1.25	100	Direct edition only; no newsstand version.
2807	31	441	Legacy of Fox	2013-10-24	2.50	44	Controversial issue banned in three states.
2808	233	567	Vendetta of Nash	2016-12-06	0.50	100	Contains bonus pin-up gallery.
2809	136	767	Reborn of Nash	2021-06-30	0.10	64	Key first appearance issue.
2810	259	446	Vendetta of Morgan	2019-04-01	2.99	64	Part of a crossover event.
2811	212	23	Convergence of Drake	2019-12-10	0.10	28	Reprints classic story with new framing pages.
2812	88	48	Convergence of Cross	2011-05-07	0.15	44	Low distribution; considered scarce.
2813	122	34	Chaos of Holt	1999-08-06	0.12	100	High print run; common in collections.
2814	89	357	Uprising of Vale	2015-11-18	0.50	32	Key first appearance issue.
2815	86	367	Shadows of Drake	2008-12-22	0.25	44	Part of a crossover event.
2816	177	61	Rising of Price	2023-04-15	0.75	44	Low distribution; considered scarce.
2817	169	700	Dawn of Vale	2024-03-15	2.50	100	Double-sized anniversary issue.
2818	284	292	Uprising of Price	2017-07-27	0.50	36	High print run; common in collections.
2819	84	253	Nemesis of Cross	1958-04-21	2.99	32	Key first appearance issue.
2820	276	356	Reborn of Grant	1969-08-07	0.75	28	Controversial issue banned in three states.
2821	138	277	Shadows of Cross	2012-07-11	0.12	64	Part of a crossover event.
2822	202	627	Shattered of Price	2018-10-04	0.25	24	Landmark story milestone.
2823	74	509	Nemesis of Stone	2018-09-21	0.15	64	Contains bonus pin-up gallery.
2824	159	381	Chaos of Cross	1969-03-09	0.15	24	Direct edition only; no newsstand version.
2825	94	794	Chaos of Voss	2010-09-04	0.50	64	Part of a crossover event.
2826	51	136	Convergence of Ward	2022-02-22	3.99	28	High print run; common in collections.
2827	52	382	Revelation of Ward	2018-10-20	0.25	48	Low distribution; considered scarce.
2828	243	155	Resurgence of Ward	1988-02-23	1.00	48	Landmark story milestone.
2829	73	636	Legacy of Kane	1956-02-21	3.99	36	Key first appearance issue.
2830	3	676	Descent of Holt	1948-02-08	1.50	32	Low distribution; considered scarce.
2831	32	171	Rising of Voss	1954-04-15	1.95	36	Part of a crossover event.
2832	182	326	Rising of Holt	1953-11-22	0.50	32	Landmark story milestone.
2833	298	108	Vendetta of Vale	1957-03-05	0.12	80	Contains bonus pin-up gallery.
2834	249	473	Fallen of Holt	2022-08-18	3.99	100	Controversial issue banned in three states.
2835	192	760	Chaos of Steele	2002-07-13	0.25	28	Double-sized anniversary issue.
2836	280	726	Chaos of Flynn	2008-08-06	0.20	100	Controversial issue banned in three states.
2837	4	791	Descent of Stark	1973-11-06	4.99	24	Direct edition only; no newsstand version.
2838	253	392	Reborn of Stone	1990-03-22	0.50	36	Controversial issue banned in three states.
2839	286	363	Rising of Nash	2020-08-23	0.12	32	Part of a crossover event.
2840	240	682	Vendetta of Crane	2023-01-16	1.00	24	Double-sized anniversary issue.
2841	171	368	Resurgence of Cole	2020-04-17	0.50	80	Controversial issue banned in three states.
2842	165	448	Oblivion of Steele	1982-12-03	2.50	32	Key first appearance issue.
2843	261	408	Oblivion of Steele	1958-12-21	0.35	44	Low distribution; considered scarce.
2844	111	799	Eclipse of Nash	1973-09-01	0.15	100	Direct edition only; no newsstand version.
2845	87	163	Convergence of Cross	2018-10-31	1.95	24	Landmark story milestone.
2846	274	362	Nemesis of Cross	2004-01-22	1.25	64	Controversial issue banned in three states.
2847	283	194	Reborn of Holt	1973-08-12	0.35	24	Landmark story milestone.
2848	87	252	Chaos of Voss	1983-08-01	1.25	100	Reprints classic story with new framing pages.
2849	90	12	Reckoning of Price	2003-08-25	2.99	48	Controversial issue banned in three states.
2850	228	138	Legacy of Ward	1989-10-13	0.10	40	Part of a crossover event.
2851	27	370	Legacy of Stone	1998-01-10	0.35	28	Contains bonus pin-up gallery.
2852	146	41	Reckoning of Vale	2021-08-18	0.15	24	Landmark story milestone.
2853	295	252	Inferno of Stone	1943-03-26	0.35	32	Controversial issue banned in three states.
2854	153	96	Shadows of Hunt	1973-03-14	0.75	48	Key first appearance issue.
2855	24	22	Resurgence of Steele	1970-05-09	3.99	64	Key first appearance issue.
2856	165	288	Nemesis of Kane	1981-03-30	2.99	24	Contains bonus pin-up gallery.
2857	224	401	Vendetta of Stone	1997-10-27	1.95	24	Key first appearance issue.
2858	294	234	Fracture of Cross	2013-08-26	0.50	40	Direct edition only; no newsstand version.
2859	47	436	Fallen of Vale	1978-06-29	0.20	36	High print run; common in collections.
2860	211	13	Shattered of Holt	1958-04-15	1.25	28	Direct edition only; no newsstand version.
2861	154	205	Rising of Ward	1997-02-26	1.95	40	Low distribution; considered scarce.
2862	60	202	Fracture of Cross	1968-05-25	3.99	64	Direct edition only; no newsstand version.
2863	268	489	Legacy of Drake	1992-01-22	2.99	36	Low distribution; considered scarce.
2864	150	639	Dawn of Holt	2004-01-29	2.99	28	Contains bonus pin-up gallery.
2865	168	103	Resurgence of Grant	1982-04-05	3.99	24	Landmark story milestone.
2866	254	631	Reborn of Stone	2012-10-19	0.35	40	Controversial issue banned in three states.
2867	22	294	Descent of Vale	1965-07-26	3.99	40	Low distribution; considered scarce.
2868	137	788	Oblivion of Cross	1949-06-09	0.75	40	Part of a crossover event.
2869	220	344	Uprising of Cole	2005-07-07	2.50	100	Low distribution; considered scarce.
2870	230	780	Reckoning of Cross	1972-10-15	1.95	40	Double-sized anniversary issue.
2871	190	388	Fallen of Crane	2020-07-12	0.12	40	Contains bonus pin-up gallery.
2872	89	529	Legacy of Holt	2016-02-10	0.15	24	Key first appearance issue.
2873	174	513	Eclipse of Flynn	2016-08-20	4.99	40	Controversial issue banned in three states.
2874	47	744	Chaos of Vale	1978-03-11	1.50	100	Reprints classic story with new framing pages.
2875	9	596	Revelation of Stark	1967-09-24	0.15	40	Direct edition only; no newsstand version.
2876	26	501	Legacy of Kane	2016-09-16	1.25	36	Contains bonus pin-up gallery.
2877	259	269	Chaos of Stone	2018-09-20	3.99	24	Direct edition only; no newsstand version.
2878	193	556	Fracture of Nash	2005-09-11	2.99	40	Direct edition only; no newsstand version.
2879	240	696	Nemesis of Vale	2020-09-26	2.50	80	Landmark story milestone.
2880	189	711	Shadows of Cole	2021-05-01	1.95	80	Reprints classic story with new framing pages.
2881	293	62	Fallen of Fox	2012-05-17	4.99	32	Reprints classic story with new framing pages.
2882	57	796	Resurgence of Burns	1996-06-30	1.50	24	Contains bonus pin-up gallery.
2883	288	21	Vendetta of Vale	2007-04-10	1.95	48	Direct edition only; no newsstand version.
2884	18	38	Revelation of Vale	2017-10-14	3.99	40	Direct edition only; no newsstand version.
2885	261	217	Reckoning of Ward	1958-07-06	4.99	64	High print run; common in collections.
2886	12	483	Rising of Grant	1997-02-23	0.25	32	Controversial issue banned in three states.
2887	216	487	Reborn of Holt	1982-10-24	0.15	100	Key first appearance issue.
2888	263	521	Resurgence of Crane	2005-07-25	1.50	36	Double-sized anniversary issue.
2889	169	613	Dawn of Ward	2022-05-02	4.99	36	Reprints classic story with new framing pages.
2890	213	312	Convergence of Cole	2016-04-17	4.99	48	Key first appearance issue.
2891	162	331	Reckoning of Burns	1966-04-20	0.25	32	Landmark story milestone.
2892	234	269	Descent of Crane	1990-05-01	0.15	80	Direct edition only; no newsstand version.
2893	227	417	Nemesis of Stone	1943-05-03	0.35	24	Landmark story milestone.
2894	206	167	Reborn of Morgan	1989-04-12	4.99	36	Reprints classic story with new framing pages.
2895	298	786	Resurgence of Price	1951-12-28	0.15	100	Double-sized anniversary issue.
2896	82	123	Descent of Steele	1985-01-03	2.99	44	High print run; common in collections.
2897	120	93	Fracture of Morgan	1992-05-26	2.99	40	Reprints classic story with new framing pages.
2898	135	415	Reborn of Burns	2018-12-04	0.35	24	High print run; common in collections.
2899	275	90	Revelation of Flynn	1987-01-12	1.25	100	Key first appearance issue.
2900	58	368	Reborn of Price	2005-04-28	2.99	64	Key first appearance issue.
2901	195	66	Shattered of Flynn	1990-02-12	3.99	36	Key first appearance issue.
2902	189	622	Resurgence of Cross	2020-11-24	1.00	36	Double-sized anniversary issue.
2903	263	675	Revelation of Drake	1989-12-08	0.25	28	Contains bonus pin-up gallery.
2904	276	425	Oblivion of Cole	1971-07-04	0.10	48	Direct edition only; no newsstand version.
2905	139	695	Rising of Flynn	1999-12-13	0.12	28	Direct edition only; no newsstand version.
2906	130	670	Resurgence of Voss	2009-03-08	1.50	24	High print run; common in collections.
2907	230	118	Oblivion of Drake	1961-01-14	0.25	48	Low distribution; considered scarce.
2908	22	50	Uprising of Morgan	1978-01-07	0.12	80	Landmark story milestone.
2909	233	412	Fallen of Cole	2016-11-22	0.35	100	Direct edition only; no newsstand version.
2910	282	667	Vendetta of Burns	1983-10-19	1.50	24	Key first appearance issue.
2911	235	529	Resurgence of Hunt	2007-04-21	1.50	100	Controversial issue banned in three states.
2912	240	283	Shadows of Voss	2023-07-16	2.99	80	Key first appearance issue.
2913	217	702	Rising of Price	1996-02-21	2.50	28	Controversial issue banned in three states.
2914	242	402	Fallen of Morgan	2014-03-21	0.12	80	Controversial issue banned in three states.
2915	9	640	Rising of Fox	1972-05-20	0.12	32	Direct edition only; no newsstand version.
2916	100	271	Chaos of Holt	2000-02-01	0.50	44	Reprints classic story with new framing pages.
2917	196	658	Chaos of Flynn	1954-02-15	4.99	24	Landmark story milestone.
2918	92	754	Vendetta of Steele	1943-12-25	1.25	32	Part of a crossover event.
2919	111	611	Reckoning of Hunt	1968-07-28	0.15	32	High print run; common in collections.
2920	235	255	Reckoning of Cross	2012-03-02	1.00	100	Contains bonus pin-up gallery.
2921	208	722	Dawn of Vale	2017-10-29	2.50	64	Key first appearance issue.
2922	68	301	Revelation of Ward	2015-08-31	1.50	32	Low distribution; considered scarce.
2923	22	364	Revelation of Crane	1973-10-15	1.00	80	Landmark story milestone.
2924	273	451	Inferno of Holt	2012-02-17	0.10	36	Direct edition only; no newsstand version.
2925	140	560	Fallen of Kane	1991-09-21	1.95	100	Contains bonus pin-up gallery.
2926	256	531	Inferno of Holt	1984-04-26	2.50	48	Controversial issue banned in three states.
2927	102	237	Legacy of Drake	1966-06-05	2.50	48	Contains bonus pin-up gallery.
2928	271	291	Reborn of Voss	1951-04-16	0.25	44	Reprints classic story with new framing pages.
2929	159	497	Convergence of Steele	1968-09-18	0.12	40	Controversial issue banned in three states.
2930	269	189	Convergence of Crane	2004-09-04	0.25	24	Direct edition only; no newsstand version.
2931	214	75	Fracture of Hunt	1942-06-19	2.99	32	High print run; common in collections.
2932	177	625	Reborn of Price	2001-11-29	0.25	100	Reprints classic story with new framing pages.
2933	281	221	Eclipse of Grant	2011-07-25	4.99	48	Double-sized anniversary issue.
2934	264	728	Oblivion of Fox	2023-05-30	0.35	44	Direct edition only; no newsstand version.
2935	7	125	Revelation of Holt	1959-10-03	0.35	24	Double-sized anniversary issue.
2936	129	253	Rising of Flynn	2001-04-10	0.50	100	Double-sized anniversary issue.
2937	98	87	Fallen of Steele	2022-06-13	2.50	24	Key first appearance issue.
2938	3	297	Vendetta of Drake	1943-12-26	3.99	48	Controversial issue banned in three states.
2939	35	759	Revelation of Drake	2008-09-16	1.25	100	Landmark story milestone.
2940	112	122	Reckoning of Stone	1973-12-17	4.99	44	Controversial issue banned in three states.
2941	279	136	Dawn of Hunt	1964-07-17	2.99	44	Direct edition only; no newsstand version.
2942	153	761	Fallen of Burns	1969-10-16	0.10	44	Reprints classic story with new framing pages.
2943	78	532	Convergence of Vale	1947-04-01	1.50	36	Key first appearance issue.
2944	292	437	Legacy of Price	2011-09-25	0.20	100	Low distribution; considered scarce.
2945	287	411	Fallen of Hunt	1958-12-01	0.12	44	Direct edition only; no newsstand version.
2946	274	5	Shadows of Stark	2003-06-24	1.95	36	Key first appearance issue.
2947	230	419	Legacy of Kane	1973-10-22	2.99	100	Part of a crossover event.
2948	246	776	Vendetta of Morgan	1989-11-10	1.25	36	Low distribution; considered scarce.
2949	252	124	Convergence of Flynn	1962-10-12	0.75	28	High print run; common in collections.
2950	247	415	Rising of Morgan	1969-03-01	0.12	64	Contains bonus pin-up gallery.
2951	254	658	Convergence of Voss	1993-10-24	4.99	44	Key first appearance issue.
2952	116	89	Reborn of Cross	1957-09-13	0.12	32	Part of a crossover event.
2953	299	740	Shadows of Hunt	1975-05-08	0.50	80	Contains bonus pin-up gallery.
2954	100	471	Dawn of Stone	1989-09-17	1.25	32	Low distribution; considered scarce.
2955	159	460	Vendetta of Grant	1962-03-03	0.10	40	Contains bonus pin-up gallery.
2956	221	455	Descent of Crane	1983-02-22	0.25	36	Part of a crossover event.
2957	34	6	Oblivion of Crane	1964-12-03	1.50	28	Reprints classic story with new framing pages.
2958	37	645	Dawn of Grant	1992-02-20	1.95	28	Contains bonus pin-up gallery.
2959	123	171	Descent of Hunt	2022-12-24	1.95	28	Low distribution; considered scarce.
2960	181	198	Chaos of Drake	1993-03-15	0.15	80	Part of a crossover event.
2961	261	353	Inferno of Grant	1953-01-12	0.15	28	Part of a crossover event.
2962	232	278	Shattered of Ward	1964-05-18	1.95	36	Reprints classic story with new framing pages.
2963	60	49	Oblivion of Stark	1964-06-19	0.10	24	Low distribution; considered scarce.
2964	6	252	Reckoning of Burns	1996-03-08	1.50	40	Landmark story milestone.
2965	277	19	Revelation of Price	1966-02-05	0.25	32	Landmark story milestone.
2966	277	698	Uprising of Hunt	1963-04-09	2.50	48	Controversial issue banned in three states.
2967	21	527	Inferno of Grant	2020-09-04	2.50	40	Key first appearance issue.
2968	228	554	Reckoning of Steele	2011-12-17	2.50	44	Controversial issue banned in three states.
2969	174	392	Vendetta of Crane	2016-04-02	0.50	36	High print run; common in collections.
2970	176	136	Uprising of Drake	2012-05-05	0.50	100	Contains bonus pin-up gallery.
2971	154	22	Resurgence of Cole	2002-10-29	0.12	48	Contains bonus pin-up gallery.
2972	22	738	Shattered of Grant	1980-09-05	4.99	24	Reprints classic story with new framing pages.
2973	87	696	Rising of Price	1972-09-06	0.15	80	Low distribution; considered scarce.
2974	114	95	Uprising of Steele	1964-10-08	2.50	48	Landmark story milestone.
2975	50	551	Chaos of Grant	1968-01-30	1.50	80	Key first appearance issue.
2976	176	409	Revelation of Cross	2010-11-30	0.20	28	Reprints classic story with new framing pages.
2977	207	303	Fracture of Cross	1994-06-14	0.25	24	Part of a crossover event.
2978	116	482	Reckoning of Stark	1959-09-27	4.99	40	Part of a crossover event.
2979	143	492	Dawn of Grant	1988-08-29	0.25	36	Landmark story milestone.
2980	228	66	Vendetta of Ward	2021-09-03	0.15	100	Reprints classic story with new framing pages.
2981	174	591	Chaos of Crane	2016-09-06	4.99	48	Direct edition only; no newsstand version.
2982	68	185	Revelation of Flynn	1984-07-21	2.50	24	Part of a crossover event.
2983	119	142	Nemesis of Voss	1998-04-22	1.25	24	Controversial issue banned in three states.
2984	192	569	Fracture of Morgan	1997-11-26	0.50	48	Double-sized anniversary issue.
2985	206	339	Dawn of Ward	1985-04-10	0.75	24	Direct edition only; no newsstand version.
2986	203	445	Reckoning of Nash	2004-09-15	0.12	32	Double-sized anniversary issue.
2987	45	273	Reckoning of Price	2009-06-25	0.20	24	High print run; common in collections.
2988	23	122	Convergence of Drake	1993-02-21	0.75	24	Controversial issue banned in three states.
2989	187	24	Shattered of Holt	1965-01-13	1.50	32	High print run; common in collections.
2990	236	583	Fracture of Price	1991-04-15	1.95	36	Landmark story milestone.
2991	295	192	Nemesis of Drake	1945-08-22	0.12	100	Double-sized anniversary issue.
2992	221	137	Fracture of Nash	1983-03-30	4.99	40	Part of a crossover event.
2993	132	280	Reborn of Steele	2015-10-15	0.12	44	Low distribution; considered scarce.
2994	286	711	Vendetta of Flynn	2017-04-25	0.75	80	Landmark story milestone.
2995	64	646	Descent of Kane	2002-09-24	2.50	44	Part of a crossover event.
2996	272	291	Vendetta of Flynn	1996-06-24	2.50	48	Controversial issue banned in three states.
2997	86	703	Inferno of Steele	2024-10-14	0.20	64	Reprints classic story with new framing pages.
2998	254	323	Legacy of Ward	1987-05-08	0.10	36	Direct edition only; no newsstand version.
2999	53	431	Fallen of Burns	2019-05-17	2.99	24	Contains bonus pin-up gallery.
3000	6	460	Fallen of Crane	1989-08-24	2.50	24	Controversial issue banned in three states.
\.


--
-- TOC entry 5112 (class 0 OID 32931)
-- Dependencies: 230
-- Data for Name: issue_character; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.issue_character (issue_id, character_id, appearance) FROM stdin;
2417	207	Main
500	60	Main
784	320	Supporting
861	588	Main
2602	488	Main
532	148	Main
1483	597	Supporting
348	370	Supporting
1954	579	Cameo
813	397	Cameo
1818	535	Supporting
1400	254	Cameo
1813	149	Flashback
244	400	Cameo
2532	392	Supporting
548	268	Supporting
2017	191	Supporting
426	223	Main
2788	336	Supporting
691	336	Main
1195	218	Main
754	96	Cameo
481	164	Main
2238	188	Supporting
690	97	Main
1273	480	Main
2708	328	Death
1157	255	Main
383	158	Main
2877	368	Supporting
1202	197	Main
2852	283	Main
882	188	Main
1911	527	Flashback
2625	113	Cameo
1354	31	Cameo
2391	571	Supporting
2446	277	Supporting
216	554	Supporting
339	416	Supporting
1890	165	Main
877	412	Supporting
1525	103	Supporting
180	476	Main
1532	65	Main
895	296	Supporting
1481	435	Main
2427	293	Main
1179	7	Cameo
1236	429	Main
1135	377	Main
801	501	Supporting
158	124	Supporting
399	334	Main
36	6	Main
1216	37	Supporting
396	180	Cameo
2406	588	Main
610	234	Cameo
1587	113	Supporting
456	375	Main
1912	454	Main
1177	135	Main
2174	514	Main
1856	577	Supporting
2626	315	Main
1427	161	Main
39	250	Cameo
2836	321	Supporting
82	108	Main
685	583	Main
207	106	Cameo
2889	167	Cameo
2517	242	Main
2581	364	Supporting
619	143	Main
684	86	Cameo
1519	78	Main
2260	554	Cameo
2	556	Supporting
202	398	Main
1527	232	Main
385	277	Cameo
100	562	Supporting
1235	359	Main
2632	565	Main
1649	549	Supporting
360	496	Supporting
1074	504	Supporting
1970	258	Supporting
2977	341	Main
1216	271	Supporting
2652	560	Supporting
1635	235	Supporting
1550	31	Main
1619	583	Main
2839	429	Main
2286	476	Main
299	357	Main
2542	357	Main
1711	251	Cameo
1377	305	Main
2910	444	Main
2584	341	Main
1134	312	Main
1906	354	Supporting
2102	65	Supporting
2573	414	Main
557	308	Cameo
857	204	Main
2198	362	Main
472	131	Death
1065	525	Death
2915	103	Main
1723	543	Main
102	348	Main
1695	8	Main
2358	578	Supporting
793	150	Cameo
2637	66	Supporting
1116	412	Main
1615	212	Flashback
2175	152	Main
2454	48	Main
2155	455	Supporting
376	450	Flashback
1693	551	Main
2075	578	Flashback
478	23	Main
162	558	Main
1276	34	Main
2182	597	Main
1719	341	Supporting
74	44	Supporting
1021	66	Supporting
2180	324	Main
2278	163	Main
1111	145	Main
2099	387	Main
218	465	Main
2143	399	Main
1449	417	Cameo
1946	521	Flashback
368	398	Flashback
218	449	Main
1810	249	Main
2050	380	Main
2017	473	Supporting
1949	274	Supporting
1043	1	Supporting
676	185	Supporting
354	541	Main
604	419	Cameo
27	387	Main
1777	522	Main
2893	447	Main
2144	183	Cameo
1260	108	Cameo
2862	473	Supporting
1649	519	Death
1078	173	Supporting
2007	524	Supporting
663	336	Cameo
2151	405	Cameo
2831	159	Supporting
499	367	Main
507	373	Main
1947	447	Main
2333	390	Main
720	548	Flashback
562	369	Main
1426	341	Cameo
271	270	Main
1479	518	Main
1101	205	Flashback
2436	354	Main
422	555	Supporting
971	109	Cameo
1487	255	Main
2723	524	Supporting
1559	378	Main
855	237	Supporting
2301	46	Main
446	107	Main
711	373	Death
2103	437	Supporting
1345	422	Main
1943	104	Cameo
1852	374	Cameo
513	308	Cameo
2757	47	Supporting
2866	360	Supporting
443	253	Supporting
2309	236	Main
1928	267	Supporting
2379	373	Cameo
175	50	Main
263	553	Cameo
2590	58	Main
1758	38	Main
2043	532	Main
1542	239	Cameo
2156	410	Main
2951	439	Main
2092	485	Supporting
791	300	Cameo
2576	263	Supporting
2477	255	Supporting
1084	74	Main
1945	17	Main
1928	30	Main
2698	195	Cameo
359	287	Main
2075	154	Death
2587	58	Main
178	398	Supporting
2916	83	Main
1807	430	Main
2638	409	Main
1405	510	Cameo
692	1	Main
2652	63	Supporting
38	38	Main
2679	156	Main
17	409	Main
483	125	Supporting
33	393	Cameo
2286	492	Cameo
2996	42	Supporting
1262	168	Main
1675	424	Main
1150	358	Main
1388	37	Supporting
1087	35	Supporting
2425	301	Cameo
2639	360	Cameo
580	129	Main
257	234	Supporting
1339	134	Main
1694	269	Flashback
1018	352	Supporting
623	375	Main
501	522	Cameo
829	482	Main
1404	465	Cameo
1968	314	Main
2618	432	Death
1736	156	Main
2868	334	Supporting
2108	314	Supporting
2119	276	Main
325	437	Supporting
2650	587	Supporting
1726	101	Main
1319	385	Supporting
700	410	Supporting
263	265	Supporting
1500	337	Supporting
353	303	Main
1865	15	Main
2763	17	Cameo
1988	195	Supporting
1876	343	Supporting
372	106	Supporting
2160	431	Supporting
937	123	Cameo
2137	529	Main
1390	338	Main
371	431	Main
1750	89	Supporting
2542	379	Cameo
1218	174	Main
1023	333	Cameo
1480	243	Main
2512	308	Main
2900	398	Main
2398	332	Supporting
1149	282	Main
50	600	Supporting
2293	160	Supporting
2124	144	Cameo
2641	343	Cameo
2373	437	Main
48	517	Main
2854	491	Flashback
561	348	Main
2220	513	Main
2297	344	Main
2402	81	Flashback
731	398	Main
2235	428	Main
898	377	Main
2430	498	Main
1390	327	Main
781	547	Supporting
698	160	Main
2981	279	Main
495	457	Main
2058	580	Main
1988	313	Death
2156	148	Main
2167	154	Supporting
1806	362	Supporting
2128	464	Main
181	477	Supporting
281	47	Cameo
500	237	Main
1790	597	Cameo
2381	225	Main
2569	513	Main
2761	222	Main
2066	498	Main
1576	255	Supporting
615	538	Main
2898	515	Main
2647	558	Main
2621	265	Cameo
1995	370	Supporting
1881	229	Cameo
1674	559	Supporting
1504	50	Supporting
1236	321	Main
1366	183	Main
305	540	Supporting
348	20	Supporting
100	204	Main
215	252	Main
548	487	Main
402	475	Supporting
2171	403	Main
1145	314	Cameo
2256	505	Cameo
2857	517	Flashback
981	435	Death
154	43	Cameo
2490	518	Main
2638	378	Supporting
2230	189	Cameo
290	303	Cameo
2577	104	Main
687	481	Main
2276	584	Main
2106	572	Main
513	117	Main
537	555	Main
9	445	Supporting
1730	552	Flashback
1120	258	Supporting
2400	295	Supporting
357	463	Main
549	134	Main
720	286	Flashback
2268	32	Main
657	468	Main
1376	523	Supporting
1576	585	Main
523	515	Flashback
1088	252	Cameo
1187	141	Cameo
214	339	Main
1173	57	Cameo
22	362	Main
2584	216	Supporting
2869	292	Main
803	463	Cameo
1528	13	Supporting
2672	394	Death
2328	177	Main
2815	166	Main
1933	381	Main
1047	89	Supporting
2229	140	Cameo
729	520	Main
226	147	Main
892	440	Cameo
361	222	Supporting
2327	175	Main
887	517	Supporting
2933	287	Flashback
2776	297	Main
658	150	Main
2667	3	Flashback
1847	548	Main
31	458	Death
1653	298	Main
2742	131	Cameo
1860	39	Main
422	237	Death
1519	587	Supporting
2950	241	Death
361	180	Supporting
2390	513	Main
364	521	Supporting
2776	3	Main
522	205	Flashback
415	169	Main
575	362	Cameo
1109	526	Flashback
1151	405	Main
2025	313	Main
1334	351	Main
1849	321	Supporting
2330	274	Main
524	345	Main
577	327	Supporting
2195	374	Supporting
258	82	Main
2340	272	Main
1531	9	Supporting
1733	380	Main
701	350	Main
626	155	Cameo
2301	24	Supporting
2892	157	Main
697	584	Main
2874	297	Cameo
100	331	Main
1738	568	Main
810	213	Cameo
668	37	Main
2256	466	Main
369	88	Main
2454	458	Cameo
821	40	Main
2123	433	Main
2947	353	Main
2879	570	Main
2372	563	Main
1904	110	Supporting
649	83	Main
1640	571	Supporting
2605	242	Supporting
1464	354	Main
1413	105	Main
2741	599	Main
1034	414	Main
967	51	Supporting
2216	7	Main
2720	5	Supporting
707	497	Cameo
526	505	Supporting
1764	15	Main
500	92	Main
1702	242	Death
494	67	Main
2088	274	Supporting
1397	468	Supporting
2650	197	Cameo
2809	230	Cameo
2121	104	Cameo
1025	20	Main
1172	503	Main
2387	408	Main
1083	442	Main
1359	109	Main
1228	328	Main
2352	454	Supporting
420	467	Supporting
33	281	Main
404	72	Main
1824	332	Main
2311	196	Main
12	421	Supporting
430	494	Main
2877	354	Supporting
2534	502	Main
1960	489	Main
466	440	Main
1184	61	Cameo
324	399	Flashback
1313	578	Main
1047	369	Main
2507	485	Main
2770	32	Supporting
2445	200	Main
1314	590	Main
1758	110	Main
2192	576	Main
2033	324	Main
1253	567	Death
2759	48	Death
693	510	Main
2795	245	Main
1134	416	Main
2874	488	Main
2579	45	Main
574	511	Main
2799	511	Cameo
1272	202	Death
1253	484	Main
2802	58	Main
705	442	Cameo
45	502	Main
1577	580	Supporting
885	345	Supporting
2139	193	Supporting
2946	566	Cameo
1834	115	Flashback
2915	414	Cameo
1323	585	Supporting
1161	309	Main
70	232	Main
803	127	Main
2599	523	Flashback
2987	580	Flashback
1046	163	Main
526	337	Supporting
422	369	Cameo
1557	329	Main
2783	556	Main
1976	223	Main
756	24	Main
1787	520	Cameo
821	274	Main
489	537	Cameo
74	297	Supporting
242	12	Main
1617	505	Main
2153	507	Flashback
518	275	Main
523	573	Main
884	54	Main
2368	188	Main
948	534	Main
2287	183	Cameo
2024	26	Cameo
2922	410	Supporting
647	69	Supporting
1445	502	Death
309	369	Main
952	126	Flashback
1347	247	Cameo
930	456	Supporting
1567	44	Main
478	540	Cameo
983	419	Supporting
655	599	Supporting
771	213	Main
303	345	Main
1950	562	Death
851	11	Main
796	29	Supporting
1553	317	Main
1318	567	Supporting
2247	594	Death
1988	314	Supporting
2690	560	Main
2638	550	Supporting
2801	197	Flashback
399	560	Cameo
2684	250	Supporting
75	133	Death
356	335	Supporting
982	159	Death
27	548	Flashback
2876	421	Death
2949	387	Supporting
582	516	Main
1184	484	Main
357	66	Cameo
2431	518	Cameo
241	302	Supporting
458	417	Main
775	256	Main
707	571	Supporting
1513	490	Cameo
255	106	Main
2477	418	Main
2332	426	Main
2639	444	Supporting
2884	10	Main
1665	431	Supporting
190	210	Main
2767	454	Supporting
857	577	Supporting
2315	417	Main
729	590	Main
280	209	Main
1155	69	Cameo
2233	215	Supporting
2800	74	Supporting
1413	388	Main
1389	48	Supporting
717	134	Supporting
41	281	Main
2767	226	Main
2429	134	Main
2756	29	Cameo
1146	523	Flashback
724	285	Main
2242	219	Supporting
887	362	Main
603	32	Main
2796	65	Cameo
2410	19	Main
2905	496	Main
1134	144	Main
710	51	Supporting
1510	551	Supporting
2519	27	Supporting
1478	77	Main
1162	553	Flashback
2430	517	Main
522	20	Flashback
2198	430	Main
1680	282	Main
2189	273	Main
1526	168	Main
2411	534	Cameo
750	64	Cameo
2342	43	Main
1615	411	Main
433	372	Main
1077	504	Main
654	249	Supporting
857	441	Main
1715	290	Main
2154	299	Supporting
1375	8	Main
1468	20	Main
2070	49	Supporting
419	329	Supporting
1836	416	Main
2558	403	Main
152	466	Cameo
1482	514	Main
2492	207	Cameo
2853	425	Death
542	178	Supporting
503	266	Flashback
2599	345	Supporting
1543	242	Supporting
1045	224	Cameo
2451	596	Cameo
285	179	Main
903	39	Main
2487	229	Death
1823	479	Supporting
253	406	Main
2069	488	Cameo
2981	49	Death
2625	83	Supporting
2766	68	Main
1576	600	Flashback
822	274	Supporting
225	338	Cameo
1396	392	Main
2774	169	Main
1846	281	Main
2622	454	Cameo
2100	303	Main
1894	122	Cameo
2744	65	Main
1405	410	Cameo
2282	429	Cameo
461	270	Cameo
1692	284	Death
2353	237	Cameo
342	473	Main
2450	12	Cameo
2102	489	Supporting
54	61	Cameo
1511	111	Death
2277	176	Supporting
1616	47	Main
1335	256	Main
1194	71	Cameo
469	2	Main
137	76	Main
552	74	Main
2590	588	Death
610	541	Cameo
2505	194	Main
2446	499	Death
1715	251	Main
2314	201	Death
909	54	Death
50	157	Cameo
698	556	Supporting
668	123	Main
35	42	Main
566	134	Main
1980	311	Supporting
1660	45	Main
1102	525	Supporting
646	257	Main
1780	26	Supporting
695	16	Cameo
717	475	Main
2898	596	Main
1099	323	Main
2286	191	Main
2606	174	Cameo
1773	136	Main
677	503	Main
1358	219	Supporting
776	502	Main
925	455	Main
308	191	Main
1093	37	Death
2197	353	Main
813	147	Supporting
1685	340	Flashback
929	121	Main
1080	531	Main
2179	182	Flashback
2494	51	Main
1296	312	Main
975	270	Supporting
1347	280	Main
556	239	Main
295	427	Main
1507	187	Main
2709	566	Main
2741	473	Main
788	269	Supporting
1365	149	Cameo
1032	365	Cameo
1148	150	Supporting
244	363	Main
2797	504	Main
2656	523	Supporting
51	463	Cameo
2967	117	Main
2591	562	Cameo
2874	393	Main
2720	347	Main
172	25	Cameo
702	141	Main
650	445	Cameo
2290	571	Cameo
2397	369	Main
1955	2	Cameo
2004	30	Supporting
1979	196	Supporting
2786	239	Supporting
752	61	Main
2746	39	Main
49	92	Main
2291	51	Main
711	573	Cameo
461	4	Main
2228	543	Main
431	343	Main
1190	108	Main
2378	165	Main
1170	57	Cameo
1614	181	Supporting
572	364	Death
1502	378	Death
2090	494	Main
1959	596	Main
2716	310	Main
717	53	Main
2712	205	Death
2903	533	Main
257	384	Death
1975	338	Main
2499	415	Main
1088	155	Flashback
1606	415	Main
1988	186	Supporting
2092	274	Main
98	24	Main
1196	230	Cameo
402	41	Flashback
1778	63	Supporting
2980	27	Supporting
1881	47	Main
1001	12	Main
448	221	Death
129	516	Supporting
55	380	Main
717	210	Main
1434	512	Main
1459	124	Flashback
504	241	Death
1026	182	Supporting
2618	527	Main
344	287	Main
988	581	Supporting
2357	10	Main
1902	594	Death
2934	593	Supporting
2942	354	Supporting
1372	507	Main
2933	495	Main
1238	102	Supporting
420	434	Main
2275	192	Main
2886	204	Cameo
584	267	Main
1196	122	Supporting
1898	204	Supporting
2351	328	Supporting
623	370	Cameo
1091	29	Main
1311	275	Cameo
1581	243	Supporting
356	568	Main
85	11	Cameo
1601	143	Main
1727	98	Cameo
2287	307	Main
1934	429	Flashback
2620	501	Flashback
2463	521	Cameo
2159	577	Main
645	534	Main
1194	224	Main
2926	566	Supporting
2133	352	Cameo
637	328	Cameo
2278	525	Main
2337	408	Supporting
1459	171	Main
2966	330	Cameo
121	254	Supporting
1341	227	Supporting
1373	221	Main
2984	200	Main
1459	133	Main
2963	519	Main
1982	347	Main
1096	241	Cameo
261	190	Death
2582	421	Main
2408	459	Cameo
1009	108	Main
1851	186	Main
1506	309	Main
2107	435	Supporting
13	121	Supporting
2991	270	Flashback
2844	106	Main
3	552	Main
76	497	Main
1380	164	Main
2619	559	Death
1656	121	Supporting
1352	43	Death
1480	335	Main
201	551	Death
798	16	Main
475	356	Main
384	63	Flashback
1897	551	Main
249	254	Supporting
429	211	Cameo
362	600	Main
548	467	Main
251	203	Main
1579	442	Death
38	445	Main
2276	484	Supporting
2284	67	Cameo
2393	280	Supporting
2750	345	Main
252	404	Supporting
1390	332	Supporting
2939	582	Cameo
1354	182	Cameo
1091	185	Main
1285	61	Supporting
417	386	Cameo
427	345	Main
2564	401	Main
907	68	Main
906	16	Flashback
1017	7	Main
2762	360	Cameo
699	45	Supporting
651	208	Main
2535	388	Supporting
2099	562	Supporting
944	69	Main
2427	416	Main
2085	422	Main
2220	262	Death
1087	281	Main
616	116	Cameo
274	495	Cameo
1566	152	Cameo
2563	114	Main
2393	316	Main
1691	4	Main
60	8	Cameo
868	585	Main
2556	117	Main
559	361	Supporting
2869	157	Supporting
2397	572	Main
584	118	Main
2419	505	Cameo
352	191	Supporting
2764	288	Cameo
2879	203	Main
2864	146	Main
2007	241	Flashback
735	173	Supporting
1850	106	Main
2988	192	Main
2450	332	Cameo
1255	2	Supporting
1146	235	Cameo
2934	523	Supporting
2213	427	Supporting
1146	564	Main
114	402	Cameo
1525	407	Supporting
816	21	Supporting
2968	40	Main
2761	493	Main
1358	426	Cameo
1841	394	Cameo
960	273	Main
535	237	Main
1121	277	Main
86	258	Main
1262	177	Main
2977	12	Main
791	366	Main
401	298	Supporting
455	436	Flashback
2638	92	Main
2163	262	Main
1686	93	Flashback
1618	178	Cameo
552	413	Supporting
1714	146	Main
790	480	Main
1942	406	Flashback
2463	5	Main
1465	12	Cameo
1155	530	Main
62	222	Cameo
1269	420	Supporting
883	59	Death
1156	515	Cameo
2820	179	Main
1944	416	Supporting
595	480	Supporting
2115	1	Cameo
278	184	Main
2548	579	Main
2491	53	Cameo
1720	174	Supporting
1247	310	Main
1517	178	Cameo
824	39	Main
1382	499	Cameo
419	149	Supporting
1452	213	Main
2722	296	Supporting
2665	574	Cameo
304	202	Flashback
231	316	Cameo
1207	508	Main
531	123	Main
1379	269	Supporting
2197	186	Main
2293	570	Main
1309	470	Cameo
2391	184	Main
1745	161	Main
2301	305	Cameo
2611	20	Main
640	119	Main
1751	373	Supporting
1441	232	Main
1098	228	Cameo
355	480	Main
231	403	Main
2643	370	Supporting
206	492	Flashback
172	456	Death
253	479	Cameo
982	583	Death
891	335	Flashback
101	594	Main
2378	205	Supporting
367	534	Main
2104	247	Supporting
2145	331	Supporting
1046	393	Supporting
1609	386	Flashback
2925	399	Main
275	561	Supporting
173	597	Main
2866	1	Cameo
960	165	Cameo
2127	364	Main
2633	66	Supporting
2834	210	Main
2153	402	Main
2800	91	Main
1994	321	Main
75	497	Supporting
1488	406	Supporting
1750	562	Main
2008	509	Death
2346	55	Cameo
237	89	Cameo
2581	195	Supporting
2846	546	Main
1821	554	Main
294	593	Cameo
371	256	Supporting
264	121	Flashback
226	334	Supporting
1203	399	Main
1598	110	Flashback
1059	486	Supporting
1869	580	Main
2089	595	Main
2441	274	Supporting
926	254	Supporting
528	364	Supporting
1142	60	Supporting
121	358	Supporting
1353	238	Main
550	112	Main
2963	247	Cameo
2821	429	Supporting
1430	118	Supporting
2432	261	Main
1629	268	Main
2370	554	Cameo
1775	519	Main
2288	224	Main
1556	162	Main
95	231	Supporting
2211	345	Supporting
1092	488	Main
491	340	Main
1316	178	Main
2168	200	Main
581	219	Death
114	549	Main
2595	474	Main
1631	18	Death
1972	441	Main
1132	132	Flashback
1265	265	Main
1615	556	Supporting
2980	62	Cameo
633	496	Supporting
2437	583	Supporting
2331	301	Supporting
2513	285	Cameo
2579	57	Cameo
494	529	Supporting
2136	592	Cameo
1578	435	Main
2360	234	Cameo
2889	391	Main
231	519	Supporting
1507	420	Flashback
159	32	Cameo
733	597	Main
2884	503	Main
1223	197	Main
1536	218	Main
1946	399	Main
2454	535	Main
1948	249	Cameo
2977	566	Cameo
508	367	Main
2401	543	Main
2862	251	Death
2016	456	Main
430	356	Cameo
1759	201	Supporting
893	310	Supporting
2944	126	Supporting
360	182	Supporting
731	594	Main
824	590	Main
597	56	Cameo
1060	514	Main
1375	369	Supporting
680	59	Main
1288	140	Main
323	142	Supporting
2580	563	Main
1524	37	Supporting
2338	397	Main
2101	242	Cameo
2133	541	Flashback
2160	10	Main
1884	242	Cameo
813	543	Main
2077	495	Supporting
2526	82	Supporting
1812	155	Main
1385	187	Supporting
2204	109	Main
393	195	Main
2481	174	Supporting
402	26	Main
861	593	Cameo
1853	17	Main
275	213	Main
2847	380	Main
844	543	Supporting
2068	249	Main
2500	453	Supporting
2961	118	Main
1899	330	Main
2516	559	Cameo
474	78	Cameo
57	573	Main
1788	10	Supporting
2235	584	Supporting
2682	111	Supporting
637	521	Main
1981	101	Main
2261	304	Flashback
440	93	Main
2588	291	Main
2810	207	Main
1394	435	Cameo
225	63	Cameo
1882	41	Main
834	18	Supporting
551	504	Main
340	566	Main
2118	421	Supporting
816	61	Main
2026	433	Main
219	260	Supporting
597	492	Supporting
1519	252	Main
1522	412	Supporting
1707	564	Main
2818	60	Supporting
2474	148	Supporting
78	315	Main
2528	383	Supporting
2756	224	Main
920	350	Main
881	455	Main
161	35	Main
2128	321	Main
855	569	Cameo
1148	450	Cameo
330	7	Flashback
2115	506	Main
305	480	Main
1835	153	Main
323	60	Death
493	32	Supporting
1448	592	Main
2714	107	Main
447	170	Main
2045	229	Main
2228	80	Main
1184	513	Main
87	348	Main
1895	172	Flashback
1354	449	Cameo
1871	177	Main
2477	326	Supporting
1268	249	Death
461	167	Flashback
779	359	Supporting
2231	151	Main
1222	539	Cameo
585	538	Death
30	522	Main
1560	173	Supporting
865	395	Main
2360	85	Main
432	256	Flashback
1389	3	Main
2185	352	Death
1301	181	Main
1602	527	Death
2833	53	Supporting
165	402	Supporting
847	359	Cameo
1965	146	Cameo
2063	563	Main
1415	313	Main
1917	177	Flashback
729	99	Main
343	410	Death
950	114	Supporting
2542	343	Death
2634	562	Death
248	421	Supporting
306	79	Cameo
1751	35	Cameo
2578	56	Cameo
259	173	Main
436	141	Main
1262	503	Cameo
969	537	Main
1276	528	Cameo
1169	519	Supporting
2846	233	Cameo
1675	585	Death
64	132	Main
190	577	Main
1531	479	Supporting
2302	94	Main
2854	274	Main
435	312	Cameo
1298	482	Main
2476	384	Main
502	63	Cameo
1653	5	Main
2197	580	Main
490	114	Main
1222	298	Supporting
1991	423	Supporting
447	293	Supporting
1089	205	Main
1423	64	Main
1702	513	Main
2471	314	Cameo
2710	380	Main
1289	264	Supporting
1485	173	Main
1517	525	Supporting
515	597	Cameo
1496	4	Main
1495	151	Main
407	4	Supporting
2633	90	Main
43	578	Main
2530	200	Main
1633	172	Supporting
654	376	Supporting
1207	567	Main
1125	380	Supporting
2427	325	Main
1768	213	Main
1535	344	Supporting
197	159	Main
125	473	Death
2438	388	Supporting
2207	162	Supporting
1552	82	Supporting
561	525	Main
102	276	Main
524	55	Supporting
1254	225	Cameo
472	11	Death
957	18	Main
2716	201	Main
452	72	Main
1594	248	Main
2206	566	Main
1223	418	Main
2174	415	Main
1130	525	Main
1457	246	Death
354	188	Main
336	15	Main
2863	411	Main
1298	430	Supporting
1097	244	Main
2874	311	Supporting
1043	264	Supporting
2712	390	Cameo
1067	310	Main
271	78	Main
1815	15	Supporting
2610	46	Flashback
856	39	Main
1679	92	Cameo
385	569	Main
136	264	Main
1252	284	Death
1072	411	Main
2364	573	Supporting
578	530	Main
269	316	Supporting
2580	497	Supporting
2853	347	Supporting
2630	225	Main
254	341	Death
1103	113	Main
429	524	Supporting
656	455	Death
157	2	Main
2763	580	Cameo
650	106	Main
2501	26	Supporting
61	334	Death
2898	427	Flashback
1981	293	Cameo
2570	127	Cameo
1826	551	Supporting
226	207	Supporting
960	34	Cameo
2427	241	Main
2626	524	Main
881	2	Supporting
557	92	Main
2502	600	Supporting
1161	331	Cameo
287	552	Main
1044	117	Main
2441	28	Main
1591	581	Main
2908	557	Cameo
1364	218	Main
315	59	Main
116	480	Flashback
2412	387	Main
27	190	Main
2167	126	Cameo
1945	108	Main
994	162	Main
2680	335	Supporting
2636	507	Supporting
291	62	Cameo
528	515	Supporting
257	420	Cameo
2827	565	Cameo
958	76	Flashback
1457	381	Main
1300	426	Main
2884	497	Supporting
2500	3	Main
1232	126	Death
1735	390	Supporting
384	89	Death
850	296	Main
2615	325	Main
1246	143	Main
2465	422	Supporting
2400	442	Supporting
1828	422	Supporting
2521	585	Cameo
209	479	Supporting
2062	122	Main
49	268	Main
999	508	Supporting
2905	435	Main
171	298	Death
1971	44	Main
963	313	Main
977	72	Cameo
298	379	Main
2612	493	Main
2207	228	Main
2816	484	Supporting
2509	21	Supporting
1027	355	Main
2802	297	Death
624	26	Main
807	46	Main
526	202	Supporting
2618	256	Supporting
1112	53	Main
1848	84	Main
813	574	Main
1032	498	Main
1913	566	Main
456	400	Death
2916	321	Flashback
2880	492	Main
1515	88	Main
1179	581	Main
2754	395	Main
1834	446	Main
1987	93	Main
858	297	Supporting
1659	576	Main
2159	335	Main
1867	350	Main
1346	502	Supporting
171	26	Main
2087	238	Main
2627	599	Main
976	415	Main
950	61	Main
2487	533	Supporting
2938	93	Supporting
2519	345	Supporting
2046	568	Flashback
2935	239	Main
1362	385	Cameo
941	269	Main
310	438	Cameo
317	57	Flashback
1573	355	Main
2680	97	Main
614	176	Main
630	202	Main
1390	524	Supporting
1125	396	Cameo
1358	154	Flashback
2959	310	Supporting
580	325	Main
2777	478	Supporting
313	198	Cameo
2053	384	Main
2061	411	Supporting
155	306	Cameo
1908	80	Supporting
564	83	Supporting
2187	7	Cameo
2036	402	Main
1485	261	Main
2126	9	Flashback
2582	438	Main
2132	452	Main
330	221	Main
281	151	Main
260	432	Main
1826	404	Supporting
982	415	Main
1826	187	Cameo
1360	561	Cameo
1565	557	Main
414	176	Main
2465	543	Main
1317	258	Cameo
1070	251	Main
2616	590	Main
1622	473	Death
1637	198	Cameo
1336	110	Main
374	45	Death
1077	230	Main
116	299	Main
367	35	Cameo
700	332	Supporting
1209	460	Main
2869	493	Main
360	477	Main
901	354	Supporting
277	520	Flashback
1691	595	Supporting
1939	154	Supporting
1938	88	Main
458	156	Main
1246	88	Supporting
2212	499	Supporting
824	246	Main
227	434	Main
2689	462	Cameo
285	248	Main
537	143	Main
631	133	Death
1818	445	Main
2007	468	Flashback
113	35	Main
706	547	Main
1411	351	Supporting
1855	187	Supporting
1110	560	Supporting
2444	564	Main
2886	118	Main
2092	586	Main
1008	372	Main
1509	142	Supporting
2632	407	Cameo
86	396	Main
1400	406	Main
854	141	Cameo
45	51	Supporting
2501	345	Death
2358	71	Main
2802	183	Main
1336	4	Cameo
1765	254	Death
1692	175	Main
2199	181	Cameo
663	337	Main
1001	522	Main
781	96	Main
1295	573	Main
2835	272	Main
250	586	Main
2145	280	Main
1767	161	Flashback
182	275	Cameo
768	316	Main
2047	600	Main
1835	197	Cameo
993	167	Cameo
361	111	Supporting
138	523	Flashback
2640	164	Supporting
910	556	Main
1127	220	Supporting
1407	470	Cameo
2491	47	Main
557	87	Supporting
1370	126	Death
1300	375	Main
1866	243	Supporting
1798	385	Main
1862	142	Cameo
1917	571	Cameo
2875	497	Supporting
2582	338	Flashback
2484	501	Main
1192	430	Main
2718	488	Cameo
146	358	Main
557	93	Main
561	339	Main
1515	524	Cameo
2711	224	Main
2136	173	Main
267	470	Cameo
2613	152	Main
2664	362	Supporting
1517	152	Main
1860	262	Main
2785	242	Flashback
1245	195	Main
540	166	Supporting
1825	175	Cameo
805	9	Main
2026	216	Main
126	309	Main
1182	10	Supporting
50	280	Main
1229	296	Main
758	174	Main
2971	137	Supporting
2022	158	Main
1131	249	Main
1916	459	Main
87	272	Cameo
2181	270	Main
2003	393	Death
597	566	Cameo
1379	377	Supporting
1259	571	Main
667	509	Main
1586	374	Main
2259	505	Main
2587	592	Main
436	244	Death
13	519	Cameo
2788	450	Main
1729	151	Main
2492	113	Main
873	111	Supporting
2751	271	Supporting
1133	396	Supporting
2379	330	Cameo
1636	393	Supporting
1368	412	Supporting
47	189	Supporting
2024	437	Supporting
1146	321	Main
974	62	Supporting
459	145	Main
925	300	Supporting
1366	493	Cameo
2690	317	Flashback
1223	77	Cameo
1184	306	Main
1313	284	Supporting
1310	229	Main
165	377	Main
1440	279	Supporting
338	339	Supporting
1259	278	Supporting
1397	13	Main
643	338	Main
2231	382	Supporting
2303	450	Death
2110	88	Main
2878	324	Main
2854	535	Supporting
1271	64	Cameo
1808	433	Supporting
482	381	Main
2271	31	Main
2992	517	Supporting
1745	591	Main
2720	14	Cameo
636	386	Cameo
2984	527	Main
1045	587	Main
2468	244	Main
2048	276	Death
1842	517	Main
1315	175	Main
261	380	Main
1296	416	Main
2611	306	Supporting
959	502	Main
2463	324	Cameo
2976	139	Main
847	35	Main
236	296	Main
1697	236	Supporting
2025	380	Supporting
2620	492	Supporting
750	586	Death
1254	400	Supporting
1485	521	Cameo
1400	469	Main
124	380	Main
1320	482	Main
2358	483	Main
807	168	Cameo
2765	85	Supporting
2562	110	Supporting
168	353	Main
1030	424	Supporting
707	595	Death
2878	548	Supporting
800	370	Supporting
1497	560	Cameo
207	455	Main
2232	141	Supporting
7	326	Main
557	409	Main
1141	283	Main
495	96	Main
936	516	Main
1578	158	Supporting
1074	256	Supporting
2831	422	Supporting
2959	316	Supporting
140	454	Main
982	310	Main
716	234	Main
1299	25	Main
2853	26	Main
2956	114	Flashback
2706	442	Main
2088	34	Main
465	106	Cameo
1052	91	Main
1482	523	Death
2073	421	Supporting
1196	403	Main
2633	166	Main
2547	172	Flashback
128	128	Main
2220	515	Main
670	405	Main
573	529	Cameo
557	502	Main
2934	386	Death
530	383	Supporting
1803	595	Main
1663	5	Main
747	462	Main
2832	217	Cameo
478	12	Main
2742	279	Flashback
1433	151	Main
1069	40	Cameo
866	374	Supporting
460	568	Supporting
2524	218	Main
1296	505	Main
1163	578	Main
2072	465	Supporting
1584	594	Supporting
342	415	Supporting
2829	82	Main
2731	265	Main
1610	222	Main
1763	229	Supporting
330	526	Supporting
2444	451	Supporting
2628	471	Main
2860	154	Main
2129	311	Supporting
1306	89	Main
747	437	Main
1802	332	Main
2090	301	Main
1227	32	Cameo
1089	116	Main
2194	202	Cameo
493	272	Main
2743	316	Main
2688	244	Cameo
133	195	Main
203	334	Main
1142	9	Main
1212	96	Death
710	257	Main
25	340	Supporting
2585	164	Main
1952	16	Supporting
2658	154	Main
2771	447	Main
1003	389	Supporting
1704	199	Main
2137	371	Main
2204	334	Supporting
600	323	Cameo
30	213	Supporting
391	154	Main
930	173	Supporting
2478	408	Supporting
1510	584	Cameo
1320	161	Main
360	488	Death
2951	565	Cameo
47	172	Supporting
225	328	Flashback
869	22	Cameo
224	387	Main
2936	126	Main
2731	23	Main
339	309	Supporting
2566	57	Cameo
2103	193	Main
412	21	Main
2743	137	Main
55	134	Main
186	600	Supporting
1387	598	Main
2596	441	Supporting
2094	279	Main
2601	152	Cameo
372	250	Main
784	279	Flashback
369	121	Supporting
1981	147	Main
713	199	Main
339	477	Main
288	195	Main
812	119	Main
2426	390	Supporting
1431	370	Death
2435	78	Supporting
1878	564	Main
2239	568	Main
1402	506	Main
1073	127	Supporting
1774	189	Main
456	438	Main
2653	177	Supporting
1847	238	Supporting
221	274	Main
2840	474	Flashback
1144	100	Supporting
2520	570	Main
2707	255	Main
2317	29	Cameo
1062	160	Main
898	86	Main
97	133	Main
1987	177	Main
2579	469	Supporting
2304	504	Supporting
2212	465	Supporting
633	398	Main
195	210	Main
701	214	Main
1161	526	Flashback
945	446	Main
1305	233	Supporting
2009	116	Supporting
862	151	Cameo
2410	337	Main
605	73	Main
2333	357	Main
874	240	Death
1387	82	Flashback
1463	96	Supporting
1373	44	Supporting
2323	494	Cameo
672	521	Death
204	572	Supporting
2286	517	Main
2118	573	Main
171	51	Main
2242	103	Main
907	132	Cameo
949	409	Main
1620	30	Main
2021	283	Supporting
1641	74	Flashback
1647	596	Cameo
1846	136	Cameo
2058	62	Death
2473	256	Supporting
1197	440	Supporting
2487	3	Supporting
463	50	Main
325	592	Cameo
1814	596	Supporting
2611	517	Death
255	278	Main
1652	3	Main
2356	84	Cameo
1035	175	Main
2537	164	Main
1990	216	Death
223	317	Cameo
2366	581	Main
140	337	Main
192	110	Main
1139	225	Main
428	69	Supporting
1759	499	Main
1414	108	Main
301	59	Main
1005	330	Main
2781	301	Supporting
687	253	Main
2742	216	Death
1962	357	Main
1085	99	Main
2252	184	Main
1271	188	Main
335	276	Cameo
1369	409	Main
2521	302	Cameo
1321	546	Main
1803	229	Cameo
2259	582	Main
63	86	Flashback
488	183	Flashback
2487	146	Main
1549	133	Death
326	68	Cameo
81	460	Main
2178	581	Cameo
847	149	Cameo
484	499	Main
1144	388	Death
1297	215	Flashback
374	323	Cameo
233	339	Main
150	106	Main
2699	23	Main
1814	401	Main
2541	585	Main
2096	131	Main
1125	9	Main
580	546	Main
1038	174	Flashback
169	339	Main
160	521	Cameo
1205	130	Cameo
2452	480	Supporting
1665	486	Main
571	421	Main
937	215	Flashback
829	162	Main
743	88	Cameo
2589	477	Main
2976	319	Main
1362	378	Main
2740	132	Supporting
1919	479	Death
622	71	Main
2757	431	Supporting
1143	590	Cameo
358	472	Cameo
1622	259	Supporting
2563	516	Main
1936	339	Supporting
613	61	Main
1936	20	Main
2576	394	Main
2774	207	Cameo
2747	474	Main
1303	216	Cameo
790	499	Main
2784	115	Main
1139	518	Main
2940	419	Main
925	106	Cameo
598	125	Supporting
739	471	Main
2312	429	Main
1216	510	Main
782	108	Main
2302	302	Flashback
335	436	Supporting
1025	473	Cameo
1387	386	Main
2486	111	Main
2987	377	Main
429	383	Main
1757	123	Supporting
622	573	Death
946	282	Main
2242	174	Main
1793	540	Supporting
513	158	Main
1335	236	Cameo
2975	184	Main
913	160	Supporting
1717	549	Main
2400	510	Main
1343	582	Death
2601	398	Main
2363	249	Cameo
2449	289	Main
2240	383	Supporting
2484	251	Main
978	156	Supporting
179	102	Supporting
2762	15	Supporting
1497	76	Main
2425	24	Supporting
2005	77	Main
1160	515	Supporting
2320	328	Main
1024	395	Main
979	442	Supporting
1810	427	Supporting
1773	234	Main
2878	20	Main
2944	334	Supporting
1026	424	Main
566	69	Main
1983	150	Main
2505	340	Main
1612	334	Flashback
1730	289	Main
2089	579	Supporting
2812	223	Main
1808	5	Cameo
1152	407	Main
243	371	Supporting
547	421	Supporting
560	308	Main
801	23	Main
16	405	Main
107	577	Flashback
2539	82	Supporting
1846	15	Main
2305	235	Main
2089	110	Supporting
95	166	Cameo
358	126	Main
117	89	Main
2188	106	Main
795	536	Main
2463	600	Death
8	300	Supporting
2120	200	Main
972	189	Main
194	220	Main
2396	226	Main
2072	505	Main
562	325	Main
2230	483	Main
2702	186	Main
1024	449	Death
2784	509	Death
2426	504	Supporting
564	345	Main
411	472	Main
2473	122	Main
1093	341	Supporting
701	388	Main
1271	599	Main
1283	44	Main
865	476	Main
2634	278	Supporting
225	283	Supporting
1378	123	Cameo
2911	262	Main
43	81	Main
2521	548	Death
2640	172	Main
2798	18	Main
2530	315	Main
821	506	Main
520	386	Cameo
1567	436	Flashback
1532	522	Main
2171	206	Cameo
2938	5	Main
1098	508	Supporting
2892	112	Cameo
760	338	Cameo
2549	508	Main
1437	98	Main
2571	507	Main
1269	62	Main
628	546	Main
1025	98	Main
123	465	Main
370	598	Death
2143	369	Main
1105	488	Supporting
576	347	Main
2813	431	Main
2215	171	Cameo
1219	51	Cameo
610	569	Cameo
1852	136	Main
1188	39	Main
2044	48	Supporting
1825	35	Main
1192	587	Main
1668	24	Main
782	18	Cameo
1964	372	Supporting
2036	263	Cameo
586	11	Main
125	40	Cameo
2434	274	Supporting
1596	345	Supporting
8	501	Main
1414	270	Supporting
766	178	Main
1792	9	Main
2865	257	Main
1220	455	Main
2771	438	Supporting
2712	225	Main
425	338	Main
2878	593	Main
1624	81	Supporting
1850	37	Death
2146	368	Cameo
2226	116	Supporting
568	443	Main
2708	15	Death
2416	257	Main
752	380	Cameo
1982	143	Main
836	220	Main
808	310	Main
2840	293	Cameo
2405	282	Main
2075	585	Death
1012	447	Cameo
1722	304	Main
2755	40	Main
2810	485	Main
2375	585	Main
922	48	Main
1478	493	Supporting
1931	127	Main
2060	30	Cameo
2700	521	Main
1312	164	Main
547	274	Main
128	427	Supporting
785	380	Death
301	511	Main
511	124	Supporting
523	147	Main
1016	123	Main
949	385	Supporting
837	129	Cameo
2653	558	Flashback
156	22	Main
430	343	Supporting
1225	5	Supporting
2831	486	Main
1453	32	Main
1042	423	Main
1507	470	Cameo
826	403	Supporting
462	290	Main
718	188	Main
1427	435	Cameo
720	5	Supporting
2088	292	Supporting
1608	82	Cameo
2284	58	Main
2091	153	Cameo
2307	514	Supporting
1197	198	Main
514	107	Main
838	72	Supporting
2841	352	Cameo
2880	494	Main
987	35	Flashback
2545	491	Main
2807	19	Main
2898	415	Cameo
2206	101	Supporting
219	288	Death
513	143	Main
1701	570	Supporting
973	183	Main
1047	283	Main
2707	430	Cameo
2583	572	Supporting
1729	221	Main
1678	569	Cameo
26	283	Supporting
321	100	Main
1717	429	Supporting
1285	204	Supporting
352	549	Main
2831	111	Supporting
1179	403	Main
2142	570	Main
2207	551	Supporting
205	512	Main
1903	505	Main
2367	576	Death
2535	171	Death
728	185	Supporting
496	7	Main
1436	154	Main
2810	539	Main
501	469	Supporting
447	580	Main
668	340	Main
371	450	Main
381	528	Main
1638	314	Main
1864	510	Main
99	223	Main
1965	120	Cameo
2369	536	Main
834	464	Flashback
2169	271	Cameo
1531	486	Supporting
1666	478	Flashback
1778	220	Main
1157	124	Supporting
2763	103	Supporting
706	215	Main
2996	233	Supporting
2017	547	Main
169	51	Main
1753	449	Main
1539	415	Main
2182	335	Main
2156	64	Cameo
145	593	Supporting
2484	504	Cameo
1079	548	Supporting
2537	49	Flashback
1477	11	Cameo
2017	217	Main
1675	406	Main
1469	426	Main
1461	454	Main
836	489	Main
386	276	Main
2720	550	Supporting
1379	555	Cameo
383	439	Main
2454	398	Cameo
2706	41	Supporting
769	210	Main
2027	474	Main
1601	141	Supporting
2070	468	Main
1212	367	Main
2887	151	Cameo
2843	543	Main
1239	556	Main
2770	525	Death
572	335	Main
2555	597	Supporting
1535	525	Supporting
2469	489	Main
420	30	Supporting
1725	448	Main
1902	174	Supporting
2247	331	Supporting
375	547	Flashback
1505	336	Main
1149	355	Main
1419	173	Main
2150	375	Main
1201	421	Cameo
316	82	Main
2955	378	Main
2937	474	Supporting
2924	288	Main
1010	283	Main
598	314	Main
2831	169	Supporting
2206	218	Main
472	358	Main
2936	284	Main
1669	8	Main
1655	392	Main
2019	198	Supporting
2551	386	Cameo
1069	66	Main
1619	347	Main
17	496	Main
2435	272	Supporting
705	3	Main
533	377	Cameo
2677	390	Main
1982	32	Main
1688	579	Supporting
1952	29	Supporting
617	446	Main
1896	113	Death
1942	223	Supporting
881	211	Main
2011	99	Main
99	164	Supporting
1976	73	Supporting
362	222	Cameo
893	150	Main
164	95	Supporting
2571	196	Cameo
1006	510	Main
733	494	Cameo
659	49	Supporting
1639	50	Main
417	114	Death
2796	308	Cameo
318	414	Supporting
1111	467	Supporting
1674	534	Supporting
1049	559	Supporting
544	202	Supporting
1833	267	Cameo
2893	309	Supporting
1928	270	Main
587	14	Cameo
395	307	Main
1266	530	Flashback
2142	26	Cameo
350	483	Main
1006	527	Main
1617	435	Supporting
2000	116	Supporting
858	292	Main
2507	543	Main
1205	475	Main
1504	253	Flashback
2983	435	Main
2943	378	Main
23	349	Flashback
728	195	Main
2377	142	Main
1719	599	Main
933	26	Main
2942	187	Supporting
2150	351	Main
1047	88	Main
1346	38	Main
186	401	Main
1460	90	Main
1496	563	Supporting
745	116	Cameo
159	16	Supporting
2077	70	Main
716	600	Cameo
385	113	Cameo
2192	183	Flashback
1887	558	Supporting
252	377	Supporting
2054	144	Main
1146	376	Supporting
2144	394	Main
2547	562	Supporting
2187	598	Death
729	60	Supporting
2148	186	Main
1301	341	Death
60	193	Supporting
1768	243	Cameo
1983	243	Main
2433	553	Main
2563	355	Main
2943	181	Supporting
1430	208	Main
2631	529	Main
586	564	Main
1068	93	Cameo
2852	280	Cameo
68	458	Main
2648	41	Main
2566	355	Main
909	595	Main
169	485	Main
2565	510	Flashback
2637	285	Main
837	177	Main
2362	201	Main
2726	512	Cameo
666	196	Main
2477	251	Main
2858	41	Main
2299	555	Main
2313	306	Main
1669	207	Cameo
567	80	Death
866	443	Main
2916	121	Supporting
2481	178	Supporting
666	186	Main
1775	252	Supporting
1503	387	Supporting
390	428	Supporting
322	465	Cameo
1505	299	Cameo
993	222	Main
444	378	Supporting
284	234	Main
329	42	Death
1364	566	Supporting
2991	116	Main
1039	262	Cameo
1226	141	Main
2716	279	Main
1382	397	Main
1480	316	Cameo
1544	202	Supporting
1807	200	Cameo
1885	345	Main
2771	429	Main
2312	75	Cameo
706	302	Supporting
2922	591	Main
173	74	Main
563	314	Supporting
2513	506	Main
622	522	Supporting
2760	469	Main
2268	68	Main
1432	312	Supporting
2870	363	Main
1919	366	Main
1848	476	Supporting
806	173	Main
2160	396	Main
835	210	Supporting
608	389	Main
1770	540	Main
696	56	Main
1289	67	Cameo
1513	366	Cameo
2505	66	Main
1921	555	Cameo
598	451	Main
2831	348	Main
466	314	Main
1985	138	Main
2435	535	Death
2140	134	Main
1813	141	Main
542	524	Main
1201	264	Supporting
584	59	Death
495	179	Flashback
2992	245	Main
1386	220	Supporting
16	481	Flashback
922	151	Main
2240	281	Main
1056	285	Main
1390	104	Main
1835	289	Supporting
2208	459	Main
1384	262	Cameo
2166	13	Main
1918	185	Cameo
629	589	Supporting
1040	314	Supporting
216	586	Supporting
2126	166	Cameo
807	144	Cameo
1432	212	Death
687	531	Cameo
750	222	Main
200	87	Supporting
2918	111	Flashback
1537	176	Main
1175	360	Flashback
223	527	Main
2136	452	Main
363	66	Main
2270	310	Main
252	315	Main
687	500	Main
2538	202	Main
217	235	Supporting
671	378	Cameo
928	391	Supporting
327	356	Flashback
1895	242	Main
178	228	Supporting
2194	347	Main
527	427	Main
837	220	Main
1543	28	Main
1413	592	Supporting
2428	29	Cameo
1796	15	Main
416	469	Cameo
185	540	Main
1314	251	Main
425	445	Flashback
728	132	Death
1671	366	Main
646	107	Cameo
2351	541	Supporting
1280	278	Main
793	234	Main
2128	112	Main
406	386	Cameo
1646	53	Flashback
742	333	Cameo
1709	74	Cameo
2717	532	Main
2126	277	Supporting
2154	389	Main
1926	476	Main
124	596	Cameo
2788	600	Main
814	166	Main
1856	408	Flashback
1492	494	Main
1582	380	Main
617	568	Main
2705	86	Death
2512	71	Main
2683	155	Cameo
2542	95	Main
46	242	Cameo
1755	443	Main
1341	550	Main
2222	186	Death
941	226	Main
2439	462	Cameo
2621	210	Main
1420	534	Cameo
2953	195	Main
1936	292	Supporting
1379	525	Main
1392	554	Cameo
2869	234	Supporting
1497	488	Main
1271	236	Main
1917	159	Flashback
778	258	Cameo
1038	151	Supporting
2364	112	Main
2927	432	Supporting
2055	429	Main
463	99	Cameo
976	502	Main
1756	289	Supporting
1852	180	Main
2034	477	Supporting
818	576	Main
2099	84	Supporting
1627	374	Supporting
2380	20	Main
118	231	Death
57	103	Main
2308	139	Cameo
2590	297	Main
856	205	Main
2344	457	Main
2344	595	Main
2359	158	Cameo
1249	48	Death
932	163	Cameo
955	156	Supporting
2490	44	Main
2178	268	Cameo
233	327	Main
1578	210	Supporting
1500	128	Cameo
6	239	Supporting
1256	584	Main
175	69	Main
771	52	Main
1270	154	Main
2350	589	Main
388	567	Supporting
670	297	Main
1515	394	Main
2909	589	Main
2250	302	Main
2732	301	Cameo
1475	370	Main
2422	8	Main
799	409	Cameo
1146	326	Main
2611	350	Main
1007	308	Main
1966	380	Main
2605	252	Main
834	202	Main
2392	389	Main
985	177	Main
1736	121	Cameo
630	124	Flashback
1864	10	Main
874	486	Supporting
1434	27	Death
2288	289	Main
1893	135	Main
440	463	Main
\.


--
-- TOC entry 5109 (class 0 OID 32896)
-- Dependencies: 227
-- Data for Name: issue_creator; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.issue_creator (issue_id, creator_id, role) FROM stdin;
1	328	Writer
1	58	Penciler
2	13	Writer
2	380	Penciler
3	141	Writer
3	126	Penciler
4	115	Writer
4	72	Penciler
5	378	Writer
5	53	Penciler
6	347	Writer
6	380	Penciler
7	457	Writer
7	280	Penciler
8	45	Writer
8	303	Penciler
9	217	Writer
9	17	Penciler
10	16	Writer
10	48	Penciler
11	112	Writer
11	120	Penciler
12	259	Writer
12	309	Penciler
13	14	Writer
13	288	Penciler
14	102	Writer
14	367	Penciler
15	333	Writer
15	360	Penciler
16	280	Writer
16	215	Penciler
17	113	Writer
17	230	Penciler
18	302	Writer
18	143	Penciler
19	415	Writer
19	446	Penciler
20	4	Writer
20	389	Penciler
21	413	Writer
21	82	Penciler
22	358	Writer
22	217	Penciler
23	175	Writer
23	143	Penciler
24	80	Writer
24	111	Penciler
25	491	Writer
25	391	Penciler
26	173	Writer
26	53	Penciler
27	48	Writer
27	195	Penciler
28	50	Writer
28	184	Penciler
29	434	Writer
29	177	Penciler
30	310	Writer
30	136	Penciler
31	414	Writer
31	23	Penciler
32	374	Writer
32	236	Penciler
33	275	Writer
33	64	Penciler
34	499	Writer
34	473	Penciler
35	194	Writer
35	41	Penciler
36	283	Writer
36	151	Penciler
37	425	Writer
37	322	Penciler
38	317	Writer
38	454	Penciler
39	442	Writer
39	186	Penciler
40	296	Writer
40	99	Penciler
41	361	Writer
41	36	Penciler
42	24	Writer
42	339	Penciler
43	117	Writer
43	396	Penciler
44	149	Writer
44	41	Penciler
45	438	Writer
45	120	Penciler
46	444	Writer
46	52	Penciler
47	195	Writer
47	143	Penciler
48	233	Writer
48	326	Penciler
49	428	Writer
49	187	Penciler
50	84	Writer
50	190	Penciler
51	182	Writer
51	108	Penciler
52	344	Writer
52	137	Penciler
53	360	Writer
53	480	Penciler
54	350	Writer
54	332	Penciler
55	37	Writer
55	312	Penciler
56	326	Writer
56	88	Penciler
57	274	Writer
57	374	Penciler
58	126	Writer
58	84	Penciler
59	237	Writer
59	195	Penciler
60	139	Writer
60	474	Penciler
61	328	Writer
61	353	Penciler
62	286	Writer
62	113	Penciler
63	351	Writer
63	167	Penciler
64	432	Writer
64	394	Penciler
65	398	Writer
65	29	Penciler
66	118	Writer
66	421	Penciler
67	17	Writer
67	413	Penciler
68	162	Writer
68	206	Penciler
69	138	Writer
69	34	Penciler
70	109	Writer
70	468	Penciler
71	483	Writer
71	291	Penciler
72	449	Writer
72	368	Penciler
73	162	Writer
73	109	Penciler
74	336	Writer
74	256	Penciler
75	203	Writer
75	453	Penciler
76	469	Writer
76	330	Penciler
77	235	Writer
77	74	Penciler
78	136	Writer
78	72	Penciler
79	127	Writer
79	382	Penciler
80	288	Writer
80	276	Penciler
81	135	Writer
81	383	Penciler
82	300	Writer
82	220	Penciler
83	460	Writer
83	299	Penciler
84	205	Writer
84	186	Penciler
85	113	Writer
85	71	Penciler
86	261	Writer
86	253	Penciler
87	47	Writer
87	387	Penciler
88	25	Writer
88	441	Penciler
89	57	Writer
89	79	Penciler
90	322	Writer
90	82	Penciler
91	406	Writer
91	349	Penciler
92	217	Writer
92	306	Penciler
93	33	Writer
93	198	Penciler
94	196	Writer
94	306	Penciler
95	240	Writer
95	271	Penciler
96	129	Writer
96	498	Penciler
97	284	Writer
97	441	Penciler
98	483	Writer
98	6	Penciler
99	349	Writer
99	370	Penciler
100	59	Writer
100	350	Penciler
101	454	Writer
101	275	Penciler
102	385	Writer
102	137	Penciler
103	394	Writer
103	329	Penciler
104	175	Writer
104	58	Penciler
105	151	Writer
105	223	Penciler
106	81	Writer
106	233	Penciler
107	2	Writer
107	489	Penciler
108	370	Writer
108	449	Penciler
109	369	Writer
109	135	Penciler
110	498	Writer
110	257	Penciler
111	391	Writer
111	92	Penciler
112	260	Writer
112	468	Penciler
113	55	Writer
113	446	Penciler
114	321	Writer
114	153	Penciler
115	431	Writer
115	328	Penciler
116	260	Writer
116	312	Penciler
117	102	Writer
117	79	Penciler
118	192	Writer
118	391	Penciler
119	83	Writer
119	277	Penciler
120	489	Writer
120	399	Penciler
121	473	Writer
121	272	Penciler
122	471	Writer
122	1	Penciler
123	307	Writer
123	166	Penciler
124	251	Writer
124	10	Penciler
125	58	Writer
125	476	Penciler
126	186	Writer
126	450	Penciler
127	426	Writer
127	414	Penciler
128	158	Writer
128	123	Penciler
129	30	Writer
129	124	Penciler
130	450	Writer
130	291	Penciler
131	485	Writer
131	41	Penciler
132	44	Writer
132	375	Penciler
133	249	Writer
133	418	Penciler
134	36	Writer
134	390	Penciler
135	273	Writer
135	393	Penciler
136	65	Writer
136	66	Penciler
137	338	Writer
137	244	Penciler
138	485	Writer
138	282	Penciler
139	85	Writer
139	136	Penciler
140	271	Writer
140	447	Penciler
141	311	Writer
141	217	Penciler
142	494	Writer
142	109	Penciler
143	476	Writer
143	277	Penciler
144	387	Writer
144	374	Penciler
145	354	Writer
145	103	Penciler
146	366	Writer
146	160	Penciler
147	205	Writer
147	344	Penciler
148	333	Writer
148	192	Penciler
149	225	Writer
149	461	Penciler
150	265	Writer
150	232	Penciler
151	62	Writer
151	127	Penciler
152	116	Writer
152	33	Penciler
153	174	Writer
153	11	Penciler
154	302	Writer
154	284	Penciler
155	118	Writer
155	302	Penciler
156	113	Writer
156	4	Penciler
157	37	Writer
157	363	Penciler
158	324	Writer
158	31	Penciler
159	118	Writer
159	35	Penciler
160	464	Writer
160	17	Penciler
161	441	Writer
161	170	Penciler
162	37	Writer
162	264	Penciler
163	122	Writer
163	143	Penciler
164	343	Writer
164	249	Penciler
165	110	Writer
165	277	Penciler
166	68	Writer
166	371	Penciler
167	479	Writer
167	452	Penciler
168	293	Writer
168	296	Penciler
169	243	Writer
169	125	Penciler
170	402	Writer
170	243	Penciler
171	414	Writer
171	209	Penciler
172	98	Writer
172	49	Penciler
173	50	Writer
173	338	Penciler
174	221	Writer
174	182	Penciler
175	217	Writer
175	211	Penciler
176	240	Writer
176	443	Penciler
177	374	Writer
177	28	Penciler
178	345	Writer
178	335	Penciler
179	331	Writer
179	51	Penciler
180	32	Writer
180	207	Penciler
181	373	Writer
181	174	Penciler
182	410	Writer
182	442	Penciler
183	56	Writer
183	128	Penciler
184	99	Writer
184	98	Penciler
185	275	Writer
185	230	Penciler
186	72	Writer
186	217	Penciler
187	94	Writer
187	143	Penciler
188	237	Writer
188	128	Penciler
189	448	Writer
189	473	Penciler
190	39	Writer
190	227	Penciler
191	414	Writer
191	442	Penciler
192	439	Writer
192	282	Penciler
193	51	Writer
193	26	Penciler
194	334	Writer
194	277	Penciler
195	429	Writer
195	8	Penciler
196	497	Writer
196	48	Penciler
197	475	Writer
197	386	Penciler
198	435	Writer
198	122	Penciler
199	86	Writer
199	209	Penciler
200	249	Writer
200	247	Penciler
201	110	Writer
201	443	Penciler
202	206	Writer
202	463	Penciler
203	31	Writer
203	85	Penciler
204	195	Writer
204	2	Penciler
205	200	Writer
205	136	Penciler
206	475	Writer
206	402	Penciler
207	402	Writer
207	233	Penciler
208	147	Writer
208	217	Penciler
209	357	Writer
209	491	Penciler
210	375	Writer
210	402	Penciler
211	285	Writer
211	339	Penciler
212	368	Writer
212	250	Penciler
213	80	Writer
213	98	Penciler
214	152	Writer
214	112	Penciler
215	496	Writer
215	30	Penciler
216	297	Writer
216	377	Penciler
217	278	Writer
217	32	Penciler
218	383	Writer
218	161	Penciler
219	30	Writer
219	26	Penciler
220	300	Writer
220	245	Penciler
221	258	Writer
221	471	Penciler
222	437	Writer
222	272	Penciler
223	81	Writer
223	30	Penciler
224	492	Writer
224	261	Penciler
225	42	Writer
225	436	Penciler
226	96	Writer
226	36	Penciler
227	305	Writer
227	35	Penciler
228	346	Writer
228	442	Penciler
229	121	Writer
229	207	Penciler
230	62	Writer
230	483	Penciler
231	456	Writer
231	292	Penciler
232	127	Writer
232	297	Penciler
233	305	Writer
233	21	Penciler
234	318	Writer
234	42	Penciler
235	215	Writer
235	337	Penciler
236	299	Writer
236	290	Penciler
237	268	Writer
237	162	Penciler
238	479	Writer
238	134	Penciler
239	105	Writer
239	343	Penciler
240	367	Writer
240	161	Penciler
241	123	Writer
241	136	Penciler
242	203	Writer
242	68	Penciler
243	344	Writer
243	331	Penciler
244	154	Writer
244	235	Penciler
245	162	Writer
245	476	Penciler
246	385	Writer
246	480	Penciler
247	38	Writer
247	5	Penciler
248	235	Writer
248	319	Penciler
249	289	Writer
249	52	Penciler
250	38	Writer
250	276	Penciler
251	110	Writer
251	260	Penciler
252	136	Writer
252	68	Penciler
253	478	Writer
253	179	Penciler
254	452	Writer
254	36	Penciler
255	451	Writer
255	126	Penciler
256	190	Writer
256	146	Penciler
257	81	Writer
257	225	Penciler
258	427	Writer
258	279	Penciler
259	361	Writer
259	155	Penciler
260	314	Writer
260	414	Penciler
261	335	Writer
261	271	Penciler
262	5	Writer
262	342	Penciler
263	419	Writer
263	284	Penciler
264	154	Writer
264	478	Penciler
265	340	Writer
265	54	Penciler
266	481	Writer
266	450	Penciler
267	69	Writer
267	136	Penciler
268	60	Writer
268	456	Penciler
269	55	Writer
269	381	Penciler
270	284	Writer
270	80	Penciler
271	140	Writer
271	145	Penciler
272	310	Writer
272	108	Penciler
273	368	Writer
273	176	Penciler
274	105	Writer
274	352	Penciler
275	325	Writer
275	437	Penciler
276	136	Writer
276	259	Penciler
277	251	Writer
277	129	Penciler
278	464	Writer
278	465	Penciler
279	434	Writer
279	27	Penciler
280	48	Writer
280	325	Penciler
281	217	Writer
281	425	Penciler
282	142	Writer
282	23	Penciler
283	2	Writer
283	171	Penciler
284	395	Writer
284	67	Penciler
285	327	Writer
285	135	Penciler
286	83	Writer
286	380	Penciler
287	227	Writer
287	283	Penciler
288	362	Writer
288	219	Penciler
289	288	Writer
289	5	Penciler
290	58	Writer
290	39	Penciler
291	484	Writer
291	453	Penciler
292	354	Writer
292	463	Penciler
293	77	Writer
293	280	Penciler
294	19	Writer
294	428	Penciler
295	190	Writer
295	299	Penciler
296	283	Writer
296	76	Penciler
297	221	Writer
297	66	Penciler
298	22	Writer
298	158	Penciler
299	187	Writer
299	461	Penciler
300	478	Writer
300	408	Penciler
301	498	Writer
301	441	Penciler
302	21	Writer
302	461	Penciler
303	184	Writer
303	108	Penciler
304	350	Writer
304	128	Penciler
305	342	Writer
305	53	Penciler
306	182	Writer
306	400	Penciler
307	287	Writer
307	453	Penciler
308	448	Writer
308	209	Penciler
309	499	Writer
309	318	Penciler
310	384	Writer
310	80	Penciler
311	474	Writer
311	477	Penciler
312	122	Writer
312	443	Penciler
313	84	Writer
313	500	Penciler
314	410	Writer
314	416	Penciler
315	91	Writer
315	452	Penciler
316	212	Writer
316	13	Penciler
317	92	Writer
317	378	Penciler
318	474	Writer
318	171	Penciler
319	401	Writer
319	477	Penciler
320	211	Writer
320	411	Penciler
321	343	Writer
321	443	Penciler
322	377	Writer
322	416	Penciler
323	128	Writer
323	137	Penciler
324	82	Writer
324	404	Penciler
325	360	Writer
325	56	Penciler
326	196	Writer
326	447	Penciler
327	20	Writer
327	440	Penciler
328	241	Writer
328	114	Penciler
329	103	Writer
329	419	Penciler
330	471	Writer
330	236	Penciler
331	180	Writer
331	157	Penciler
332	421	Writer
332	408	Penciler
333	447	Writer
333	117	Penciler
334	115	Writer
334	13	Penciler
335	338	Writer
335	99	Penciler
336	205	Writer
336	169	Penciler
337	143	Writer
337	443	Penciler
338	36	Writer
338	496	Penciler
339	396	Writer
339	143	Penciler
340	180	Writer
340	329	Penciler
341	261	Writer
341	205	Penciler
342	348	Writer
342	432	Penciler
343	275	Writer
343	170	Penciler
344	481	Writer
344	15	Penciler
345	60	Writer
345	450	Penciler
346	497	Writer
346	134	Penciler
347	92	Writer
347	298	Penciler
348	493	Writer
348	136	Penciler
349	20	Writer
349	56	Penciler
350	306	Writer
350	223	Penciler
351	177	Writer
351	374	Penciler
352	403	Writer
352	161	Penciler
353	224	Writer
353	311	Penciler
354	262	Writer
354	60	Penciler
355	198	Writer
355	461	Penciler
356	296	Writer
356	98	Penciler
357	131	Writer
357	23	Penciler
358	363	Writer
358	224	Penciler
359	1	Writer
359	267	Penciler
360	474	Writer
360	413	Penciler
361	276	Writer
361	352	Penciler
362	369	Writer
362	482	Penciler
363	380	Writer
363	378	Penciler
364	344	Writer
364	101	Penciler
365	187	Writer
365	221	Penciler
366	36	Writer
366	486	Penciler
367	341	Writer
367	472	Penciler
368	170	Writer
368	320	Penciler
369	161	Writer
369	340	Penciler
370	435	Writer
370	64	Penciler
371	369	Writer
371	461	Penciler
372	154	Writer
372	260	Penciler
373	159	Writer
373	342	Penciler
374	210	Writer
374	168	Penciler
375	207	Writer
375	357	Penciler
376	152	Writer
376	284	Penciler
377	66	Writer
377	99	Penciler
378	216	Writer
378	341	Penciler
379	482	Writer
379	195	Penciler
380	347	Writer
380	384	Penciler
381	463	Writer
381	90	Penciler
382	316	Writer
382	292	Penciler
383	155	Writer
383	208	Penciler
384	281	Writer
384	427	Penciler
385	1	Writer
385	156	Penciler
386	147	Writer
386	108	Penciler
387	221	Writer
387	403	Penciler
388	297	Writer
388	311	Penciler
389	336	Writer
389	165	Penciler
390	239	Writer
390	227	Penciler
391	227	Writer
391	346	Penciler
392	110	Writer
392	262	Penciler
393	243	Writer
393	407	Penciler
394	462	Writer
394	492	Penciler
395	408	Writer
395	377	Penciler
396	87	Writer
396	338	Penciler
397	44	Writer
397	146	Penciler
398	264	Writer
398	340	Penciler
399	325	Writer
399	318	Penciler
400	172	Writer
400	48	Penciler
401	420	Writer
401	488	Penciler
402	385	Writer
402	121	Penciler
403	345	Writer
403	159	Penciler
404	116	Writer
404	413	Penciler
405	102	Writer
405	76	Penciler
406	13	Writer
406	24	Penciler
407	126	Writer
407	244	Penciler
408	313	Writer
408	436	Penciler
409	394	Writer
409	38	Penciler
410	234	Writer
410	213	Penciler
411	454	Writer
411	323	Penciler
412	295	Writer
412	100	Penciler
413	368	Writer
413	357	Penciler
414	197	Writer
414	254	Penciler
415	205	Writer
415	125	Penciler
416	76	Writer
416	336	Penciler
417	353	Writer
417	3	Penciler
418	458	Writer
418	385	Penciler
419	441	Writer
419	395	Penciler
420	454	Writer
420	55	Penciler
421	399	Writer
421	218	Penciler
422	113	Writer
422	91	Penciler
423	412	Writer
423	491	Penciler
424	357	Writer
424	266	Penciler
425	238	Writer
425	26	Penciler
426	286	Writer
426	128	Penciler
427	470	Writer
427	435	Penciler
428	63	Writer
428	234	Penciler
429	69	Writer
429	411	Penciler
430	238	Writer
430	342	Penciler
431	272	Writer
431	287	Penciler
432	305	Writer
432	163	Penciler
433	487	Writer
433	387	Penciler
434	457	Writer
434	227	Penciler
435	314	Writer
435	418	Penciler
436	369	Writer
436	457	Penciler
437	259	Writer
437	219	Penciler
438	426	Writer
438	465	Penciler
439	281	Writer
439	229	Penciler
440	460	Writer
440	82	Penciler
441	381	Writer
441	442	Penciler
442	244	Writer
442	231	Penciler
443	133	Writer
443	385	Penciler
444	127	Writer
444	431	Penciler
445	327	Writer
445	142	Penciler
446	393	Writer
446	399	Penciler
447	267	Writer
447	249	Penciler
448	321	Writer
448	123	Penciler
449	141	Writer
449	226	Penciler
450	40	Writer
450	366	Penciler
451	147	Writer
451	121	Penciler
452	140	Writer
452	172	Penciler
453	164	Writer
453	458	Penciler
454	277	Writer
454	42	Penciler
455	71	Writer
455	78	Penciler
456	119	Writer
456	197	Penciler
457	356	Writer
457	79	Penciler
458	362	Writer
458	110	Penciler
459	33	Writer
459	213	Penciler
460	209	Writer
460	170	Penciler
461	278	Writer
461	239	Penciler
462	213	Writer
462	32	Penciler
463	106	Writer
463	427	Penciler
464	216	Writer
464	200	Penciler
465	464	Writer
465	395	Penciler
466	300	Writer
466	485	Penciler
467	357	Writer
467	11	Penciler
468	439	Writer
468	451	Penciler
469	392	Writer
469	295	Penciler
470	195	Writer
470	245	Penciler
471	4	Writer
471	483	Penciler
472	181	Writer
472	153	Penciler
473	386	Writer
473	200	Penciler
474	437	Writer
474	457	Penciler
475	489	Writer
475	428	Penciler
476	215	Writer
476	276	Penciler
477	383	Writer
477	377	Penciler
478	280	Writer
478	410	Penciler
479	309	Writer
479	460	Penciler
480	113	Writer
480	250	Penciler
481	113	Writer
481	140	Penciler
482	224	Writer
482	249	Penciler
483	15	Writer
483	200	Penciler
484	173	Writer
484	343	Penciler
485	348	Writer
485	409	Penciler
486	208	Writer
486	371	Penciler
487	85	Writer
487	431	Penciler
488	240	Writer
488	471	Penciler
489	66	Writer
489	319	Penciler
490	274	Writer
490	14	Penciler
491	465	Writer
491	202	Penciler
492	304	Writer
492	289	Penciler
493	340	Writer
493	14	Penciler
494	43	Writer
494	330	Penciler
495	220	Writer
495	70	Penciler
496	444	Writer
496	237	Penciler
497	94	Writer
497	26	Penciler
498	134	Writer
498	195	Penciler
499	168	Writer
499	109	Penciler
500	233	Writer
500	168	Penciler
501	173	Writer
501	390	Penciler
502	451	Writer
502	195	Penciler
503	143	Writer
503	386	Penciler
504	488	Writer
504	426	Penciler
505	216	Writer
505	130	Penciler
506	428	Writer
506	42	Penciler
507	241	Writer
507	10	Penciler
508	384	Writer
508	277	Penciler
509	27	Writer
509	488	Penciler
510	180	Writer
510	115	Penciler
511	333	Writer
511	36	Penciler
512	400	Writer
512	491	Penciler
513	334	Writer
513	21	Penciler
514	387	Writer
514	16	Penciler
515	487	Writer
515	127	Penciler
516	103	Writer
516	430	Penciler
517	11	Writer
517	319	Penciler
518	79	Writer
518	123	Penciler
519	65	Writer
519	243	Penciler
520	343	Writer
520	59	Penciler
521	289	Writer
521	486	Penciler
522	112	Writer
522	239	Penciler
523	359	Writer
523	132	Penciler
524	393	Writer
524	189	Penciler
525	86	Writer
525	311	Penciler
526	311	Writer
526	494	Penciler
527	383	Writer
527	368	Penciler
528	59	Writer
528	399	Penciler
529	420	Writer
529	84	Penciler
530	494	Writer
530	160	Penciler
531	56	Writer
531	297	Penciler
532	14	Writer
532	476	Penciler
533	160	Writer
533	295	Penciler
534	347	Writer
534	465	Penciler
535	491	Writer
535	193	Penciler
536	204	Writer
536	483	Penciler
537	367	Writer
537	102	Penciler
538	39	Writer
538	304	Penciler
539	354	Writer
539	426	Penciler
540	322	Writer
540	125	Penciler
541	53	Writer
541	357	Penciler
542	396	Writer
542	155	Penciler
543	436	Writer
543	351	Penciler
544	308	Writer
544	413	Penciler
545	62	Writer
545	408	Penciler
546	290	Writer
546	401	Penciler
547	22	Writer
547	178	Penciler
548	273	Writer
548	220	Penciler
549	339	Writer
549	190	Penciler
550	36	Writer
550	260	Penciler
551	332	Writer
551	175	Penciler
552	7	Writer
552	435	Penciler
553	216	Writer
553	422	Penciler
554	251	Writer
554	55	Penciler
555	222	Writer
555	492	Penciler
556	186	Writer
556	326	Penciler
557	457	Writer
557	425	Penciler
558	236	Writer
558	363	Penciler
559	79	Writer
559	223	Penciler
560	91	Writer
560	376	Penciler
561	268	Writer
561	495	Penciler
562	334	Writer
562	139	Penciler
563	316	Writer
563	414	Penciler
564	471	Writer
564	276	Penciler
565	397	Writer
565	248	Penciler
566	239	Writer
566	224	Penciler
567	423	Writer
567	375	Penciler
568	304	Writer
568	138	Penciler
569	166	Writer
569	437	Penciler
570	126	Writer
570	426	Penciler
571	479	Writer
571	45	Penciler
572	143	Writer
572	452	Penciler
573	231	Writer
573	125	Penciler
574	385	Writer
574	238	Penciler
575	292	Writer
575	313	Penciler
576	343	Writer
576	195	Penciler
577	173	Writer
577	15	Penciler
578	254	Writer
578	436	Penciler
579	167	Writer
579	94	Penciler
580	250	Writer
580	109	Penciler
581	182	Writer
581	409	Penciler
582	133	Writer
582	175	Penciler
583	144	Writer
583	451	Penciler
584	306	Writer
584	360	Penciler
585	451	Writer
585	142	Penciler
586	285	Writer
586	6	Penciler
587	265	Writer
587	486	Penciler
588	98	Writer
588	44	Penciler
589	124	Writer
589	369	Penciler
590	209	Writer
590	251	Penciler
591	285	Writer
591	389	Penciler
592	124	Writer
592	354	Penciler
593	244	Writer
593	331	Penciler
594	365	Writer
594	252	Penciler
595	230	Writer
595	406	Penciler
596	9	Writer
596	48	Penciler
597	151	Writer
597	114	Penciler
598	208	Writer
598	355	Penciler
599	125	Writer
599	157	Penciler
600	340	Writer
600	298	Penciler
601	189	Writer
601	243	Penciler
602	284	Writer
602	272	Penciler
603	177	Writer
603	218	Penciler
604	382	Writer
604	282	Penciler
605	170	Writer
605	181	Penciler
606	360	Writer
606	233	Penciler
607	139	Writer
607	157	Penciler
608	129	Writer
608	119	Penciler
609	62	Writer
609	370	Penciler
610	99	Writer
610	162	Penciler
611	62	Writer
611	381	Penciler
612	275	Writer
612	487	Penciler
613	391	Writer
613	354	Penciler
614	95	Writer
614	99	Penciler
615	111	Writer
615	379	Penciler
616	248	Writer
616	142	Penciler
617	371	Writer
617	302	Penciler
618	390	Writer
618	269	Penciler
619	306	Writer
619	145	Penciler
620	52	Writer
620	427	Penciler
621	100	Writer
621	152	Penciler
622	117	Writer
622	185	Penciler
623	92	Writer
623	155	Penciler
624	8	Writer
624	363	Penciler
625	274	Writer
625	65	Penciler
626	141	Writer
626	24	Penciler
627	499	Writer
627	28	Penciler
628	284	Writer
628	150	Penciler
629	358	Writer
629	484	Penciler
630	65	Writer
630	327	Penciler
631	445	Writer
631	386	Penciler
632	252	Writer
632	53	Penciler
633	447	Writer
633	7	Penciler
634	294	Writer
634	146	Penciler
635	241	Writer
635	246	Penciler
636	226	Writer
636	175	Penciler
637	95	Writer
637	495	Penciler
638	27	Writer
638	130	Penciler
639	482	Writer
639	442	Penciler
640	245	Writer
640	59	Penciler
641	421	Writer
641	34	Penciler
642	206	Writer
642	252	Penciler
643	38	Writer
643	296	Penciler
644	323	Writer
644	352	Penciler
645	28	Writer
645	78	Penciler
646	77	Writer
646	416	Penciler
647	289	Writer
647	486	Penciler
648	156	Writer
648	44	Penciler
649	128	Writer
649	61	Penciler
650	286	Writer
650	392	Penciler
651	214	Writer
651	311	Penciler
652	306	Writer
652	405	Penciler
653	317	Writer
653	116	Penciler
654	398	Writer
654	268	Penciler
655	195	Writer
655	231	Penciler
656	466	Writer
656	227	Penciler
657	153	Writer
657	441	Penciler
658	302	Writer
658	220	Penciler
659	157	Writer
659	292	Penciler
660	318	Writer
660	31	Penciler
661	313	Writer
661	492	Penciler
662	379	Writer
662	51	Penciler
663	486	Writer
663	391	Penciler
664	107	Writer
664	321	Penciler
665	109	Writer
665	136	Penciler
666	339	Writer
666	42	Penciler
667	81	Writer
667	123	Penciler
668	89	Writer
668	283	Penciler
669	39	Writer
669	81	Penciler
670	2	Writer
670	210	Penciler
671	231	Writer
671	353	Penciler
672	305	Writer
672	241	Penciler
673	150	Writer
673	17	Penciler
674	119	Writer
674	148	Penciler
675	362	Writer
675	145	Penciler
676	360	Writer
676	441	Penciler
677	233	Writer
677	37	Penciler
678	352	Writer
678	120	Penciler
679	474	Writer
679	136	Penciler
680	404	Writer
680	406	Penciler
681	321	Writer
681	302	Penciler
682	339	Writer
682	412	Penciler
683	479	Writer
683	102	Penciler
684	218	Writer
684	59	Penciler
685	279	Writer
685	116	Penciler
686	332	Writer
686	77	Penciler
687	466	Writer
687	137	Penciler
688	424	Writer
688	73	Penciler
689	37	Writer
689	31	Penciler
690	85	Writer
690	406	Penciler
691	158	Writer
691	305	Penciler
692	384	Writer
692	423	Penciler
693	292	Writer
693	472	Penciler
694	148	Writer
694	225	Penciler
695	64	Writer
695	240	Penciler
696	353	Writer
696	156	Penciler
697	359	Writer
697	207	Penciler
698	483	Writer
698	140	Penciler
699	257	Writer
699	277	Penciler
700	253	Writer
700	225	Penciler
701	42	Writer
701	307	Penciler
702	21	Writer
702	456	Penciler
703	222	Writer
703	377	Penciler
704	166	Writer
704	310	Penciler
705	129	Writer
705	14	Penciler
706	47	Writer
706	118	Penciler
707	493	Writer
707	346	Penciler
708	429	Writer
708	441	Penciler
709	295	Writer
709	301	Penciler
710	487	Writer
710	11	Penciler
711	392	Writer
711	345	Penciler
712	421	Writer
712	138	Penciler
713	296	Writer
713	21	Penciler
714	391	Writer
714	388	Penciler
715	90	Writer
715	241	Penciler
716	266	Writer
716	334	Penciler
717	227	Writer
717	470	Penciler
718	143	Writer
718	93	Penciler
719	300	Writer
719	224	Penciler
720	326	Writer
720	417	Penciler
721	252	Writer
721	497	Penciler
722	47	Writer
722	241	Penciler
723	179	Writer
723	210	Penciler
724	171	Writer
724	165	Penciler
725	344	Writer
725	54	Penciler
726	440	Writer
726	83	Penciler
727	169	Writer
727	211	Penciler
728	356	Writer
728	254	Penciler
729	148	Writer
729	340	Penciler
730	484	Writer
730	206	Penciler
731	417	Writer
731	390	Penciler
732	282	Writer
732	19	Penciler
733	233	Writer
733	46	Penciler
734	162	Writer
734	130	Penciler
735	166	Writer
735	60	Penciler
736	497	Writer
736	396	Penciler
737	207	Writer
737	443	Penciler
738	264	Writer
738	423	Penciler
739	1	Writer
739	337	Penciler
740	446	Writer
740	278	Penciler
741	237	Writer
741	212	Penciler
742	28	Writer
742	97	Penciler
743	266	Writer
743	186	Penciler
744	319	Writer
744	388	Penciler
745	256	Writer
745	321	Penciler
746	227	Writer
746	390	Penciler
747	27	Writer
747	105	Penciler
748	137	Writer
748	282	Penciler
749	68	Writer
749	475	Penciler
750	148	Writer
750	225	Penciler
751	451	Writer
751	358	Penciler
752	249	Writer
752	63	Penciler
753	15	Writer
753	499	Penciler
754	323	Writer
754	312	Penciler
755	410	Writer
755	123	Penciler
756	364	Writer
756	82	Penciler
757	160	Writer
757	283	Penciler
758	8	Writer
758	283	Penciler
759	209	Writer
759	48	Penciler
760	116	Writer
760	431	Penciler
761	468	Writer
761	59	Penciler
762	237	Writer
762	485	Penciler
763	61	Writer
763	332	Penciler
764	427	Writer
764	79	Penciler
765	256	Writer
765	478	Penciler
766	367	Writer
766	150	Penciler
767	261	Writer
767	362	Penciler
768	140	Writer
768	213	Penciler
769	428	Writer
769	248	Penciler
770	242	Writer
770	125	Penciler
771	234	Writer
771	283	Penciler
772	75	Writer
772	197	Penciler
773	98	Writer
773	472	Penciler
774	307	Writer
774	261	Penciler
775	383	Writer
775	451	Penciler
776	70	Writer
776	443	Penciler
777	36	Writer
777	142	Penciler
778	396	Writer
778	405	Penciler
779	438	Writer
779	213	Penciler
780	175	Writer
780	479	Penciler
781	404	Writer
781	260	Penciler
782	137	Writer
782	421	Penciler
783	2	Writer
783	145	Penciler
784	372	Writer
784	153	Penciler
785	429	Writer
785	301	Penciler
786	297	Writer
786	338	Penciler
787	251	Writer
787	444	Penciler
788	77	Writer
788	229	Penciler
789	276	Writer
789	248	Penciler
790	177	Writer
790	171	Penciler
791	283	Writer
791	391	Penciler
792	279	Writer
792	194	Penciler
793	234	Writer
793	478	Penciler
794	165	Writer
794	446	Penciler
795	97	Writer
795	358	Penciler
796	123	Writer
796	293	Penciler
797	197	Writer
797	120	Penciler
798	439	Writer
798	398	Penciler
799	211	Writer
799	23	Penciler
800	163	Writer
800	382	Penciler
801	243	Writer
801	362	Penciler
802	468	Writer
802	416	Penciler
803	196	Writer
803	198	Penciler
804	340	Writer
804	406	Penciler
805	421	Writer
805	334	Penciler
806	78	Writer
806	254	Penciler
807	494	Writer
807	19	Penciler
808	65	Writer
808	258	Penciler
809	495	Writer
809	303	Penciler
810	170	Writer
810	446	Penciler
811	52	Writer
811	448	Penciler
812	433	Writer
812	226	Penciler
813	52	Writer
813	270	Penciler
814	467	Writer
814	234	Penciler
815	8	Writer
815	370	Penciler
816	74	Writer
816	210	Penciler
817	446	Writer
817	336	Penciler
818	497	Writer
818	80	Penciler
819	39	Writer
819	241	Penciler
820	401	Writer
820	497	Penciler
821	136	Writer
821	174	Penciler
822	320	Writer
822	355	Penciler
823	204	Writer
823	333	Penciler
824	42	Writer
824	437	Penciler
825	169	Writer
825	437	Penciler
826	346	Writer
826	440	Penciler
827	274	Writer
827	195	Penciler
828	489	Writer
828	163	Penciler
829	321	Writer
829	368	Penciler
830	455	Writer
830	389	Penciler
831	250	Writer
831	447	Penciler
832	278	Writer
832	19	Penciler
833	317	Writer
833	36	Penciler
834	121	Writer
834	324	Penciler
835	351	Writer
835	472	Penciler
836	148	Writer
836	117	Penciler
837	383	Writer
837	47	Penciler
838	223	Writer
838	51	Penciler
839	390	Writer
839	325	Penciler
840	361	Writer
840	447	Penciler
841	52	Writer
841	228	Penciler
842	86	Writer
842	356	Penciler
843	154	Writer
843	463	Penciler
844	15	Writer
844	24	Penciler
845	167	Writer
845	408	Penciler
846	29	Writer
846	151	Penciler
847	184	Writer
847	192	Penciler
848	221	Writer
848	75	Penciler
849	126	Writer
849	272	Penciler
850	211	Writer
850	290	Penciler
851	350	Writer
851	406	Penciler
852	93	Writer
852	88	Penciler
853	90	Writer
853	41	Penciler
854	313	Writer
854	446	Penciler
855	196	Writer
855	318	Penciler
856	350	Writer
856	124	Penciler
857	255	Writer
857	468	Penciler
858	299	Writer
858	74	Penciler
859	119	Writer
859	237	Penciler
860	327	Writer
860	131	Penciler
861	236	Writer
861	131	Penciler
862	342	Writer
862	5	Penciler
863	461	Writer
863	412	Penciler
864	239	Writer
864	462	Penciler
865	148	Writer
865	347	Penciler
866	280	Writer
866	81	Penciler
867	38	Writer
867	227	Penciler
868	484	Writer
868	177	Penciler
869	301	Writer
869	154	Penciler
870	328	Writer
870	493	Penciler
871	218	Writer
871	354	Penciler
872	129	Writer
872	234	Penciler
873	433	Writer
873	155	Penciler
874	102	Writer
874	197	Penciler
875	437	Writer
875	248	Penciler
876	55	Writer
876	122	Penciler
877	196	Writer
877	293	Penciler
878	184	Writer
878	295	Penciler
879	152	Writer
879	359	Penciler
880	152	Writer
880	12	Penciler
881	425	Writer
881	338	Penciler
882	203	Writer
882	141	Penciler
883	5	Writer
883	290	Penciler
884	443	Writer
884	352	Penciler
885	399	Writer
885	382	Penciler
886	499	Writer
886	26	Penciler
887	467	Writer
887	311	Penciler
888	382	Writer
888	255	Penciler
889	427	Writer
889	463	Penciler
890	463	Writer
890	147	Penciler
891	398	Writer
891	410	Penciler
892	118	Writer
892	311	Penciler
893	411	Writer
893	181	Penciler
894	113	Writer
894	326	Penciler
895	98	Writer
895	318	Penciler
896	129	Writer
896	348	Penciler
897	387	Writer
897	370	Penciler
898	393	Writer
898	338	Penciler
899	349	Writer
899	430	Penciler
900	71	Writer
900	322	Penciler
901	50	Writer
901	463	Penciler
902	322	Writer
902	331	Penciler
903	21	Writer
903	159	Penciler
904	404	Writer
904	226	Penciler
905	18	Writer
905	297	Penciler
906	187	Writer
906	375	Penciler
907	68	Writer
907	47	Penciler
908	466	Writer
908	152	Penciler
909	168	Writer
909	383	Penciler
910	213	Writer
910	90	Penciler
911	103	Writer
911	68	Penciler
912	403	Writer
912	277	Penciler
913	449	Writer
913	498	Penciler
914	188	Writer
914	272	Penciler
915	257	Writer
915	468	Penciler
916	140	Writer
916	426	Penciler
917	85	Writer
917	132	Penciler
918	468	Writer
918	423	Penciler
919	484	Writer
919	247	Penciler
920	496	Writer
920	413	Penciler
921	152	Writer
921	383	Penciler
922	446	Writer
922	174	Penciler
923	412	Writer
923	59	Penciler
924	240	Writer
924	494	Penciler
925	39	Writer
925	73	Penciler
926	387	Writer
926	495	Penciler
927	116	Writer
927	441	Penciler
928	347	Writer
928	371	Penciler
929	346	Writer
929	204	Penciler
930	496	Writer
930	434	Penciler
931	412	Writer
931	286	Penciler
932	188	Writer
932	47	Penciler
933	405	Writer
933	203	Penciler
934	8	Writer
934	136	Penciler
935	275	Writer
935	64	Penciler
936	233	Writer
936	189	Penciler
937	345	Writer
937	384	Penciler
938	345	Writer
938	135	Penciler
939	300	Writer
939	196	Penciler
940	422	Writer
940	327	Penciler
941	482	Writer
941	191	Penciler
942	56	Writer
942	346	Penciler
943	120	Writer
943	242	Penciler
944	13	Writer
944	318	Penciler
945	453	Writer
945	483	Penciler
946	288	Writer
946	168	Penciler
947	469	Writer
947	313	Penciler
948	114	Writer
948	332	Penciler
949	33	Writer
949	326	Penciler
950	422	Writer
950	238	Penciler
951	466	Writer
951	359	Penciler
952	155	Writer
952	333	Penciler
953	210	Writer
953	60	Penciler
954	72	Writer
954	24	Penciler
955	485	Writer
955	20	Penciler
956	156	Writer
956	253	Penciler
957	60	Writer
957	50	Penciler
958	121	Writer
958	455	Penciler
959	276	Writer
959	70	Penciler
960	199	Writer
960	233	Penciler
961	190	Writer
961	344	Penciler
962	487	Writer
962	381	Penciler
963	357	Writer
963	485	Penciler
964	277	Writer
964	215	Penciler
965	301	Writer
965	381	Penciler
966	373	Writer
966	80	Penciler
967	454	Writer
967	213	Penciler
968	336	Writer
968	51	Penciler
969	427	Writer
969	251	Penciler
970	316	Writer
970	209	Penciler
971	481	Writer
971	488	Penciler
972	144	Writer
972	17	Penciler
973	354	Writer
973	190	Penciler
974	112	Writer
974	228	Penciler
975	228	Writer
975	487	Penciler
976	121	Writer
976	438	Penciler
977	186	Writer
977	51	Penciler
978	352	Writer
978	189	Penciler
979	279	Writer
979	462	Penciler
980	331	Writer
980	184	Penciler
981	32	Writer
981	204	Penciler
982	142	Writer
982	98	Penciler
983	496	Writer
983	63	Penciler
984	486	Writer
984	435	Penciler
985	422	Writer
985	233	Penciler
986	47	Writer
986	340	Penciler
987	109	Writer
987	329	Penciler
988	328	Writer
988	306	Penciler
989	498	Writer
989	11	Penciler
990	26	Writer
990	403	Penciler
991	171	Writer
991	125	Penciler
992	65	Writer
992	403	Penciler
993	290	Writer
993	106	Penciler
994	36	Writer
994	425	Penciler
995	392	Writer
995	284	Penciler
996	107	Writer
996	301	Penciler
997	111	Writer
997	417	Penciler
998	446	Writer
998	120	Penciler
999	169	Writer
999	397	Penciler
1000	76	Writer
1000	404	Penciler
1001	462	Writer
1001	306	Penciler
1002	2	Writer
1002	142	Penciler
1003	440	Writer
1003	75	Penciler
1004	67	Writer
1004	277	Penciler
1005	129	Writer
1005	409	Penciler
1006	90	Writer
1006	57	Penciler
1007	339	Writer
1007	444	Penciler
1008	14	Writer
1008	68	Penciler
1009	8	Writer
1009	184	Penciler
1010	405	Writer
1010	404	Penciler
1011	122	Writer
1011	302	Penciler
1012	166	Writer
1012	9	Penciler
1013	90	Writer
1013	136	Penciler
1014	27	Writer
1014	65	Penciler
1015	380	Writer
1015	216	Penciler
1016	270	Writer
1016	59	Penciler
1017	382	Writer
1017	33	Penciler
1018	244	Writer
1018	230	Penciler
1019	399	Writer
1019	186	Penciler
1020	263	Writer
1020	304	Penciler
1021	56	Writer
1021	232	Penciler
1022	258	Writer
1022	114	Penciler
1023	485	Writer
1023	315	Penciler
1024	23	Writer
1024	373	Penciler
1025	402	Writer
1025	466	Penciler
1026	444	Writer
1026	338	Penciler
1027	267	Writer
1027	155	Penciler
1028	235	Writer
1028	330	Penciler
1029	494	Writer
1029	16	Penciler
1030	32	Writer
1030	246	Penciler
1031	434	Writer
1031	206	Penciler
1032	219	Writer
1032	352	Penciler
1033	56	Writer
1033	252	Penciler
1034	365	Writer
1034	466	Penciler
1035	228	Writer
1035	38	Penciler
1036	461	Writer
1036	42	Penciler
1037	165	Writer
1037	312	Penciler
1038	76	Writer
1038	34	Penciler
1039	65	Writer
1039	141	Penciler
1040	320	Writer
1040	325	Penciler
1041	300	Writer
1041	281	Penciler
1042	365	Writer
1042	167	Penciler
1043	196	Writer
1043	306	Penciler
1044	272	Writer
1044	151	Penciler
1045	233	Writer
1045	259	Penciler
1046	310	Writer
1046	221	Penciler
1047	51	Writer
1047	407	Penciler
1048	360	Writer
1048	59	Penciler
1049	437	Writer
1049	336	Penciler
1050	334	Writer
1050	450	Penciler
1051	394	Writer
1051	283	Penciler
1052	370	Writer
1052	444	Penciler
1053	111	Writer
1053	221	Penciler
1054	232	Writer
1054	455	Penciler
1055	117	Writer
1055	212	Penciler
1056	174	Writer
1056	424	Penciler
1057	233	Writer
1057	205	Penciler
1058	213	Writer
1058	374	Penciler
1059	49	Writer
1059	161	Penciler
1060	219	Writer
1060	161	Penciler
1061	341	Writer
1061	131	Penciler
1062	192	Writer
1062	489	Penciler
1063	79	Writer
1063	352	Penciler
1064	473	Writer
1064	243	Penciler
1065	35	Writer
1065	47	Penciler
1066	426	Writer
1066	44	Penciler
1067	48	Writer
1067	222	Penciler
1068	50	Writer
1068	382	Penciler
1069	379	Writer
1069	191	Penciler
1070	416	Writer
1070	67	Penciler
1071	285	Writer
1071	31	Penciler
1072	301	Writer
1072	490	Penciler
1073	288	Writer
1073	288	Penciler
1074	169	Writer
1074	344	Penciler
1075	63	Writer
1075	211	Penciler
1076	182	Writer
1076	448	Penciler
1077	341	Writer
1077	482	Penciler
1078	385	Writer
1078	217	Penciler
1079	445	Writer
1079	469	Penciler
1080	370	Writer
1080	27	Penciler
1081	496	Writer
1081	148	Penciler
1082	308	Writer
1082	160	Penciler
1083	181	Writer
1083	54	Penciler
1084	296	Writer
1084	260	Penciler
1085	109	Writer
1085	80	Penciler
1086	337	Writer
1086	247	Penciler
1087	115	Writer
1087	434	Penciler
1088	56	Writer
1088	180	Penciler
1089	433	Writer
1089	285	Penciler
1090	189	Writer
1090	59	Penciler
1091	391	Writer
1091	143	Penciler
1092	294	Writer
1092	116	Penciler
1093	414	Writer
1093	220	Penciler
1094	433	Writer
1094	288	Penciler
1095	499	Writer
1095	393	Penciler
1096	420	Writer
1096	319	Penciler
1097	315	Writer
1097	346	Penciler
1098	330	Writer
1098	286	Penciler
1099	14	Writer
1099	312	Penciler
1100	476	Writer
1100	337	Penciler
1101	425	Writer
1101	356	Penciler
1102	137	Writer
1102	15	Penciler
1103	93	Writer
1103	140	Penciler
1104	360	Writer
1104	391	Penciler
1105	159	Writer
1105	472	Penciler
1106	174	Writer
1106	180	Penciler
1107	4	Writer
1107	93	Penciler
1108	446	Writer
1108	74	Penciler
1109	290	Writer
1109	337	Penciler
1110	206	Writer
1110	36	Penciler
1111	73	Writer
1111	380	Penciler
1112	325	Writer
1112	498	Penciler
1113	16	Writer
1113	47	Penciler
1114	383	Writer
1114	272	Penciler
1115	111	Writer
1115	193	Penciler
1116	215	Writer
1116	233	Penciler
1117	175	Writer
1117	81	Penciler
1118	190	Writer
1118	160	Penciler
1119	370	Writer
1119	167	Penciler
1120	398	Writer
1120	483	Penciler
1121	291	Writer
1121	306	Penciler
1122	44	Writer
1122	453	Penciler
1123	27	Writer
1123	80	Penciler
1124	81	Writer
1124	387	Penciler
1125	317	Writer
1125	26	Penciler
1126	346	Writer
1126	42	Penciler
1127	140	Writer
1127	227	Penciler
1128	339	Writer
1128	218	Penciler
1129	249	Writer
1129	311	Penciler
1130	227	Writer
1130	213	Penciler
1131	140	Writer
1131	111	Penciler
1132	387	Writer
1132	263	Penciler
1133	59	Writer
1133	177	Penciler
1134	221	Writer
1134	57	Penciler
1135	146	Writer
1135	348	Penciler
1136	348	Writer
1136	304	Penciler
1137	250	Writer
1137	270	Penciler
1138	342	Writer
1138	158	Penciler
1139	24	Writer
1139	113	Penciler
1140	203	Writer
1140	307	Penciler
1141	29	Writer
1141	4	Penciler
1142	105	Writer
1142	155	Penciler
1143	485	Writer
1143	109	Penciler
1144	393	Writer
1144	71	Penciler
1145	392	Writer
1145	131	Penciler
1146	149	Writer
1146	168	Penciler
1147	62	Writer
1147	4	Penciler
1148	255	Writer
1148	383	Penciler
1149	221	Writer
1149	90	Penciler
1150	67	Writer
1150	195	Penciler
1151	273	Writer
1151	361	Penciler
1152	118	Writer
1152	257	Penciler
1153	287	Writer
1153	427	Penciler
1154	343	Writer
1154	413	Penciler
1155	182	Writer
1155	37	Penciler
1156	204	Writer
1156	442	Penciler
1157	380	Writer
1157	22	Penciler
1158	224	Writer
1158	10	Penciler
1159	236	Writer
1159	472	Penciler
1160	40	Writer
1160	442	Penciler
1161	161	Writer
1161	295	Penciler
1162	220	Writer
1162	294	Penciler
1163	208	Writer
1163	364	Penciler
1164	328	Writer
1164	214	Penciler
1165	149	Writer
1165	59	Penciler
1166	208	Writer
1166	11	Penciler
1167	495	Writer
1167	167	Penciler
1168	88	Writer
1168	411	Penciler
1169	486	Writer
1169	317	Penciler
1170	236	Writer
1170	426	Penciler
1171	354	Writer
1171	471	Penciler
1172	186	Writer
1172	46	Penciler
1173	224	Writer
1173	433	Penciler
1174	55	Writer
1174	125	Penciler
1175	224	Writer
1175	302	Penciler
1176	206	Writer
1176	269	Penciler
1177	41	Writer
1177	203	Penciler
1178	446	Writer
1178	159	Penciler
1179	382	Writer
1179	174	Penciler
1180	114	Writer
1180	171	Penciler
1181	399	Writer
1181	87	Penciler
1182	40	Writer
1182	262	Penciler
1183	325	Writer
1183	59	Penciler
1184	272	Writer
1184	262	Penciler
1185	100	Writer
1185	464	Penciler
1186	398	Writer
1186	179	Penciler
1187	180	Writer
1187	373	Penciler
1188	491	Writer
1188	420	Penciler
1189	331	Writer
1189	418	Penciler
1190	76	Writer
1190	121	Penciler
1191	53	Writer
1191	75	Penciler
1192	132	Writer
1192	102	Penciler
1193	89	Writer
1193	309	Penciler
1194	79	Writer
1194	390	Penciler
1195	389	Writer
1195	336	Penciler
1196	39	Writer
1196	91	Penciler
1197	488	Writer
1197	396	Penciler
1198	322	Writer
1198	253	Penciler
1199	238	Writer
1199	387	Penciler
1200	289	Writer
1200	390	Penciler
1201	297	Writer
1201	230	Penciler
1202	349	Writer
1202	474	Penciler
1203	452	Writer
1203	290	Penciler
1204	330	Writer
1204	326	Penciler
1205	320	Writer
1205	166	Penciler
1206	443	Writer
1206	498	Penciler
1207	322	Writer
1207	162	Penciler
1208	78	Writer
1208	226	Penciler
1209	35	Writer
1209	241	Penciler
1210	227	Writer
1210	324	Penciler
1211	156	Writer
1211	408	Penciler
1212	141	Writer
1212	303	Penciler
1213	29	Writer
1213	181	Penciler
1214	260	Writer
1214	38	Penciler
1215	159	Writer
1215	237	Penciler
1216	232	Writer
1216	20	Penciler
1217	30	Writer
1217	189	Penciler
1218	426	Writer
1218	147	Penciler
1219	40	Writer
1219	331	Penciler
1220	443	Writer
1220	438	Penciler
1221	47	Writer
1221	315	Penciler
1222	305	Writer
1222	260	Penciler
1223	197	Writer
1223	237	Penciler
1224	298	Writer
1224	284	Penciler
1225	489	Writer
1225	406	Penciler
1226	379	Writer
1226	459	Penciler
1227	22	Writer
1227	231	Penciler
1228	466	Writer
1228	415	Penciler
1229	293	Writer
1229	334	Penciler
1230	97	Writer
1230	165	Penciler
1231	310	Writer
1231	244	Penciler
1232	257	Writer
1232	78	Penciler
1233	491	Writer
1233	32	Penciler
1234	231	Writer
1234	53	Penciler
1235	416	Writer
1235	461	Penciler
1236	429	Writer
1236	176	Penciler
1237	366	Writer
1237	44	Penciler
1238	259	Writer
1238	331	Penciler
1239	89	Writer
1239	21	Penciler
1240	127	Writer
1240	363	Penciler
1241	225	Writer
1241	225	Penciler
1242	269	Writer
1242	268	Penciler
1243	313	Writer
1243	82	Penciler
1244	187	Writer
1244	191	Penciler
1245	470	Writer
1245	145	Penciler
1246	199	Writer
1246	210	Penciler
1247	397	Writer
1247	174	Penciler
1248	348	Writer
1248	307	Penciler
1249	27	Writer
1249	405	Penciler
1250	324	Writer
1250	332	Penciler
1251	172	Writer
1251	34	Penciler
1252	169	Writer
1252	49	Penciler
1253	286	Writer
1253	348	Penciler
1254	198	Writer
1254	146	Penciler
1255	130	Writer
1255	371	Penciler
1256	437	Writer
1256	337	Penciler
1257	494	Writer
1257	465	Penciler
1258	309	Writer
1258	448	Penciler
1259	77	Writer
1259	171	Penciler
1260	42	Writer
1260	299	Penciler
1261	340	Writer
1261	73	Penciler
1262	470	Writer
1262	180	Penciler
1263	159	Writer
1263	496	Penciler
1264	336	Writer
1264	358	Penciler
1265	340	Writer
1265	201	Penciler
1266	67	Writer
1266	305	Penciler
1267	363	Writer
1267	481	Penciler
1268	44	Writer
1268	159	Penciler
1269	287	Writer
1269	193	Penciler
1270	330	Writer
1270	406	Penciler
1271	169	Writer
1271	417	Penciler
1272	66	Writer
1272	344	Penciler
1273	360	Writer
1273	425	Penciler
1274	485	Writer
1274	379	Penciler
1275	351	Writer
1275	468	Penciler
1276	270	Writer
1276	48	Penciler
1277	331	Writer
1277	344	Penciler
1278	217	Writer
1278	261	Penciler
1279	186	Writer
1279	10	Penciler
1280	186	Writer
1280	159	Penciler
1281	93	Writer
1281	487	Penciler
1282	110	Writer
1282	175	Penciler
1283	486	Writer
1283	393	Penciler
1284	249	Writer
1284	99	Penciler
1285	116	Writer
1285	71	Penciler
1286	80	Writer
1286	40	Penciler
1287	152	Writer
1287	433	Penciler
1288	404	Writer
1288	52	Penciler
1289	260	Writer
1289	395	Penciler
1290	277	Writer
1290	428	Penciler
1291	379	Writer
1291	453	Penciler
1292	270	Writer
1292	20	Penciler
1293	339	Writer
1293	173	Penciler
1294	449	Writer
1294	393	Penciler
1295	317	Writer
1295	68	Penciler
1296	306	Writer
1296	193	Penciler
1297	79	Writer
1297	84	Penciler
1298	93	Writer
1298	426	Penciler
1299	355	Writer
1299	395	Penciler
1300	320	Writer
1300	415	Penciler
1301	463	Writer
1301	85	Penciler
1302	370	Writer
1302	225	Penciler
1303	23	Writer
1303	211	Penciler
1304	187	Writer
1304	347	Penciler
1305	369	Writer
1305	122	Penciler
1306	497	Writer
1306	228	Penciler
1307	313	Writer
1307	146	Penciler
1308	386	Writer
1308	384	Penciler
1309	402	Writer
1309	230	Penciler
1310	120	Writer
1310	274	Penciler
1311	123	Writer
1311	159	Penciler
1312	495	Writer
1312	415	Penciler
1313	402	Writer
1313	241	Penciler
1314	463	Writer
1314	428	Penciler
1315	100	Writer
1315	189	Penciler
1316	348	Writer
1316	485	Penciler
1317	293	Writer
1317	226	Penciler
1318	237	Writer
1318	394	Penciler
1319	145	Writer
1319	399	Penciler
1320	196	Writer
1320	258	Penciler
1321	271	Writer
1321	215	Penciler
1322	495	Writer
1322	83	Penciler
1323	419	Writer
1323	103	Penciler
1324	411	Writer
1324	310	Penciler
1325	71	Writer
1325	447	Penciler
1326	129	Writer
1326	27	Penciler
1327	329	Writer
1327	247	Penciler
1328	448	Writer
1328	191	Penciler
1329	284	Writer
1329	479	Penciler
1330	53	Writer
1330	365	Penciler
1331	434	Writer
1331	265	Penciler
1332	436	Writer
1332	64	Penciler
1333	146	Writer
1333	43	Penciler
1334	391	Writer
1334	83	Penciler
1335	140	Writer
1335	231	Penciler
1336	464	Writer
1336	263	Penciler
1337	76	Writer
1337	426	Penciler
1338	224	Writer
1338	47	Penciler
1339	485	Writer
1339	467	Penciler
1340	114	Writer
1340	419	Penciler
1341	231	Writer
1341	453	Penciler
1342	179	Writer
1342	477	Penciler
1343	14	Writer
1343	213	Penciler
1344	28	Writer
1344	203	Penciler
1345	258	Writer
1345	192	Penciler
1346	121	Writer
1346	198	Penciler
1347	42	Writer
1347	192	Penciler
1348	115	Writer
1348	15	Penciler
1349	164	Writer
1349	477	Penciler
1350	51	Writer
1350	430	Penciler
1351	366	Writer
1351	333	Penciler
1352	172	Writer
1352	406	Penciler
1353	75	Writer
1353	71	Penciler
1354	20	Writer
1354	147	Penciler
1355	470	Writer
1355	425	Penciler
1356	242	Writer
1356	357	Penciler
1357	426	Writer
1357	72	Penciler
1358	389	Writer
1358	362	Penciler
1359	241	Writer
1359	230	Penciler
1360	316	Writer
1360	3	Penciler
1361	464	Writer
1361	41	Penciler
1362	10	Writer
1362	132	Penciler
1363	111	Writer
1363	428	Penciler
1364	77	Writer
1364	281	Penciler
1365	482	Writer
1365	373	Penciler
1366	312	Writer
1366	271	Penciler
1367	217	Writer
1367	57	Penciler
1368	398	Writer
1368	148	Penciler
1369	122	Writer
1369	155	Penciler
1370	63	Writer
1370	25	Penciler
1371	123	Writer
1371	215	Penciler
1372	328	Writer
1372	407	Penciler
1373	319	Writer
1373	235	Penciler
1374	33	Writer
1374	57	Penciler
1375	429	Writer
1375	464	Penciler
1376	256	Writer
1376	306	Penciler
1377	275	Writer
1377	9	Penciler
1378	324	Writer
1378	264	Penciler
1379	295	Writer
1379	124	Penciler
1380	368	Writer
1380	74	Penciler
1381	150	Writer
1381	220	Penciler
1382	1	Writer
1382	315	Penciler
1383	181	Writer
1383	124	Penciler
1384	293	Writer
1384	214	Penciler
1385	96	Writer
1385	341	Penciler
1386	343	Writer
1386	44	Penciler
1387	269	Writer
1387	500	Penciler
1388	185	Writer
1388	35	Penciler
1389	489	Writer
1389	270	Penciler
1390	279	Writer
1390	260	Penciler
1391	403	Writer
1391	260	Penciler
1392	284	Writer
1392	11	Penciler
1393	200	Writer
1393	448	Penciler
1394	241	Writer
1394	23	Penciler
1395	326	Writer
1395	199	Penciler
1396	192	Writer
1396	130	Penciler
1397	383	Writer
1397	9	Penciler
1398	183	Writer
1398	404	Penciler
1399	35	Writer
1399	177	Penciler
1400	124	Writer
1400	376	Penciler
1401	337	Writer
1401	322	Penciler
1402	54	Writer
1402	396	Penciler
1403	298	Writer
1403	377	Penciler
1404	388	Writer
1404	171	Penciler
1405	69	Writer
1405	23	Penciler
1406	181	Writer
1406	280	Penciler
1407	174	Writer
1407	417	Penciler
1408	330	Writer
1408	90	Penciler
1409	426	Writer
1409	399	Penciler
1410	351	Writer
1410	238	Penciler
1411	357	Writer
1411	246	Penciler
1412	324	Writer
1412	94	Penciler
1413	416	Writer
1413	70	Penciler
1414	33	Writer
1414	367	Penciler
1415	398	Writer
1415	484	Penciler
1416	235	Writer
1416	19	Penciler
1417	151	Writer
1417	104	Penciler
1418	23	Writer
1418	406	Penciler
1419	103	Writer
1419	454	Penciler
1420	22	Writer
1420	162	Penciler
1421	478	Writer
1421	159	Penciler
1422	264	Writer
1422	204	Penciler
1423	418	Writer
1423	279	Penciler
1424	243	Writer
1424	130	Penciler
1425	19	Writer
1425	386	Penciler
1426	332	Writer
1426	98	Penciler
1427	147	Writer
1427	183	Penciler
1428	442	Writer
1428	400	Penciler
1429	25	Writer
1429	444	Penciler
1430	336	Writer
1430	170	Penciler
1431	140	Writer
1431	64	Penciler
1432	410	Writer
1432	189	Penciler
1433	224	Writer
1433	456	Penciler
1434	205	Writer
1434	381	Penciler
1435	226	Writer
1435	459	Penciler
1436	490	Writer
1436	198	Penciler
1437	174	Writer
1437	499	Penciler
1438	96	Writer
1438	255	Penciler
1439	355	Writer
1439	255	Penciler
1440	189	Writer
1440	474	Penciler
1441	409	Writer
1441	266	Penciler
1442	137	Writer
1442	411	Penciler
1443	43	Writer
1443	373	Penciler
1444	218	Writer
1444	41	Penciler
1445	221	Writer
1445	309	Penciler
1446	422	Writer
1446	93	Penciler
1447	280	Writer
1447	151	Penciler
1448	165	Writer
1448	53	Penciler
1449	41	Writer
1449	168	Penciler
1450	339	Writer
1450	152	Penciler
1451	157	Writer
1451	229	Penciler
1452	309	Writer
1452	368	Penciler
1453	219	Writer
1453	86	Penciler
1454	354	Writer
1454	228	Penciler
1455	180	Writer
1455	229	Penciler
1456	22	Writer
1456	373	Penciler
1457	446	Writer
1457	467	Penciler
1458	181	Writer
1458	315	Penciler
1459	223	Writer
1459	141	Penciler
1460	328	Writer
1460	406	Penciler
1461	486	Writer
1461	30	Penciler
1462	39	Writer
1462	344	Penciler
1463	327	Writer
1463	208	Penciler
1464	187	Writer
1464	263	Penciler
1465	411	Writer
1465	384	Penciler
1466	348	Writer
1466	82	Penciler
1467	488	Writer
1467	16	Penciler
1468	74	Writer
1468	435	Penciler
1469	312	Writer
1469	348	Penciler
1470	401	Writer
1470	225	Penciler
1471	18	Writer
1471	65	Penciler
1472	35	Writer
1472	121	Penciler
1473	399	Writer
1473	331	Penciler
1474	188	Writer
1474	186	Penciler
1475	197	Writer
1475	487	Penciler
1476	291	Writer
1476	17	Penciler
1477	310	Writer
1477	79	Penciler
1478	348	Writer
1478	231	Penciler
1479	486	Writer
1479	190	Penciler
1480	191	Writer
1480	228	Penciler
1481	391	Writer
1481	40	Penciler
1482	294	Writer
1482	71	Penciler
1483	272	Writer
1483	188	Penciler
1484	204	Writer
1484	161	Penciler
1485	333	Writer
1485	143	Penciler
1486	128	Writer
1486	492	Penciler
1487	59	Writer
1487	14	Penciler
1488	377	Writer
1488	96	Penciler
1489	256	Writer
1489	266	Penciler
1490	199	Writer
1490	468	Penciler
1491	288	Writer
1491	61	Penciler
1492	135	Writer
1492	397	Penciler
1493	134	Writer
1493	361	Penciler
1494	229	Writer
1494	110	Penciler
1495	314	Writer
1495	147	Penciler
1496	356	Writer
1496	470	Penciler
1497	252	Writer
1497	103	Penciler
1498	63	Writer
1498	70	Penciler
1499	437	Writer
1499	38	Penciler
1500	232	Writer
1500	89	Penciler
1501	461	Writer
1501	366	Penciler
1502	228	Writer
1502	45	Penciler
1503	415	Writer
1503	350	Penciler
1504	496	Writer
1504	433	Penciler
1505	164	Writer
1505	342	Penciler
1506	178	Writer
1506	364	Penciler
1507	34	Writer
1507	282	Penciler
1508	278	Writer
1508	149	Penciler
1509	457	Writer
1509	154	Penciler
1510	436	Writer
1510	81	Penciler
1511	365	Writer
1511	364	Penciler
1512	475	Writer
1512	359	Penciler
1513	327	Writer
1513	90	Penciler
1514	407	Writer
1514	186	Penciler
1515	261	Writer
1515	115	Penciler
1516	63	Writer
1516	103	Penciler
1517	406	Writer
1517	72	Penciler
1518	122	Writer
1518	405	Penciler
1519	253	Writer
1519	14	Penciler
1520	185	Writer
1520	284	Penciler
1521	294	Writer
1521	189	Penciler
1522	240	Writer
1522	412	Penciler
1523	283	Writer
1523	67	Penciler
1524	314	Writer
1524	453	Penciler
1525	45	Writer
1525	34	Penciler
1526	159	Writer
1526	204	Penciler
1527	368	Writer
1527	369	Penciler
1528	246	Writer
1528	270	Penciler
1529	211	Writer
1529	394	Penciler
1530	210	Writer
1530	422	Penciler
1531	295	Writer
1531	38	Penciler
1532	65	Writer
1532	498	Penciler
1533	163	Writer
1533	329	Penciler
1534	38	Writer
1534	231	Penciler
1535	239	Writer
1535	349	Penciler
1536	265	Writer
1536	177	Penciler
1537	66	Writer
1537	450	Penciler
1538	425	Writer
1538	400	Penciler
1539	283	Writer
1539	328	Penciler
1540	301	Writer
1540	94	Penciler
1541	394	Writer
1541	495	Penciler
1542	67	Writer
1542	222	Penciler
1543	258	Writer
1543	467	Penciler
1544	445	Writer
1544	29	Penciler
1545	426	Writer
1545	64	Penciler
1546	266	Writer
1546	79	Penciler
1547	156	Writer
1547	85	Penciler
1548	83	Writer
1548	166	Penciler
1549	479	Writer
1549	364	Penciler
1550	116	Writer
1550	178	Penciler
1551	486	Writer
1551	482	Penciler
1552	266	Writer
1552	459	Penciler
1553	146	Writer
1553	434	Penciler
1554	41	Writer
1554	129	Penciler
1555	101	Writer
1555	326	Penciler
1556	490	Writer
1556	283	Penciler
1557	141	Writer
1557	65	Penciler
1558	321	Writer
1558	156	Penciler
1559	315	Writer
1559	274	Penciler
1560	48	Writer
1560	258	Penciler
1561	329	Writer
1561	87	Penciler
1562	304	Writer
1562	483	Penciler
1563	298	Writer
1563	79	Penciler
1564	88	Writer
1564	338	Penciler
1565	320	Writer
1565	369	Penciler
1566	462	Writer
1566	310	Penciler
1567	173	Writer
1567	432	Penciler
1568	474	Writer
1568	289	Penciler
1569	22	Writer
1569	423	Penciler
1570	443	Writer
1570	15	Penciler
1571	42	Writer
1571	24	Penciler
1572	486	Writer
1572	329	Penciler
1573	395	Writer
1573	296	Penciler
1574	136	Writer
1574	334	Penciler
1575	108	Writer
1575	393	Penciler
1576	293	Writer
1576	214	Penciler
1577	317	Writer
1577	328	Penciler
1578	16	Writer
1578	255	Penciler
1579	456	Writer
1579	322	Penciler
1580	280	Writer
1580	149	Penciler
1581	329	Writer
1581	490	Penciler
1582	155	Writer
1582	248	Penciler
1583	126	Writer
1583	413	Penciler
1584	414	Writer
1584	351	Penciler
1585	208	Writer
1585	153	Penciler
1586	233	Writer
1586	38	Penciler
1587	353	Writer
1587	31	Penciler
1588	81	Writer
1588	226	Penciler
1589	213	Writer
1589	248	Penciler
1590	238	Writer
1590	105	Penciler
1591	175	Writer
1591	311	Penciler
1592	74	Writer
1592	161	Penciler
1593	442	Writer
1593	368	Penciler
1594	164	Writer
1594	376	Penciler
1595	441	Writer
1595	177	Penciler
1596	500	Writer
1596	205	Penciler
1597	67	Writer
1597	390	Penciler
1598	190	Writer
1598	264	Penciler
1599	288	Writer
1599	55	Penciler
1600	164	Writer
1600	124	Penciler
1601	239	Writer
1601	63	Penciler
1602	137	Writer
1602	231	Penciler
1603	127	Writer
1603	73	Penciler
1604	50	Writer
1604	26	Penciler
1605	149	Writer
1605	485	Penciler
1606	197	Writer
1606	443	Penciler
1607	316	Writer
1607	215	Penciler
1608	128	Writer
1608	493	Penciler
1609	444	Writer
1609	462	Penciler
1610	82	Writer
1610	417	Penciler
1611	168	Writer
1611	479	Penciler
1612	296	Writer
1612	370	Penciler
1613	161	Writer
1613	98	Penciler
1614	391	Writer
1614	82	Penciler
1615	256	Writer
1615	264	Penciler
1616	240	Writer
1616	256	Penciler
1617	451	Writer
1617	158	Penciler
1618	255	Writer
1618	12	Penciler
1619	47	Writer
1619	484	Penciler
1620	202	Writer
1620	259	Penciler
1621	235	Writer
1621	495	Penciler
1622	124	Writer
1622	111	Penciler
1623	299	Writer
1623	181	Penciler
1624	25	Writer
1624	26	Penciler
1625	145	Writer
1625	254	Penciler
1626	306	Writer
1626	452	Penciler
1627	432	Writer
1627	335	Penciler
1628	345	Writer
1628	241	Penciler
1629	147	Writer
1629	275	Penciler
1630	5	Writer
1630	434	Penciler
1631	56	Writer
1631	221	Penciler
1632	69	Writer
1632	452	Penciler
1633	136	Writer
1633	373	Penciler
1634	188	Writer
1634	392	Penciler
1635	207	Writer
1635	188	Penciler
1636	24	Writer
1636	206	Penciler
1637	27	Writer
1637	292	Penciler
1638	288	Writer
1638	100	Penciler
1639	186	Writer
1639	284	Penciler
1640	148	Writer
1640	38	Penciler
1641	198	Writer
1641	259	Penciler
1642	231	Writer
1642	392	Penciler
1643	282	Writer
1643	144	Penciler
1644	423	Writer
1644	320	Penciler
1645	349	Writer
1645	313	Penciler
1646	61	Writer
1646	66	Penciler
1647	500	Writer
1647	50	Penciler
1648	202	Writer
1648	192	Penciler
1649	407	Writer
1649	174	Penciler
1650	286	Writer
1650	481	Penciler
1651	188	Writer
1651	387	Penciler
1652	74	Writer
1652	102	Penciler
1653	309	Writer
1653	261	Penciler
1654	206	Writer
1654	257	Penciler
1655	21	Writer
1655	24	Penciler
1656	20	Writer
1656	71	Penciler
1657	366	Writer
1657	171	Penciler
1658	412	Writer
1658	243	Penciler
1659	266	Writer
1659	234	Penciler
1660	77	Writer
1660	311	Penciler
1661	458	Writer
1661	264	Penciler
1662	72	Writer
1662	168	Penciler
1663	477	Writer
1663	314	Penciler
1664	164	Writer
1664	84	Penciler
1665	202	Writer
1665	316	Penciler
1666	379	Writer
1666	432	Penciler
1667	154	Writer
1667	304	Penciler
1668	173	Writer
1668	260	Penciler
1669	425	Writer
1669	261	Penciler
1670	273	Writer
1670	251	Penciler
1671	363	Writer
1671	289	Penciler
1672	154	Writer
1672	244	Penciler
1673	418	Writer
1673	9	Penciler
1674	189	Writer
1674	170	Penciler
1675	345	Writer
1675	57	Penciler
1676	214	Writer
1676	299	Penciler
1677	158	Writer
1677	408	Penciler
1678	461	Writer
1678	372	Penciler
1679	447	Writer
1679	353	Penciler
1680	323	Writer
1680	14	Penciler
1681	306	Writer
1681	243	Penciler
1682	136	Writer
1682	496	Penciler
1683	336	Writer
1683	401	Penciler
1684	498	Writer
1684	398	Penciler
1685	297	Writer
1685	296	Penciler
1686	117	Writer
1686	370	Penciler
1687	27	Writer
1687	299	Penciler
1688	246	Writer
1688	88	Penciler
1689	269	Writer
1689	323	Penciler
1690	370	Writer
1690	318	Penciler
1691	397	Writer
1691	431	Penciler
1692	195	Writer
1692	76	Penciler
1693	421	Writer
1693	349	Penciler
1694	125	Writer
1694	17	Penciler
1695	294	Writer
1695	486	Penciler
1696	359	Writer
1696	57	Penciler
1697	98	Writer
1697	10	Penciler
1698	226	Writer
1698	161	Penciler
1699	215	Writer
1699	78	Penciler
1700	212	Writer
1700	354	Penciler
1701	105	Writer
1701	211	Penciler
1702	257	Writer
1702	397	Penciler
1703	314	Writer
1703	472	Penciler
1704	242	Writer
1704	447	Penciler
1705	435	Writer
1705	377	Penciler
1706	373	Writer
1706	32	Penciler
1707	362	Writer
1707	71	Penciler
1708	266	Writer
1708	107	Penciler
1709	288	Writer
1709	167	Penciler
1710	340	Writer
1710	245	Penciler
1711	270	Writer
1711	193	Penciler
1712	161	Writer
1712	490	Penciler
1713	89	Writer
1713	236	Penciler
1714	468	Writer
1714	273	Penciler
1715	176	Writer
1715	280	Penciler
1716	182	Writer
1716	347	Penciler
1717	396	Writer
1717	445	Penciler
1718	370	Writer
1718	349	Penciler
1719	330	Writer
1719	412	Penciler
1720	355	Writer
1720	136	Penciler
1721	313	Writer
1721	248	Penciler
1722	99	Writer
1722	491	Penciler
1723	127	Writer
1723	143	Penciler
1724	286	Writer
1724	153	Penciler
1725	116	Writer
1725	483	Penciler
1726	499	Writer
1726	153	Penciler
1727	395	Writer
1727	148	Penciler
1728	361	Writer
1728	107	Penciler
1729	354	Writer
1729	361	Penciler
1730	251	Writer
1730	163	Penciler
1731	246	Writer
1731	179	Penciler
1732	287	Writer
1732	479	Penciler
1733	479	Writer
1733	408	Penciler
1734	370	Writer
1734	141	Penciler
1735	148	Writer
1735	63	Penciler
1736	294	Writer
1736	347	Penciler
1737	279	Writer
1737	195	Penciler
1738	459	Writer
1738	203	Penciler
1739	420	Writer
1739	177	Penciler
1740	489	Writer
1740	396	Penciler
1741	412	Writer
1741	75	Penciler
1742	149	Writer
1742	22	Penciler
1743	148	Writer
1743	490	Penciler
1744	366	Writer
1744	41	Penciler
1745	178	Writer
1745	474	Penciler
1746	227	Writer
1746	336	Penciler
1747	132	Writer
1747	383	Penciler
1748	246	Writer
1748	110	Penciler
1749	104	Writer
1749	424	Penciler
1750	276	Writer
1750	139	Penciler
1751	478	Writer
1751	288	Penciler
1752	357	Writer
1752	140	Penciler
1753	71	Writer
1753	56	Penciler
1754	316	Writer
1754	380	Penciler
1755	301	Writer
1755	123	Penciler
1756	125	Writer
1756	26	Penciler
1757	343	Writer
1757	464	Penciler
1758	272	Writer
1758	116	Penciler
1759	327	Writer
1759	120	Penciler
1760	27	Writer
1760	52	Penciler
1761	212	Writer
1761	170	Penciler
1762	368	Writer
1762	242	Penciler
1763	52	Writer
1763	349	Penciler
1764	395	Writer
1764	71	Penciler
1765	3	Writer
1765	494	Penciler
1766	282	Writer
1766	476	Penciler
1767	81	Writer
1767	209	Penciler
1768	335	Writer
1768	479	Penciler
1769	451	Writer
1769	450	Penciler
1770	244	Writer
1770	245	Penciler
1771	334	Writer
1771	103	Penciler
1772	388	Writer
1772	494	Penciler
1773	148	Writer
1773	165	Penciler
1774	147	Writer
1774	331	Penciler
1775	31	Writer
1775	465	Penciler
1776	394	Writer
1776	46	Penciler
1777	334	Writer
1777	294	Penciler
1778	119	Writer
1778	274	Penciler
1779	379	Writer
1779	371	Penciler
1780	436	Writer
1780	480	Penciler
1781	20	Writer
1781	468	Penciler
1782	472	Writer
1782	90	Penciler
1783	214	Writer
1783	452	Penciler
1784	429	Writer
1784	91	Penciler
1785	479	Writer
1785	471	Penciler
1786	19	Writer
1786	429	Penciler
1787	204	Writer
1787	404	Penciler
1788	254	Writer
1788	96	Penciler
1789	480	Writer
1789	384	Penciler
1790	493	Writer
1790	447	Penciler
1791	475	Writer
1791	149	Penciler
1792	449	Writer
1792	20	Penciler
1793	5	Writer
1793	153	Penciler
1794	291	Writer
1794	309	Penciler
1795	55	Writer
1795	476	Penciler
1796	172	Writer
1796	146	Penciler
1797	233	Writer
1797	329	Penciler
1798	279	Writer
1798	269	Penciler
1799	253	Writer
1799	456	Penciler
1800	481	Writer
1800	69	Penciler
1801	436	Writer
1801	259	Penciler
1802	240	Writer
1802	140	Penciler
1803	99	Writer
1803	415	Penciler
1804	58	Writer
1804	170	Penciler
1805	84	Writer
1805	375	Penciler
1806	235	Writer
1806	332	Penciler
1807	132	Writer
1807	368	Penciler
1808	96	Writer
1808	8	Penciler
1809	378	Writer
1809	173	Penciler
1810	405	Writer
1810	152	Penciler
1811	291	Writer
1811	346	Penciler
1812	388	Writer
1812	99	Penciler
1813	90	Writer
1813	313	Penciler
1814	439	Writer
1814	328	Penciler
1815	460	Writer
1815	208	Penciler
1816	424	Writer
1816	219	Penciler
1817	264	Writer
1817	168	Penciler
1818	45	Writer
1818	206	Penciler
1819	343	Writer
1819	49	Penciler
1820	95	Writer
1820	72	Penciler
1821	245	Writer
1821	166	Penciler
1822	480	Writer
1822	128	Penciler
1823	4	Writer
1823	134	Penciler
1824	197	Writer
1824	121	Penciler
1825	229	Writer
1825	386	Penciler
1826	137	Writer
1826	489	Penciler
1827	169	Writer
1827	155	Penciler
1828	299	Writer
1828	371	Penciler
1829	294	Writer
1829	6	Penciler
1830	134	Writer
1830	335	Penciler
1831	185	Writer
1831	355	Penciler
1832	121	Writer
1832	32	Penciler
1833	342	Writer
1833	61	Penciler
1834	239	Writer
1834	158	Penciler
1835	82	Writer
1835	208	Penciler
1836	352	Writer
1836	258	Penciler
1837	473	Writer
1837	459	Penciler
1838	455	Writer
1838	361	Penciler
1839	395	Writer
1839	160	Penciler
1840	354	Writer
1840	61	Penciler
1841	328	Writer
1841	470	Penciler
1842	482	Writer
1842	152	Penciler
1843	189	Writer
1843	315	Penciler
1844	114	Writer
1844	113	Penciler
1845	491	Writer
1845	69	Penciler
1846	245	Writer
1846	79	Penciler
1847	233	Writer
1847	383	Penciler
1848	311	Writer
1848	192	Penciler
1849	213	Writer
1849	360	Penciler
1850	282	Writer
1850	468	Penciler
1851	242	Writer
1851	388	Penciler
1852	276	Writer
1852	411	Penciler
1853	341	Writer
1853	423	Penciler
1854	112	Writer
1854	391	Penciler
1855	127	Writer
1855	349	Penciler
1856	387	Writer
1856	306	Penciler
1857	448	Writer
1857	404	Penciler
1858	42	Writer
1858	270	Penciler
1859	229	Writer
1859	271	Penciler
1860	361	Writer
1860	186	Penciler
1861	40	Writer
1861	470	Penciler
1862	289	Writer
1862	58	Penciler
1863	32	Writer
1863	425	Penciler
1864	281	Writer
1864	463	Penciler
1865	259	Writer
1865	104	Penciler
1866	294	Writer
1866	275	Penciler
1867	77	Writer
1867	85	Penciler
1868	168	Writer
1868	438	Penciler
1869	267	Writer
1869	227	Penciler
1870	60	Writer
1870	349	Penciler
1871	106	Writer
1871	368	Penciler
1872	299	Writer
1872	251	Penciler
1873	47	Writer
1873	461	Penciler
1874	262	Writer
1874	229	Penciler
1875	415	Writer
1875	29	Penciler
1876	233	Writer
1876	68	Penciler
1877	263	Writer
1877	213	Penciler
1878	234	Writer
1878	289	Penciler
1879	30	Writer
1879	287	Penciler
1880	237	Writer
1880	345	Penciler
1881	414	Writer
1881	158	Penciler
1882	371	Writer
1882	12	Penciler
1883	203	Writer
1883	131	Penciler
1884	419	Writer
1884	2	Penciler
1885	382	Writer
1885	112	Penciler
1886	297	Writer
1886	38	Penciler
1887	24	Writer
1887	217	Penciler
1888	177	Writer
1888	359	Penciler
1889	33	Writer
1889	278	Penciler
1890	31	Writer
1890	479	Penciler
1891	458	Writer
1891	36	Penciler
1892	479	Writer
1892	242	Penciler
1893	17	Writer
1893	147	Penciler
1894	210	Writer
1894	93	Penciler
1895	394	Writer
1895	70	Penciler
1896	393	Writer
1896	329	Penciler
1897	374	Writer
1897	331	Penciler
1898	494	Writer
1898	216	Penciler
1899	192	Writer
1899	457	Penciler
1900	196	Writer
1900	230	Penciler
1901	446	Writer
1901	470	Penciler
1902	465	Writer
1902	194	Penciler
1903	193	Writer
1903	42	Penciler
1904	350	Writer
1904	494	Penciler
1905	339	Writer
1905	448	Penciler
1906	277	Writer
1906	69	Penciler
1907	335	Writer
1907	441	Penciler
1908	179	Writer
1908	61	Penciler
1909	92	Writer
1909	276	Penciler
1910	202	Writer
1910	271	Penciler
1911	66	Writer
1911	373	Penciler
1912	115	Writer
1912	428	Penciler
1913	2	Writer
1913	388	Penciler
1914	12	Writer
1914	153	Penciler
1915	238	Writer
1915	345	Penciler
1916	369	Writer
1916	279	Penciler
1917	218	Writer
1917	273	Penciler
1918	195	Writer
1918	422	Penciler
1919	118	Writer
1919	127	Penciler
1920	236	Writer
1920	178	Penciler
1921	80	Writer
1921	142	Penciler
1922	97	Writer
1922	480	Penciler
1923	449	Writer
1923	372	Penciler
1924	392	Writer
1924	58	Penciler
1925	17	Writer
1925	415	Penciler
1926	339	Writer
1926	215	Penciler
1927	315	Writer
1927	393	Penciler
1928	480	Writer
1928	453	Penciler
1929	456	Writer
1929	9	Penciler
1930	124	Writer
1930	106	Penciler
1931	35	Writer
1931	52	Penciler
1932	305	Writer
1932	18	Penciler
1933	229	Writer
1933	307	Penciler
1934	345	Writer
1934	361	Penciler
1935	447	Writer
1935	25	Penciler
1936	126	Writer
1936	380	Penciler
1937	23	Writer
1937	206	Penciler
1938	225	Writer
1938	120	Penciler
1939	277	Writer
1939	112	Penciler
1940	387	Writer
1940	443	Penciler
1941	398	Writer
1941	29	Penciler
1942	72	Writer
1942	258	Penciler
1943	149	Writer
1943	120	Penciler
1944	418	Writer
1944	470	Penciler
1945	375	Writer
1945	295	Penciler
1946	164	Writer
1946	296	Penciler
1947	307	Writer
1947	396	Penciler
1948	345	Writer
1948	420	Penciler
1949	165	Writer
1949	122	Penciler
1950	155	Writer
1950	449	Penciler
1951	74	Writer
1951	339	Penciler
1952	267	Writer
1952	114	Penciler
1953	212	Writer
1953	154	Penciler
1954	141	Writer
1954	32	Penciler
1955	286	Writer
1955	486	Penciler
1956	303	Writer
1956	451	Penciler
1957	377	Writer
1957	467	Penciler
1958	90	Writer
1958	321	Penciler
1959	348	Writer
1959	219	Penciler
1960	285	Writer
1960	254	Penciler
1961	25	Writer
1961	498	Penciler
1962	177	Writer
1962	483	Penciler
1963	330	Writer
1963	344	Penciler
1964	196	Writer
1964	403	Penciler
1965	269	Writer
1965	164	Penciler
1966	357	Writer
1966	214	Penciler
1967	210	Writer
1967	77	Penciler
1968	154	Writer
1968	193	Penciler
1969	95	Writer
1969	387	Penciler
1970	276	Writer
1970	243	Penciler
1971	124	Writer
1971	435	Penciler
1972	116	Writer
1972	154	Penciler
1973	440	Writer
1973	363	Penciler
1974	74	Writer
1974	413	Penciler
1975	238	Writer
1975	469	Penciler
1976	30	Writer
1976	288	Penciler
1977	212	Writer
1977	496	Penciler
1978	214	Writer
1978	286	Penciler
1979	272	Writer
1979	69	Penciler
1980	199	Writer
1980	125	Penciler
1981	131	Writer
1981	105	Penciler
1982	170	Writer
1982	332	Penciler
1983	41	Writer
1983	473	Penciler
1984	231	Writer
1984	434	Penciler
1985	190	Writer
1985	48	Penciler
1986	275	Writer
1986	371	Penciler
1987	425	Writer
1987	98	Penciler
1988	27	Writer
1988	138	Penciler
1989	194	Writer
1989	345	Penciler
1990	310	Writer
1990	309	Penciler
1991	21	Writer
1991	448	Penciler
1992	38	Writer
1992	97	Penciler
1993	412	Writer
1993	390	Penciler
1994	301	Writer
1994	371	Penciler
1995	344	Writer
1995	287	Penciler
1996	112	Writer
1996	246	Penciler
1997	107	Writer
1997	446	Penciler
1998	465	Writer
1998	171	Penciler
1999	156	Writer
1999	490	Penciler
2000	466	Writer
2000	8	Penciler
2001	109	Writer
2001	480	Penciler
2002	98	Writer
2002	493	Penciler
2003	380	Writer
2003	61	Penciler
2004	383	Writer
2004	387	Penciler
2005	246	Writer
2005	469	Penciler
2006	125	Writer
2006	357	Penciler
2007	310	Writer
2007	361	Penciler
2008	105	Writer
2008	204	Penciler
2009	469	Writer
2009	123	Penciler
2010	283	Writer
2010	165	Penciler
2011	398	Writer
2011	145	Penciler
2012	195	Writer
2012	239	Penciler
2013	274	Writer
2013	333	Penciler
2014	184	Writer
2014	158	Penciler
2015	134	Writer
2015	185	Penciler
2016	263	Writer
2016	452	Penciler
2017	255	Writer
2017	239	Penciler
2018	51	Writer
2018	412	Penciler
2019	370	Writer
2019	241	Penciler
2020	390	Writer
2020	430	Penciler
2021	164	Writer
2021	469	Penciler
2022	105	Writer
2022	190	Penciler
2023	161	Writer
2023	212	Penciler
2024	24	Writer
2024	289	Penciler
2025	443	Writer
2025	114	Penciler
2026	380	Writer
2026	75	Penciler
2027	9	Writer
2027	134	Penciler
2028	284	Writer
2028	479	Penciler
2029	300	Writer
2029	297	Penciler
2030	369	Writer
2030	214	Penciler
2031	152	Writer
2031	79	Penciler
2032	101	Writer
2032	169	Penciler
2033	118	Writer
2033	195	Penciler
2034	292	Writer
2034	427	Penciler
2035	126	Writer
2035	256	Penciler
2036	282	Writer
2036	336	Penciler
2037	484	Writer
2037	351	Penciler
2038	173	Writer
2038	132	Penciler
2039	391	Writer
2039	421	Penciler
2040	251	Writer
2040	495	Penciler
2041	371	Writer
2041	329	Penciler
2042	379	Writer
2042	252	Penciler
2043	236	Writer
2043	87	Penciler
2044	376	Writer
2044	408	Penciler
2045	181	Writer
2045	87	Penciler
2046	72	Writer
2046	369	Penciler
2047	280	Writer
2047	251	Penciler
2048	95	Writer
2048	470	Penciler
2049	456	Writer
2049	278	Penciler
2050	329	Writer
2050	491	Penciler
2051	31	Writer
2051	269	Penciler
2052	18	Writer
2052	430	Penciler
2053	434	Writer
2053	39	Penciler
2054	484	Writer
2054	419	Penciler
2055	343	Writer
2055	25	Penciler
2056	392	Writer
2056	4	Penciler
2057	212	Writer
2057	71	Penciler
2058	432	Writer
2058	323	Penciler
2059	119	Writer
2059	35	Penciler
2060	363	Writer
2060	78	Penciler
2061	5	Writer
2061	112	Penciler
2062	259	Writer
2062	234	Penciler
2063	192	Writer
2063	31	Penciler
2064	317	Writer
2064	327	Penciler
2065	342	Writer
2065	479	Penciler
2066	316	Writer
2066	468	Penciler
2067	248	Writer
2067	338	Penciler
2068	250	Writer
2068	9	Penciler
2069	4	Writer
2069	273	Penciler
2070	283	Writer
2070	211	Penciler
2071	7	Writer
2071	9	Penciler
2072	272	Writer
2072	370	Penciler
2073	141	Writer
2073	275	Penciler
2074	147	Writer
2074	9	Penciler
2075	258	Writer
2075	417	Penciler
2076	358	Writer
2076	346	Penciler
2077	221	Writer
2077	413	Penciler
2078	482	Writer
2078	466	Penciler
2079	92	Writer
2079	55	Penciler
2080	471	Writer
2080	50	Penciler
2081	269	Writer
2081	77	Penciler
2082	124	Writer
2082	99	Penciler
2083	318	Writer
2083	270	Penciler
2084	130	Writer
2084	418	Penciler
2085	182	Writer
2085	137	Penciler
2086	408	Writer
2086	204	Penciler
2087	41	Writer
2087	192	Penciler
2088	492	Writer
2088	208	Penciler
2089	236	Writer
2089	290	Penciler
2090	125	Writer
2090	357	Penciler
2091	116	Writer
2091	154	Penciler
2092	351	Writer
2092	424	Penciler
2093	435	Writer
2093	42	Penciler
2094	335	Writer
2094	440	Penciler
2095	333	Writer
2095	389	Penciler
2096	17	Writer
2096	48	Penciler
2097	208	Writer
2097	195	Penciler
2098	194	Writer
2098	283	Penciler
2099	244	Writer
2099	29	Penciler
2100	327	Writer
2100	5	Penciler
2101	360	Writer
2101	88	Penciler
2102	43	Writer
2102	256	Penciler
2103	433	Writer
2103	223	Penciler
2104	331	Writer
2104	402	Penciler
2105	170	Writer
2105	290	Penciler
2106	440	Writer
2106	499	Penciler
2107	49	Writer
2107	459	Penciler
2108	271	Writer
2108	471	Penciler
2109	22	Writer
2109	118	Penciler
2110	109	Writer
2110	462	Penciler
2111	445	Writer
2111	355	Penciler
2112	455	Writer
2112	291	Penciler
2113	244	Writer
2113	139	Penciler
2114	24	Writer
2114	474	Penciler
2115	39	Writer
2115	351	Penciler
2116	474	Writer
2116	144	Penciler
2117	461	Writer
2117	279	Penciler
2118	289	Writer
2118	337	Penciler
2119	17	Writer
2119	92	Penciler
2120	476	Writer
2120	436	Penciler
2121	162	Writer
2121	9	Penciler
2122	493	Writer
2122	107	Penciler
2123	301	Writer
2123	74	Penciler
2124	386	Writer
2124	421	Penciler
2125	365	Writer
2125	421	Penciler
2126	204	Writer
2126	476	Penciler
2127	40	Writer
2127	154	Penciler
2128	84	Writer
2128	289	Penciler
2129	124	Writer
2129	291	Penciler
2130	428	Writer
2130	435	Penciler
2131	200	Writer
2131	347	Penciler
2132	460	Writer
2132	277	Penciler
2133	170	Writer
2133	197	Penciler
2134	387	Writer
2134	379	Penciler
2135	72	Writer
2135	405	Penciler
2136	353	Writer
2136	371	Penciler
2137	41	Writer
2137	257	Penciler
2138	382	Writer
2138	499	Penciler
2139	178	Writer
2139	28	Penciler
2140	51	Writer
2140	224	Penciler
2141	119	Writer
2141	430	Penciler
2142	39	Writer
2142	175	Penciler
2143	310	Writer
2143	394	Penciler
2144	315	Writer
2144	489	Penciler
2145	305	Writer
2145	204	Penciler
2146	497	Writer
2146	397	Penciler
2147	168	Writer
2147	16	Penciler
2148	325	Writer
2148	140	Penciler
2149	402	Writer
2149	231	Penciler
2150	252	Writer
2150	117	Penciler
2151	183	Writer
2151	284	Penciler
2152	482	Writer
2152	193	Penciler
2153	222	Writer
2153	96	Penciler
2154	349	Writer
2154	300	Penciler
2155	339	Writer
2155	195	Penciler
2156	44	Writer
2156	396	Penciler
2157	317	Writer
2157	152	Penciler
2158	409	Writer
2158	127	Penciler
2159	366	Writer
2159	38	Penciler
2160	43	Writer
2160	138	Penciler
2161	79	Writer
2161	195	Penciler
2162	365	Writer
2162	402	Penciler
2163	325	Writer
2163	79	Penciler
2164	379	Writer
2164	200	Penciler
2165	163	Writer
2165	185	Penciler
2166	55	Writer
2166	47	Penciler
2167	3	Writer
2167	483	Penciler
2168	158	Writer
2168	228	Penciler
2169	185	Writer
2169	390	Penciler
2170	139	Writer
2170	53	Penciler
2171	68	Writer
2171	45	Penciler
2172	96	Writer
2172	221	Penciler
2173	230	Writer
2173	286	Penciler
2174	285	Writer
2174	263	Penciler
2175	209	Writer
2175	53	Penciler
2176	14	Writer
2176	46	Penciler
2177	182	Writer
2177	284	Penciler
2178	48	Writer
2178	306	Penciler
2179	307	Writer
2179	402	Penciler
2180	167	Writer
2180	443	Penciler
2181	198	Writer
2181	7	Penciler
2182	150	Writer
2182	212	Penciler
2183	199	Writer
2183	399	Penciler
2184	44	Writer
2184	372	Penciler
2185	462	Writer
2185	287	Penciler
2186	464	Writer
2186	125	Penciler
2187	293	Writer
2187	267	Penciler
2188	87	Writer
2188	351	Penciler
2189	195	Writer
2189	87	Penciler
2190	72	Writer
2190	138	Penciler
2191	155	Writer
2191	138	Penciler
2192	253	Writer
2192	75	Penciler
2193	33	Writer
2193	86	Penciler
2194	223	Writer
2194	142	Penciler
2195	216	Writer
2195	154	Penciler
2196	248	Writer
2196	401	Penciler
2197	40	Writer
2197	185	Penciler
2198	129	Writer
2198	484	Penciler
2199	127	Writer
2199	370	Penciler
2200	321	Writer
2200	254	Penciler
2201	305	Writer
2201	316	Penciler
2202	101	Writer
2202	235	Penciler
2203	55	Writer
2203	70	Penciler
2204	156	Writer
2204	4	Penciler
2205	486	Writer
2205	203	Penciler
2206	171	Writer
2206	431	Penciler
2207	318	Writer
2207	195	Penciler
2208	412	Writer
2208	442	Penciler
2209	169	Writer
2209	226	Penciler
2210	172	Writer
2210	221	Penciler
2211	418	Writer
2211	422	Penciler
2212	441	Writer
2212	334	Penciler
2213	499	Writer
2213	305	Penciler
2214	70	Writer
2214	154	Penciler
2215	165	Writer
2215	309	Penciler
2216	486	Writer
2216	356	Penciler
2217	103	Writer
2217	246	Penciler
2218	161	Writer
2218	91	Penciler
2219	494	Writer
2219	204	Penciler
2220	496	Writer
2220	164	Penciler
2221	150	Writer
2221	377	Penciler
2222	356	Writer
2222	325	Penciler
2223	252	Writer
2223	496	Penciler
2224	295	Writer
2224	401	Penciler
2225	125	Writer
2225	167	Penciler
2226	193	Writer
2226	144	Penciler
2227	419	Writer
2227	403	Penciler
2228	202	Writer
2228	187	Penciler
2229	59	Writer
2229	478	Penciler
2230	289	Writer
2230	103	Penciler
2231	304	Writer
2231	280	Penciler
2232	93	Writer
2232	350	Penciler
2233	394	Writer
2233	282	Penciler
2234	14	Writer
2234	488	Penciler
2235	373	Writer
2235	237	Penciler
2236	483	Writer
2236	363	Penciler
2237	108	Writer
2237	225	Penciler
2238	409	Writer
2238	150	Penciler
2239	426	Writer
2239	355	Penciler
2240	36	Writer
2240	420	Penciler
2241	435	Writer
2241	408	Penciler
2242	408	Writer
2242	210	Penciler
2243	345	Writer
2243	256	Penciler
2244	72	Writer
2244	325	Penciler
2245	156	Writer
2245	124	Penciler
2246	130	Writer
2246	338	Penciler
2247	79	Writer
2247	367	Penciler
2248	217	Writer
2248	405	Penciler
2249	194	Writer
2249	38	Penciler
2250	230	Writer
2250	307	Penciler
2251	246	Writer
2251	299	Penciler
2252	206	Writer
2252	274	Penciler
2253	260	Writer
2253	473	Penciler
2254	472	Writer
2254	446	Penciler
2255	355	Writer
2255	215	Penciler
2256	279	Writer
2256	19	Penciler
2257	405	Writer
2257	496	Penciler
2258	185	Writer
2258	360	Penciler
2259	459	Writer
2259	416	Penciler
2260	275	Writer
2260	305	Penciler
2261	327	Writer
2261	469	Penciler
2262	44	Writer
2262	56	Penciler
2263	394	Writer
2263	128	Penciler
2264	337	Writer
2264	341	Penciler
2265	182	Writer
2265	86	Penciler
2266	332	Writer
2266	314	Penciler
2267	23	Writer
2267	289	Penciler
2268	331	Writer
2268	347	Penciler
2269	332	Writer
2269	205	Penciler
2270	496	Writer
2270	386	Penciler
2271	170	Writer
2271	495	Penciler
2272	408	Writer
2272	221	Penciler
2273	55	Writer
2273	6	Penciler
2274	51	Writer
2274	133	Penciler
2275	114	Writer
2275	262	Penciler
2276	383	Writer
2276	266	Penciler
2277	286	Writer
2277	298	Penciler
2278	353	Writer
2278	295	Penciler
2279	114	Writer
2279	229	Penciler
2280	192	Writer
2280	201	Penciler
2281	238	Writer
2281	396	Penciler
2282	348	Writer
2282	302	Penciler
2283	354	Writer
2283	257	Penciler
2284	78	Writer
2284	177	Penciler
2285	13	Writer
2285	248	Penciler
2286	54	Writer
2286	152	Penciler
2287	213	Writer
2287	472	Penciler
2288	493	Writer
2288	44	Penciler
2289	60	Writer
2289	426	Penciler
2290	482	Writer
2290	374	Penciler
2291	73	Writer
2291	179	Penciler
2292	160	Writer
2292	176	Penciler
2293	234	Writer
2293	402	Penciler
2294	106	Writer
2294	267	Penciler
2295	248	Writer
2295	179	Penciler
2296	244	Writer
2296	50	Penciler
2297	225	Writer
2297	370	Penciler
2298	357	Writer
2298	232	Penciler
2299	164	Writer
2299	35	Penciler
2300	154	Writer
2300	23	Penciler
2301	415	Writer
2301	364	Penciler
2302	59	Writer
2302	12	Penciler
2303	435	Writer
2303	176	Penciler
2304	332	Writer
2304	56	Penciler
2305	347	Writer
2305	410	Penciler
2306	85	Writer
2306	477	Penciler
2307	380	Writer
2307	125	Penciler
2308	265	Writer
2308	90	Penciler
2309	283	Writer
2309	82	Penciler
2310	170	Writer
2310	287	Penciler
2311	219	Writer
2311	491	Penciler
2312	237	Writer
2312	119	Penciler
2313	409	Writer
2313	208	Penciler
2314	323	Writer
2314	95	Penciler
2315	96	Writer
2315	328	Penciler
2316	337	Writer
2316	222	Penciler
2317	203	Writer
2317	15	Penciler
2318	378	Writer
2318	315	Penciler
2319	453	Writer
2319	102	Penciler
2320	231	Writer
2320	304	Penciler
2321	220	Writer
2321	200	Penciler
2322	3	Writer
2322	361	Penciler
2323	110	Writer
2323	106	Penciler
2324	143	Writer
2324	386	Penciler
2325	361	Writer
2325	415	Penciler
2326	408	Writer
2326	33	Penciler
2327	296	Writer
2327	53	Penciler
2328	410	Writer
2328	447	Penciler
2329	275	Writer
2329	96	Penciler
2330	188	Writer
2330	167	Penciler
2331	101	Writer
2331	235	Penciler
2332	59	Writer
2332	135	Penciler
2333	344	Writer
2333	442	Penciler
2334	251	Writer
2334	271	Penciler
2335	495	Writer
2335	328	Penciler
2336	161	Writer
2336	306	Penciler
2337	199	Writer
2337	313	Penciler
2338	201	Writer
2338	301	Penciler
2339	59	Writer
2339	179	Penciler
2340	181	Writer
2340	433	Penciler
2341	235	Writer
2341	317	Penciler
2342	89	Writer
2342	417	Penciler
2343	345	Writer
2343	362	Penciler
2344	410	Writer
2344	153	Penciler
2345	471	Writer
2345	315	Penciler
2346	303	Writer
2346	44	Penciler
2347	345	Writer
2347	69	Penciler
2348	161	Writer
2348	61	Penciler
2349	123	Writer
2349	157	Penciler
2350	60	Writer
2350	94	Penciler
2351	192	Writer
2351	356	Penciler
2352	73	Writer
2352	262	Penciler
2353	199	Writer
2353	215	Penciler
2354	306	Writer
2354	71	Penciler
2355	295	Writer
2355	197	Penciler
2356	217	Writer
2356	96	Penciler
2357	250	Writer
2357	326	Penciler
2358	276	Writer
2358	356	Penciler
2359	471	Writer
2359	331	Penciler
2360	477	Writer
2360	89	Penciler
2361	285	Writer
2361	86	Penciler
2362	251	Writer
2362	148	Penciler
2363	72	Writer
2363	96	Penciler
2364	162	Writer
2364	432	Penciler
2365	231	Writer
2365	318	Penciler
2366	28	Writer
2366	444	Penciler
2367	184	Writer
2367	488	Penciler
2368	5	Writer
2368	249	Penciler
2369	70	Writer
2369	100	Penciler
2370	418	Writer
2370	197	Penciler
2371	494	Writer
2371	288	Penciler
2372	259	Writer
2372	335	Penciler
2373	254	Writer
2373	210	Penciler
2374	351	Writer
2374	252	Penciler
2375	213	Writer
2375	364	Penciler
2376	431	Writer
2376	228	Penciler
2377	251	Writer
2377	86	Penciler
2378	43	Writer
2378	290	Penciler
2379	16	Writer
2379	408	Penciler
2380	390	Writer
2380	113	Penciler
2381	150	Writer
2381	17	Penciler
2382	141	Writer
2382	116	Penciler
2383	276	Writer
2383	148	Penciler
2384	87	Writer
2384	400	Penciler
2385	235	Writer
2385	290	Penciler
2386	381	Writer
2386	396	Penciler
2387	393	Writer
2387	254	Penciler
2388	282	Writer
2388	262	Penciler
2389	58	Writer
2389	294	Penciler
2390	59	Writer
2390	138	Penciler
2391	397	Writer
2391	279	Penciler
2392	422	Writer
2392	188	Penciler
2393	278	Writer
2393	422	Penciler
2394	388	Writer
2394	22	Penciler
2395	390	Writer
2395	369	Penciler
2396	226	Writer
2396	280	Penciler
2397	112	Writer
2397	218	Penciler
2398	53	Writer
2398	377	Penciler
2399	425	Writer
2399	335	Penciler
2400	385	Writer
2400	127	Penciler
2401	153	Writer
2401	448	Penciler
2402	17	Writer
2402	231	Penciler
2403	135	Writer
2403	179	Penciler
2404	442	Writer
2404	419	Penciler
2405	45	Writer
2405	225	Penciler
2406	444	Writer
2406	61	Penciler
2407	398	Writer
2407	416	Penciler
2408	122	Writer
2408	108	Penciler
2409	416	Writer
2409	378	Penciler
2410	302	Writer
2410	353	Penciler
2411	180	Writer
2411	441	Penciler
2412	364	Writer
2412	313	Penciler
2413	324	Writer
2413	220	Penciler
2414	85	Writer
2414	316	Penciler
2415	72	Writer
2415	402	Penciler
2416	106	Writer
2416	417	Penciler
2417	106	Writer
2417	413	Penciler
2418	31	Writer
2418	292	Penciler
2419	180	Writer
2419	273	Penciler
2420	144	Writer
2420	306	Penciler
2421	276	Writer
2421	87	Penciler
2422	166	Writer
2422	361	Penciler
2423	150	Writer
2423	149	Penciler
2424	294	Writer
2424	137	Penciler
2425	488	Writer
2425	440	Penciler
2426	264	Writer
2426	461	Penciler
2427	348	Writer
2427	418	Penciler
2428	49	Writer
2428	70	Penciler
2429	493	Writer
2429	385	Penciler
2430	403	Writer
2430	211	Penciler
2431	471	Writer
2431	31	Penciler
2432	142	Writer
2432	444	Penciler
2433	336	Writer
2433	65	Penciler
2434	360	Writer
2434	444	Penciler
2435	68	Writer
2435	128	Penciler
2436	75	Writer
2436	365	Penciler
2437	165	Writer
2437	425	Penciler
2438	127	Writer
2438	390	Penciler
2439	432	Writer
2439	347	Penciler
2440	202	Writer
2440	251	Penciler
2441	73	Writer
2441	296	Penciler
2442	324	Writer
2442	138	Penciler
2443	322	Writer
2443	213	Penciler
2444	193	Writer
2444	232	Penciler
2445	39	Writer
2445	325	Penciler
2446	407	Writer
2446	451	Penciler
2447	394	Writer
2447	48	Penciler
2448	207	Writer
2448	264	Penciler
2449	384	Writer
2449	143	Penciler
2450	356	Writer
2450	480	Penciler
2451	450	Writer
2451	189	Penciler
2452	233	Writer
2452	487	Penciler
2453	250	Writer
2453	168	Penciler
2454	298	Writer
2454	2	Penciler
2455	445	Writer
2455	397	Penciler
2456	434	Writer
2456	376	Penciler
2457	48	Writer
2457	375	Penciler
2458	498	Writer
2458	235	Penciler
2459	326	Writer
2459	341	Penciler
2460	358	Writer
2460	184	Penciler
2461	436	Writer
2461	33	Penciler
2462	408	Writer
2462	274	Penciler
2463	204	Writer
2463	112	Penciler
2464	496	Writer
2464	220	Penciler
2465	423	Writer
2465	109	Penciler
2466	254	Writer
2466	138	Penciler
2467	166	Writer
2467	425	Penciler
2468	146	Writer
2468	173	Penciler
2469	281	Writer
2469	296	Penciler
2470	67	Writer
2470	290	Penciler
2471	437	Writer
2471	249	Penciler
2472	404	Writer
2472	176	Penciler
2473	458	Writer
2473	350	Penciler
2474	391	Writer
2474	25	Penciler
2475	24	Writer
2475	51	Penciler
2476	321	Writer
2476	402	Penciler
2477	429	Writer
2477	236	Penciler
2478	9	Writer
2478	64	Penciler
2479	476	Writer
2479	440	Penciler
2480	81	Writer
2480	226	Penciler
2481	234	Writer
2481	1	Penciler
2482	491	Writer
2482	220	Penciler
2483	104	Writer
2483	353	Penciler
2484	466	Writer
2484	68	Penciler
2485	452	Writer
2485	333	Penciler
2486	155	Writer
2486	82	Penciler
2487	448	Writer
2487	478	Penciler
2488	449	Writer
2488	141	Penciler
2489	48	Writer
2489	336	Penciler
2490	185	Writer
2490	129	Penciler
2491	43	Writer
2491	191	Penciler
2492	341	Writer
2492	463	Penciler
2493	333	Writer
2493	85	Penciler
2494	27	Writer
2494	203	Penciler
2495	321	Writer
2495	157	Penciler
2496	372	Writer
2496	359	Penciler
2497	387	Writer
2497	120	Penciler
2498	220	Writer
2498	336	Penciler
2499	47	Writer
2499	361	Penciler
2500	49	Writer
2500	1	Penciler
2501	110	Writer
2501	245	Penciler
2502	40	Writer
2502	68	Penciler
2503	304	Writer
2503	116	Penciler
2504	266	Writer
2504	349	Penciler
2505	228	Writer
2505	5	Penciler
2506	5	Writer
2506	357	Penciler
2507	176	Writer
2507	419	Penciler
2508	62	Writer
2508	441	Penciler
2509	217	Writer
2509	356	Penciler
2510	68	Writer
2510	245	Penciler
2511	37	Writer
2511	118	Penciler
2512	197	Writer
2512	46	Penciler
2513	375	Writer
2513	413	Penciler
2514	53	Writer
2514	53	Penciler
2515	161	Writer
2515	189	Penciler
2516	452	Writer
2516	154	Penciler
2517	71	Writer
2517	196	Penciler
2518	397	Writer
2518	417	Penciler
2519	386	Writer
2519	448	Penciler
2520	69	Writer
2520	329	Penciler
2521	347	Writer
2521	74	Penciler
2522	36	Writer
2522	272	Penciler
2523	289	Writer
2523	5	Penciler
2524	313	Writer
2524	333	Penciler
2525	85	Writer
2525	226	Penciler
2526	180	Writer
2526	370	Penciler
2527	110	Writer
2527	322	Penciler
2528	384	Writer
2528	78	Penciler
2529	471	Writer
2529	211	Penciler
2530	316	Writer
2530	352	Penciler
2531	227	Writer
2531	441	Penciler
2532	112	Writer
2532	45	Penciler
2533	460	Writer
2533	52	Penciler
2534	72	Writer
2534	386	Penciler
2535	64	Writer
2535	302	Penciler
2536	374	Writer
2536	197	Penciler
2537	180	Writer
2537	494	Penciler
2538	220	Writer
2538	162	Penciler
2539	406	Writer
2539	72	Penciler
2540	127	Writer
2540	142	Penciler
2541	331	Writer
2541	44	Penciler
2542	128	Writer
2542	284	Penciler
2543	308	Writer
2543	308	Penciler
2544	370	Writer
2544	312	Penciler
2545	146	Writer
2545	399	Penciler
2546	482	Writer
2546	354	Penciler
2547	14	Writer
2547	435	Penciler
2548	434	Writer
2548	338	Penciler
2549	449	Writer
2549	155	Penciler
2550	106	Writer
2550	266	Penciler
2551	311	Writer
2551	261	Penciler
2552	97	Writer
2552	383	Penciler
2553	201	Writer
2553	152	Penciler
2554	331	Writer
2554	28	Penciler
2555	402	Writer
2555	460	Penciler
2556	407	Writer
2556	489	Penciler
2557	123	Writer
2557	254	Penciler
2558	198	Writer
2558	58	Penciler
2559	124	Writer
2559	256	Penciler
2560	327	Writer
2560	305	Penciler
2561	37	Writer
2561	271	Penciler
2562	456	Writer
2562	7	Penciler
2563	185	Writer
2563	479	Penciler
2564	163	Writer
2564	68	Penciler
2565	199	Writer
2565	441	Penciler
2566	430	Writer
2566	292	Penciler
2567	216	Writer
2567	188	Penciler
2568	280	Writer
2568	350	Penciler
2569	89	Writer
2569	391	Penciler
2570	242	Writer
2570	489	Penciler
2571	395	Writer
2571	38	Penciler
2572	9	Writer
2572	301	Penciler
2573	35	Writer
2573	8	Penciler
2574	135	Writer
2574	111	Penciler
2575	21	Writer
2575	473	Penciler
2576	31	Writer
2576	486	Penciler
2577	405	Writer
2577	204	Penciler
2578	260	Writer
2578	147	Penciler
2579	322	Writer
2579	365	Penciler
2580	257	Writer
2580	393	Penciler
2581	213	Writer
2581	217	Penciler
2582	360	Writer
2582	206	Penciler
2583	43	Writer
2583	328	Penciler
2584	275	Writer
2584	276	Penciler
2585	316	Writer
2585	79	Penciler
2586	143	Writer
2586	43	Penciler
2587	159	Writer
2587	41	Penciler
2588	262	Writer
2588	472	Penciler
2589	105	Writer
2589	499	Penciler
2590	414	Writer
2590	80	Penciler
2591	275	Writer
2591	168	Penciler
2592	201	Writer
2592	301	Penciler
2593	325	Writer
2593	391	Penciler
2594	428	Writer
2594	333	Penciler
2595	349	Writer
2595	330	Penciler
2596	34	Writer
2596	159	Penciler
2597	358	Writer
2597	224	Penciler
2598	374	Writer
2598	489	Penciler
2599	434	Writer
2599	123	Penciler
2600	30	Writer
2600	126	Penciler
2601	45	Writer
2601	474	Penciler
2602	223	Writer
2602	60	Penciler
2603	233	Writer
2603	314	Penciler
2604	312	Writer
2604	29	Penciler
2605	159	Writer
2605	342	Penciler
2606	380	Writer
2606	337	Penciler
2607	380	Writer
2607	90	Penciler
2608	62	Writer
2608	7	Penciler
2609	363	Writer
2609	71	Penciler
2610	360	Writer
2610	6	Penciler
2611	84	Writer
2611	255	Penciler
2612	488	Writer
2612	178	Penciler
2613	268	Writer
2613	265	Penciler
2614	401	Writer
2614	422	Penciler
2615	370	Writer
2615	133	Penciler
2616	86	Writer
2616	191	Penciler
2617	65	Writer
2617	384	Penciler
2618	400	Writer
2618	448	Penciler
2619	138	Writer
2619	376	Penciler
2620	454	Writer
2620	61	Penciler
2621	395	Writer
2621	461	Penciler
2622	16	Writer
2622	172	Penciler
2623	414	Writer
2623	220	Penciler
2624	140	Writer
2624	269	Penciler
2625	33	Writer
2625	135	Penciler
2626	365	Writer
2626	500	Penciler
2627	296	Writer
2627	322	Penciler
2628	40	Writer
2628	255	Penciler
2629	234	Writer
2629	262	Penciler
2630	185	Writer
2630	29	Penciler
2631	256	Writer
2631	440	Penciler
2632	291	Writer
2632	86	Penciler
2633	189	Writer
2633	81	Penciler
2634	131	Writer
2634	396	Penciler
2635	53	Writer
2635	458	Penciler
2636	294	Writer
2636	346	Penciler
2637	371	Writer
2637	60	Penciler
2638	117	Writer
2638	380	Penciler
2639	261	Writer
2639	2	Penciler
2640	23	Writer
2640	440	Penciler
2641	442	Writer
2641	7	Penciler
2642	126	Writer
2642	24	Penciler
2643	242	Writer
2643	187	Penciler
2644	197	Writer
2644	472	Penciler
2645	77	Writer
2645	92	Penciler
2646	477	Writer
2646	492	Penciler
2647	440	Writer
2647	19	Penciler
2648	284	Writer
2648	412	Penciler
2649	468	Writer
2649	366	Penciler
2650	380	Writer
2650	336	Penciler
2651	215	Writer
2651	115	Penciler
2652	165	Writer
2652	128	Penciler
2653	214	Writer
2653	469	Penciler
2654	369	Writer
2654	164	Penciler
2655	139	Writer
2655	423	Penciler
2656	40	Writer
2656	293	Penciler
2657	191	Writer
2657	62	Penciler
2658	258	Writer
2658	345	Penciler
2659	462	Writer
2659	27	Penciler
2660	92	Writer
2660	115	Penciler
2661	412	Writer
2661	265	Penciler
2662	24	Writer
2662	489	Penciler
2663	206	Writer
2663	36	Penciler
2664	450	Writer
2664	239	Penciler
2665	444	Writer
2665	145	Penciler
2666	397	Writer
2666	433	Penciler
2667	160	Writer
2667	168	Penciler
2668	45	Writer
2668	284	Penciler
2669	234	Writer
2669	5	Penciler
2670	189	Writer
2670	103	Penciler
2671	150	Writer
2671	289	Penciler
2672	402	Writer
2672	156	Penciler
2673	379	Writer
2673	319	Penciler
2674	125	Writer
2674	238	Penciler
2675	189	Writer
2675	303	Penciler
2676	498	Writer
2676	253	Penciler
2677	396	Writer
2677	398	Penciler
2678	101	Writer
2678	376	Penciler
2679	462	Writer
2679	280	Penciler
2680	390	Writer
2680	408	Penciler
2681	126	Writer
2681	78	Penciler
2682	4	Writer
2682	478	Penciler
2683	210	Writer
2683	13	Penciler
2684	120	Writer
2684	278	Penciler
2685	178	Writer
2685	326	Penciler
2686	430	Writer
2686	356	Penciler
2687	450	Writer
2687	5	Penciler
2688	487	Writer
2688	172	Penciler
2689	1	Writer
2689	389	Penciler
2690	337	Writer
2690	193	Penciler
2691	435	Writer
2691	378	Penciler
2692	373	Writer
2692	158	Penciler
2693	54	Writer
2693	106	Penciler
2694	272	Writer
2694	122	Penciler
2695	215	Writer
2695	252	Penciler
2696	493	Writer
2696	31	Penciler
2697	498	Writer
2697	73	Penciler
2698	365	Writer
2698	144	Penciler
2699	48	Writer
2699	23	Penciler
2700	472	Writer
2700	119	Penciler
2701	460	Writer
2701	433	Penciler
2702	267	Writer
2702	212	Penciler
2703	359	Writer
2703	459	Penciler
2704	191	Writer
2704	235	Penciler
2705	499	Writer
2705	383	Penciler
2706	44	Writer
2706	298	Penciler
2707	49	Writer
2707	259	Penciler
2708	69	Writer
2708	327	Penciler
2709	420	Writer
2709	202	Penciler
2710	39	Writer
2710	304	Penciler
2711	291	Writer
2711	32	Penciler
2712	223	Writer
2712	340	Penciler
2713	494	Writer
2713	67	Penciler
2714	122	Writer
2714	150	Penciler
2715	134	Writer
2715	436	Penciler
2716	162	Writer
2716	475	Penciler
2717	411	Writer
2717	202	Penciler
2718	359	Writer
2718	426	Penciler
2719	377	Writer
2719	168	Penciler
2720	163	Writer
2720	232	Penciler
2721	140	Writer
2721	120	Penciler
2722	39	Writer
2722	484	Penciler
2723	104	Writer
2723	70	Penciler
2724	400	Writer
2724	395	Penciler
2725	300	Writer
2725	56	Penciler
2726	80	Writer
2726	55	Penciler
2727	85	Writer
2727	231	Penciler
2728	239	Writer
2728	161	Penciler
2729	209	Writer
2729	62	Penciler
2730	275	Writer
2730	184	Penciler
2731	494	Writer
2731	395	Penciler
2732	107	Writer
2732	232	Penciler
2733	158	Writer
2733	238	Penciler
2734	136	Writer
2734	437	Penciler
2735	62	Writer
2735	47	Penciler
2736	81	Writer
2736	414	Penciler
2737	352	Writer
2737	156	Penciler
2738	424	Writer
2738	361	Penciler
2739	357	Writer
2739	309	Penciler
2740	21	Writer
2740	111	Penciler
2741	428	Writer
2741	439	Penciler
2742	168	Writer
2742	76	Penciler
2743	47	Writer
2743	365	Penciler
2744	128	Writer
2744	496	Penciler
2745	183	Writer
2745	203	Penciler
2746	263	Writer
2746	26	Penciler
2747	347	Writer
2747	154	Penciler
2748	134	Writer
2748	420	Penciler
2749	90	Writer
2749	16	Penciler
2750	488	Writer
2750	208	Penciler
2751	438	Writer
2751	232	Penciler
2752	285	Writer
2752	384	Penciler
2753	282	Writer
2753	128	Penciler
2754	49	Writer
2754	237	Penciler
2755	53	Writer
2755	412	Penciler
2756	407	Writer
2756	72	Penciler
2757	63	Writer
2757	7	Penciler
2758	32	Writer
2758	426	Penciler
2759	400	Writer
2759	114	Penciler
2760	67	Writer
2760	102	Penciler
2761	422	Writer
2761	206	Penciler
2762	191	Writer
2762	352	Penciler
2763	323	Writer
2763	481	Penciler
2764	331	Writer
2764	44	Penciler
2765	299	Writer
2765	301	Penciler
2766	133	Writer
2766	470	Penciler
2767	417	Writer
2767	39	Penciler
2768	12	Writer
2768	34	Penciler
2769	102	Writer
2769	463	Penciler
2770	331	Writer
2770	228	Penciler
2771	415	Writer
2771	66	Penciler
2772	48	Writer
2772	464	Penciler
2773	434	Writer
2773	425	Penciler
2774	415	Writer
2774	170	Penciler
2775	63	Writer
2775	22	Penciler
2776	483	Writer
2776	237	Penciler
2777	26	Writer
2777	87	Penciler
2778	474	Writer
2778	294	Penciler
2779	222	Writer
2779	421	Penciler
2780	371	Writer
2780	203	Penciler
2781	255	Writer
2781	16	Penciler
2782	196	Writer
2782	350	Penciler
2783	219	Writer
2783	89	Penciler
2784	182	Writer
2784	110	Penciler
2785	466	Writer
2785	96	Penciler
2786	141	Writer
2786	144	Penciler
2787	229	Writer
2787	453	Penciler
2788	77	Writer
2788	18	Penciler
2789	315	Writer
2789	318	Penciler
2790	316	Writer
2790	126	Penciler
2791	332	Writer
2791	152	Penciler
2792	256	Writer
2792	211	Penciler
2793	452	Writer
2793	282	Penciler
2794	246	Writer
2794	32	Penciler
2795	45	Writer
2795	144	Penciler
2796	197	Writer
2796	71	Penciler
2797	215	Writer
2797	103	Penciler
2798	330	Writer
2798	453	Penciler
2799	409	Writer
2799	270	Penciler
2800	128	Writer
2800	323	Penciler
2801	411	Writer
2801	279	Penciler
2802	407	Writer
2802	10	Penciler
2803	196	Writer
2803	401	Penciler
2804	366	Writer
2804	184	Penciler
2805	246	Writer
2805	279	Penciler
2806	401	Writer
2806	249	Penciler
2807	177	Writer
2807	468	Penciler
2808	290	Writer
2808	258	Penciler
2809	165	Writer
2809	199	Penciler
2810	139	Writer
2810	93	Penciler
2811	14	Writer
2811	164	Penciler
2812	306	Writer
2812	113	Penciler
2813	16	Writer
2813	459	Penciler
2814	416	Writer
2814	399	Penciler
2815	144	Writer
2815	30	Penciler
2816	415	Writer
2816	242	Penciler
2817	272	Writer
2817	184	Penciler
2818	393	Writer
2818	300	Penciler
2819	120	Writer
2819	499	Penciler
2820	82	Writer
2820	52	Penciler
2821	127	Writer
2821	337	Penciler
2822	124	Writer
2822	137	Penciler
2823	274	Writer
2823	418	Penciler
2824	406	Writer
2824	470	Penciler
2825	378	Writer
2825	29	Penciler
2826	392	Writer
2826	486	Penciler
2827	113	Writer
2827	295	Penciler
2828	434	Writer
2828	409	Penciler
2829	199	Writer
2829	182	Penciler
2830	479	Writer
2830	430	Penciler
2831	433	Writer
2831	89	Penciler
2832	91	Writer
2832	122	Penciler
2833	304	Writer
2833	163	Penciler
2834	413	Writer
2834	378	Penciler
2835	358	Writer
2835	184	Penciler
2836	468	Writer
2836	303	Penciler
2837	15	Writer
2837	361	Penciler
2838	359	Writer
2838	181	Penciler
2839	486	Writer
2839	291	Penciler
2840	289	Writer
2840	73	Penciler
2841	289	Writer
2841	486	Penciler
2842	97	Writer
2842	429	Penciler
2843	415	Writer
2843	452	Penciler
2844	497	Writer
2844	253	Penciler
2845	278	Writer
2845	159	Penciler
2846	90	Writer
2846	252	Penciler
2847	20	Writer
2847	47	Penciler
2848	29	Writer
2848	120	Penciler
2849	309	Writer
2849	113	Penciler
2850	11	Writer
2850	270	Penciler
2851	245	Writer
2851	1	Penciler
2852	170	Writer
2852	470	Penciler
2853	315	Writer
2853	104	Penciler
2854	413	Writer
2854	67	Penciler
2855	175	Writer
2855	368	Penciler
2856	91	Writer
2856	471	Penciler
2857	411	Writer
2857	433	Penciler
2858	445	Writer
2858	166	Penciler
2859	31	Writer
2859	12	Penciler
2860	76	Writer
2860	301	Penciler
2861	361	Writer
2861	470	Penciler
2862	73	Writer
2862	397	Penciler
2863	57	Writer
2863	434	Penciler
2864	270	Writer
2864	441	Penciler
2865	187	Writer
2865	492	Penciler
2866	38	Writer
2866	192	Penciler
2867	361	Writer
2867	483	Penciler
2868	340	Writer
2868	203	Penciler
2869	301	Writer
2869	52	Penciler
2870	173	Writer
2870	155	Penciler
2871	166	Writer
2871	70	Penciler
2872	500	Writer
2872	81	Penciler
2873	375	Writer
2873	486	Penciler
2874	224	Writer
2874	406	Penciler
2875	328	Writer
2875	492	Penciler
2876	250	Writer
2876	333	Penciler
2877	163	Writer
2877	90	Penciler
2878	363	Writer
2878	496	Penciler
2879	288	Writer
2879	356	Penciler
2880	456	Writer
2880	476	Penciler
2881	315	Writer
2881	403	Penciler
2882	183	Writer
2882	115	Penciler
2883	341	Writer
2883	302	Penciler
2884	418	Writer
2884	90	Penciler
2885	194	Writer
2885	158	Penciler
2886	376	Writer
2886	353	Penciler
2887	151	Writer
2887	66	Penciler
2888	91	Writer
2888	374	Penciler
2889	1	Writer
2889	486	Penciler
2890	360	Writer
2890	486	Penciler
2891	294	Writer
2891	201	Penciler
2892	436	Writer
2892	395	Penciler
2893	495	Writer
2893	291	Penciler
2894	17	Writer
2894	94	Penciler
2895	309	Writer
2895	163	Penciler
2896	472	Writer
2896	415	Penciler
2897	496	Writer
2897	314	Penciler
2898	114	Writer
2898	328	Penciler
2899	290	Writer
2899	54	Penciler
2900	480	Writer
2900	255	Penciler
2901	73	Writer
2901	170	Penciler
2902	382	Writer
2902	40	Penciler
2903	122	Writer
2903	178	Penciler
2904	164	Writer
2904	86	Penciler
2905	326	Writer
2905	454	Penciler
2906	494	Writer
2906	46	Penciler
2907	421	Writer
2907	363	Penciler
2908	344	Writer
2908	328	Penciler
2909	374	Writer
2909	454	Penciler
2910	172	Writer
2910	229	Penciler
2911	6	Writer
2911	136	Penciler
2912	108	Writer
2912	128	Penciler
2913	355	Writer
2913	35	Penciler
2914	180	Writer
2914	132	Penciler
2915	403	Writer
2915	56	Penciler
2916	369	Writer
2916	1	Penciler
2917	25	Writer
2917	198	Penciler
2918	225	Writer
2918	376	Penciler
2919	215	Writer
2919	497	Penciler
2920	86	Writer
2920	453	Penciler
2921	212	Writer
2921	253	Penciler
2922	452	Writer
2922	194	Penciler
2923	180	Writer
2923	280	Penciler
2924	193	Writer
2924	52	Penciler
2925	425	Writer
2925	246	Penciler
2926	404	Writer
2926	443	Penciler
2927	296	Writer
2927	334	Penciler
2928	389	Writer
2928	352	Penciler
2929	116	Writer
2929	84	Penciler
2930	232	Writer
2930	38	Penciler
2931	410	Writer
2931	434	Penciler
2932	18	Writer
2932	151	Penciler
2933	11	Writer
2933	164	Penciler
2934	134	Writer
2934	488	Penciler
2935	54	Writer
2935	38	Penciler
2936	176	Writer
2936	88	Penciler
2937	455	Writer
2937	193	Penciler
2938	83	Writer
2938	375	Penciler
2939	39	Writer
2939	281	Penciler
2940	483	Writer
2940	460	Penciler
2941	48	Writer
2941	174	Penciler
2942	305	Writer
2942	315	Penciler
2943	458	Writer
2943	248	Penciler
2944	361	Writer
2944	16	Penciler
2945	221	Writer
2945	483	Penciler
2946	335	Writer
2946	85	Penciler
2947	311	Writer
2947	456	Penciler
2948	223	Writer
2948	81	Penciler
2949	28	Writer
2949	52	Penciler
2950	170	Writer
2950	106	Penciler
2951	499	Writer
2951	98	Penciler
2952	210	Writer
2952	357	Penciler
2953	284	Writer
2953	370	Penciler
2954	474	Writer
2954	374	Penciler
2955	277	Writer
2955	136	Penciler
2956	339	Writer
2956	145	Penciler
2957	153	Writer
2957	122	Penciler
2958	50	Writer
2958	26	Penciler
2959	202	Writer
2959	293	Penciler
2960	282	Writer
2960	431	Penciler
2961	252	Writer
2961	79	Penciler
2962	28	Writer
2962	185	Penciler
2963	2	Writer
2963	219	Penciler
2964	45	Writer
2964	151	Penciler
2965	422	Writer
2965	339	Penciler
2966	321	Writer
2966	308	Penciler
2967	246	Writer
2967	103	Penciler
2968	50	Writer
2968	14	Penciler
2969	106	Writer
2969	88	Penciler
2970	327	Writer
2970	150	Penciler
2971	42	Writer
2971	243	Penciler
2972	433	Writer
2972	60	Penciler
2973	158	Writer
2973	402	Penciler
2974	204	Writer
2974	242	Penciler
2975	251	Writer
2975	459	Penciler
2976	339	Writer
2976	136	Penciler
2977	47	Writer
2977	329	Penciler
2978	279	Writer
2978	199	Penciler
2979	95	Writer
2979	190	Penciler
2980	454	Writer
2980	196	Penciler
2981	190	Writer
2981	96	Penciler
2982	229	Writer
2982	23	Penciler
2983	135	Writer
2983	226	Penciler
2984	239	Writer
2984	135	Penciler
2985	116	Writer
2985	429	Penciler
2986	138	Writer
2986	289	Penciler
2987	32	Writer
2987	78	Penciler
2988	386	Writer
2988	357	Penciler
2989	342	Writer
2989	50	Penciler
2990	44	Writer
2990	343	Penciler
2991	177	Writer
2991	414	Penciler
2992	278	Writer
2992	212	Penciler
2993	498	Writer
2993	388	Penciler
2994	302	Writer
2994	117	Penciler
2995	284	Writer
2995	32	Penciler
2996	431	Writer
2996	199	Penciler
2997	420	Writer
2997	268	Penciler
2998	215	Writer
2998	495	Penciler
2999	275	Writer
2999	352	Penciler
3000	444	Writer
3000	480	Penciler
\.


--
-- TOC entry 5115 (class 0 OID 32966)
-- Dependencies: 233
-- Data for Name: issue_story_arc; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.issue_story_arc (issue_id, arc_id, part_num) FROM stdin;
282	196	1
2271	54	1
2402	56	1
955	85	1
605	153	1
12	71	1
593	34	1
2213	65	1
715	29	1
2708	7	1
540	4	1
1468	61	1
2412	83	1
65	45	1
1087	14	1
520	190	1
1725	135	1
466	191	1
261	122	1
1837	200	1
1483	132	1
2432	28	1
1852	129	1
908	158	1
178	187	1
2699	134	1
1236	118	1
2636	8	1
250	123	1
1646	110	1
2811	28	2
2009	183	1
1817	19	1
331	83	2
2492	38	1
270	33	1
1127	160	1
2594	150	1
2247	183	2
1332	98	1
2447	136	1
1208	117	1
2071	155	1
1763	26	1
2875	30	1
2682	167	1
2259	185	1
881	111	1
1850	59	1
1695	87	1
1858	103	1
1704	187	2
390	81	1
1749	81	2
2725	66	1
1534	40	1
2814	122	2
275	24	1
350	24	2
1769	25	1
1527	34	2
2279	16	1
2403	144	1
2301	85	2
2745	32	1
1683	91	1
2726	193	1
1733	185	2
211	74	1
2460	80	1
1441	27	1
2368	130	1
872	40	2
2690	124	1
919	28	3
1435	143	1
1506	30	2
1142	147	1
927	110	2
2298	197	1
2547	158	2
2765	165	1
2281	7	2
2495	169	1
2841	69	1
119	47	1
1120	180	1
1266	87	2
1438	2	1
744	37	1
2320	169	2
1642	18	1
582	190	2
2594	8	2
376	192	1
2173	56	2
1541	108	1
1859	88	1
645	95	1
1277	185	3
1329	199	1
2325	153	2
348	14	2
638	41	1
2531	13	1
2761	21	1
1115	114	1
2712	109	1
1990	156	1
1811	107	1
1119	56	3
2099	30	3
1414	111	2
455	73	1
2778	174	1
2430	125	1
2159	171	1
1264	12	1
904	102	1
2455	15	1
32	53	1
1235	55	1
563	196	2
1047	75	1
1344	31	1
32	128	1
1764	45	2
530	98	2
2182	181	1
943	129	2
2289	172	1
1451	19	2
1627	190	3
174	112	1
77	118	2
319	81	3
2359	110	3
2349	104	1
2907	164	1
1711	75	2
472	104	2
86	84	1
704	159	1
1885	177	1
1483	23	1
1789	28	4
997	112	2
2413	103	2
2147	21	2
1622	80	2
1391	57	1
1365	200	2
689	20	1
2091	163	1
468	136	2
2089	50	1
1432	90	1
2980	166	1
605	61	2
422	38	2
1049	51	1
711	155	2
627	195	1
2685	20	2
726	198	1
2573	127	1
1901	194	1
2310	195	2
2374	115	1
2790	145	1
2634	163	2
2559	83	3
2570	81	4
619	113	1
280	121	1
1812	162	1
1241	71	2
2423	15	2
1442	130	2
304	80	3
1892	116	1
155	15	3
1511	74	2
315	166	2
370	158	3
2434	130	3
1575	119	1
2378	142	1
169	116	2
2342	167	2
772	83	4
2479	122	3
2054	39	1
254	116	3
424	88	2
2926	22	1
2067	166	3
707	11	1
1015	182	1
1794	113	2
2147	134	2
2498	41	2
1491	96	1
1159	100	1
1675	199	2
1386	174	2
2449	14	3
2585	166	4
1371	17	1
1351	25	2
2286	174	3
1584	73	2
1033	186	1
2690	155	3
616	86	1
334	150	2
2719	37	2
1433	80	4
2688	179	1
2713	101	1
529	153	3
2904	22	2
1269	144	2
1543	165	2
1346	33	2
2745	180	2
2808	135	2
383	166	5
2747	109	2
2083	93	1
75	93	2
1266	47	2
878	88	3
1992	50	2
928	36	1
635	20	3
1212	26	2
2080	198	2
2211	190	4
2157	10	1
2712	87	3
2532	34	3
2447	97	1
632	42	1
741	178	1
2559	43	1
2954	113	3
179	106	1
1493	174	4
2948	61	3
1820	157	1
1168	193	2
1839	60	1
2188	62	1
1268	121	2
795	95	2
2779	147	2
1805	119	2
1155	200	3
1565	129	3
2161	108	2
664	52	1
2477	36	2
1025	14	4
2627	124	2
1521	142	2
421	183	3
2114	32	2
1168	22	3
657	70	1
1841	132	2
604	112	3
376	57	2
1848	90	2
110	107	2
219	102	2
2057	96	2
966	99	1
335	96	3
920	8	3
1306	26	3
2928	167	3
1374	38	3
564	10	2
1176	121	3
2852	36	3
2890	121	4
1838	158	4
22	21	3
78	66	2
884	39	2
2248	187	3
2494	136	3
1734	29	2
1181	61	4
1234	32	3
196	62	2
1720	164	2
2552	118	3
258	29	3
2048	153	4
2196	5	1
2589	132	3
2356	62	3
2944	37	3
1194	110	4
7	158	5
1446	62	4
2338	107	3
768	171	2
2738	22	4
2145	93	3
278	135	3
2229	130	4
2080	142	3
84	100	2
1926	12	2
2604	100	3
1530	65	2
67	92	1
277	89	1
988	188	1
2692	161	1
425	198	3
2384	189	1
1362	35	1
182	91	2
2237	87	4
2633	45	3
2805	119	3
2849	123	2
2588	47	3
553	17	2
2933	199	3
1875	10	3
1202	52	2
180	52	3
172	81	5
1271	132	4
1632	140	1
1940	65	3
150	193	3
2650	49	1
1172	92	2
196	168	1
1360	70	2
510	95	3
1790	103	3
1802	99	2
1389	48	1
2033	178	2
2038	95	4
2127	69	2
339	187	4
1739	21	4
1764	155	4
740	140	2
1204	83	5
421	21	5
1344	170	1
1211	79	1
1827	155	5
2940	110	5
683	177	2
1819	90	3
1832	11	2
2978	91	3
2519	112	4
1125	164	3
235	20	4
2750	164	4
1664	94	1
2102	192	2
2783	41	3
128	37	4
2489	174	5
1795	9	1
518	18	2
967	200	4
2643	94	2
1484	99	3
2324	9	2
2479	40	3
2782	116	4
1520	96	4
1819	196	3
315	147	3
564	136	4
1504	102	3
1288	167	4
1142	64	1
465	7	3
763	128	2
2121	100	4
2301	31	2
1073	199	4
1067	181	2
1828	55	2
2507	74	3
2843	126	1
820	32	4
556	19	3
1852	45	4
2922	114	2
360	175	1
1310	171	3
1424	182	2
266	141	1
2221	75	3
1229	41	4
2916	182	3
2869	164	5
714	93	4
2084	58	1
498	52	4
569	61	5
2024	7	4
1479	142	4
2345	95	5
1915	142	5
532	157	2
354	17	3
1267	102	4
2937	185	4
1961	135	4
1683	197	2
1678	148	1
303	33	3
1299	165	3
304	116	5
1909	175	2
2120	89	2
526	200	5
2259	164	6
2408	47	4
529	111	3
2060	15	4
509	133	1
627	78	1
675	42	2
1322	182	4
924	89	3
2126	73	3
324	65	4
805	163	3
2257	71	3
513	161	2
1241	158	6
2186	24	3
2059	165	4
691	152	1
2379	40	4
702	169	3
2558	185	5
2479	87	5
2309	11	3
117	21	6
187	165	5
2363	68	1
2668	54	2
2344	107	4
2532	164	7
125	128	3
2569	140	3
1187	165	6
1238	124	3
1004	176	1
1664	77	1
1858	19	4
2821	16	2
648	113	4
1703	124	4
1903	53	2
1394	156	2
589	81	6
2943	82	1
1415	103	4
536	195	3
1518	132	5
2301	28	5
1308	62	5
1911	32	5
1096	116	6
1016	37	5
397	13	2
1189	99	4
2521	108	3
1017	41	5
1342	148	2
2954	81	7
778	196	4
653	128	4
2109	120	1
2043	79	2
2038	6	1
369	101	2
2071	118	4
987	56	4
2390	91	4
200	13	3
1153	127	2
2448	168	2
2755	121	5
1171	138	1
34	28	6
1766	35	2
1084	187	5
1499	196	5
1652	94	3
186	103	5
210	146	1
2302	50	3
1485	142	6
1183	19	5
1583	130	5
1845	196	6
2253	72	1
2553	175	3
2503	31	3
528	25	3
1614	96	5
1389	143	2
1498	194	2
591	51	2
2468	131	1
1645	129	4
165	12	3
160	36	4
2923	86	2
1941	133	2
1872	39	3
2484	132	6
573	84	2
2512	82	2
666	101	3
2526	190	5
1226	152	2
1378	130	6
2088	137	1
2007	182	5
2306	77	2
1946	5	2
1509	85	3
2760	29	4
1707	150	3
1261	186	2
2819	162	2
110	153	5
1944	68	2
2686	199	5
2370	148	3
933	185	6
211	150	4
1968	44	1
2148	162	3
2954	159	2
1558	38	4
2789	63	1
130	147	4
2870	29	5
782	5	3
1807	81	8
1716	39	4
1692	177	3
836	106	2
2056	199	6
2505	121	6
2980	16	3
2891	36	5
2125	54	3
2298	84	3
2713	123	3
2153	97	2
1286	45	5
1883	137	2
1403	140	4
1452	174	6
2953	175	4
2635	178	3
1083	157	3
1984	50	4
1010	72	2
2286	77	3
922	77	4
1184	181	3
850	177	4
2888	126	2
1299	123	4
1429	144	3
2956	71	4
1179	32	6
2349	174	7
2225	98	3
1617	89	4
600	75	4
173	74	4
2926	21	7
1419	114	3
2687	66	3
1963	55	3
828	138	2
1111	144	4
2852	70	3
563	28	7
2522	190	6
2404	62	6
994	13	4
2744	136	5
925	164	8
954	14	5
411	106	3
1353	184	1
1935	26	4
2791	198	4
564	2	2
2255	41	6
1667	168	3
1949	123	5
2665	52	5
1177	83	6
1170	166	6
243	197	3
367	167	5
2352	60	2
2192	190	7
2962	10	4
718	107	5
721	10	5
1627	127	3
764	192	3
1186	10	6
38	77	5
2327	155	6
440	86	3
1166	117	2
2627	140	5
2148	127	4
550	130	7
1918	70	4
790	29	6
1355	42	3
2995	118	5
2656	66	4
2944	48	2
58	189	2
1381	76	1
2326	173	1
792	45	6
2503	164	9
1661	110	6
2111	84	4
356	103	6
2742	25	4
757	36	6
1956	83	7
1017	2	3
1069	99	5
965	115	2
1094	85	4
1237	150	5
2961	147	5
47	67	1
2678	93	5
2838	61	6
255	171	4
485	120	2
1257	41	7
1661	176	2
2059	181	4
1274	177	5
481	164	10
1209	95	6
2518	57	3
898	35	3
1959	40	5
1864	192	4
2482	96	6
1704	180	3
2250	121	7
2202	171	5
895	196	7
1014	175	5
2441	21	8
2153	115	3
2164	181	5
1482	20	5
2311	29	7
253	141	2
2071	52	6
2346	138	3
614	43	2
1344	134	3
1810	30	4
2787	53	3
2937	150	6
2003	24	4
2091	115	4
228	117	3
541	132	7
1702	117	4
2310	15	5
2289	119	4
2756	79	3
2963	6	2
1622	66	5
13	191	2
893	149	1
300	12	4
1736	89	5
2869	17	4
2217	16	4
283	121	8
130	74	5
1675	47	5
555	197	4
2628	187	6
2646	108	4
1534	98	4
1838	97	3
1539	21	9
2797	170	2
2209	35	4
2677	90	4
486	46	1
2201	101	4
2167	33	4
2982	58	2
15	194	3
94	77	6
1897	173	2
2946	140	6
1738	137	3
1554	59	2
1014	118	6
1418	40	6
1130	49	2
2970	196	8
463	9	3
2705	108	5
2519	197	5
65	62	7
845	18	3
414	153	6
138	115	5
2449	173	3
2881	13	5
1003	190	8
182	103	7
1798	60	3
2211	56	5
232	36	7
2064	75	5
960	188	2
2360	82	3
2366	154	1
2755	83	8
971	78	2
587	170	3
2136	57	4
1694	77	7
1128	16	5
2281	152	3
718	161	3
2781	110	7
2277	127	5
193	89	6
2636	172	2
1562	135	5
1306	179	2
1706	105	1
612	77	8
1542	48	3
2204	122	4
988	58	3
1232	182	6
592	119	5
237	144	5
1691	107	6
2283	136	6
550	100	5
995	66	6
833	85	5
2649	21	10
1843	95	7
379	138	4
2968	49	3
212	69	3
1545	173	4
2478	155	7
162	19	6
771	195	4
2407	186	3
2751	144	6
889	123	6
856	86	4
1242	4	2
868	49	4
481	192	5
1962	63	2
2850	155	8
2883	53	4
1625	62	8
2262	83	9
1160	98	5
1910	137	4
2658	92	3
1264	67	2
1474	132	8
2037	120	3
404	185	7
1924	195	5
1312	53	5
1519	81	9
1696	12	5
2305	57	5
598	5	4
1069	142	7
2393	149	2
2950	107	7
1210	40	7
804	85	6
943	98	6
2334	63	3
2046	141	3
2682	176	3
1383	66	7
2002	186	4
2629	190	9
2010	118	7
690	188	3
1443	44	2
574	185	8
2239	126	3
754	139	1
2629	16	6
2147	9	4
305	172	3
199	196	9
27	106	4
564	162	4
948	18	4
2897	39	5
38	56	6
2072	117	5
1529	16	7
2531	164	11
2732	158	7
1980	169	4
1999	5	5
28	137	5
2260	106	5
49	5	6
2169	185	9
1126	138	5
1175	5	7
2058	179	3
2761	111	4
735	28	8
395	135	6
610	62	9
787	159	3
2157	65	5
1452	69	4
1626	21	11
1529	104	3
1881	145	2
997	179	4
926	77	9
2802	21	12
2678	167	6
130	24	5
1661	98	7
1545	142	8
1950	15	6
2609	3	1
2879	44	3
339	128	5
1778	166	7
1357	145	3
391	136	7
175	59	3
866	178	4
2322	122	5
1111	12	6
305	176	4
1149	140	7
2309	169	5
135	46	2
1289	5	8
849	151	1
591	193	4
2920	102	5
316	77	10
666	145	4
985	146	2
1594	174	8
2215	85	7
1573	194	4
574	177	6
2967	21	13
2052	191	3
1417	14	6
401	112	5
951	20	6
1396	155	9
2515	153	7
1625	199	7
1337	8	4
2598	70	5
1846	126	4
935	92	4
2266	97	4
1769	48	4
2785	150	7
2707	98	8
352	198	5
2534	76	2
1010	183	4
302	22	5
1098	40	8
1557	183	5
2597	40	9
1596	82	4
1478	28	9
375	2	4
1263	114	4
1475	195	6
1105	27	2
543	23	2
768	111	5
1839	143	3
2273	132	9
1672	27	3
108	23	3
1450	142	9
382	153	8
2450	84	5
1578	4	3
1196	106	6
1589	200	6
347	186	5
2292	63	4
2343	134	4
695	176	5
1560	44	4
569	69	5
1234	69	6
2020	38	5
260	43	3
1781	71	5
1725	77	11
1984	20	7
1480	65	6
1011	185	10
2561	127	6
2433	158	8
801	118	8
439	35	5
1248	2	5
1621	86	5
2541	98	9
1350	113	5
1372	111	6
2667	153	9
558	77	12
1314	155	10
2848	52	7
1963	81	10
728	102	6
1308	75	6
2847	163	4
2012	148	4
993	84	6
1541	72	3
1610	94	4
467	145	5
819	152	4
2235	47	6
2793	197	6
2254	7	5
2979	119	6
2902	54	4
1796	75	7
2838	18	5
1676	173	5
2046	36	8
2595	78	3
992	65	7
2698	40	10
2930	109	3
1545	19	7
1840	154	2
1963	150	8
1642	137	6
2076	178	5
1714	140	8
151	93	6
2874	138	6
2433	164	12
349	28	10
\.


--
-- TOC entry 5102 (class 0 OID 32840)
-- Dependencies: 220
-- Data for Name: publisher; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.publisher (publisher_id, name, founded_year, country, website) FROM stdin;
1	Marvel Comics	1939	USA	https://www.marvelcomics.com
2	DC Comics	1934	USA	https://www.dccomics.com
3	Image Comics	1992	USA	https://www.imagecomics.com
4	Dark Horse Comics	1986	USA	https://www.darkhorsecomics.com
5	IDW Publishing	1999	USA	https://www.idwpublishing.com
6	BOOM! Studios	2005	USA	https://www.boom!studios.com
7	Dynamite Entertainment	2004	USA	https://www.dynamiteentertainment.com
8	Valiant Comics	1989	USA	https://www.valiantcomics.com
9	Archie Comics	1939	USA	https://www.archiecomics.com
10	Fantagraphics Books	1976	USA	https://www.fantagraphicsbooks.com
11	Drawn and Quarterly	1990	Canada	https://www.drawnandquarterly.com
12	Oni Press	1997	USA	https://www.onipress.com
13	Vault Comics	2016	USA	https://www.vaultcomics.com
14	Aftershock Comics	2015	USA	https://www.aftershockcomics.com
15	Titan Comics	2010	UK	https://www.titancomics.com
16	2000 AD	1977	UK	https://www.2000ad.com
17	Rebellion Publishing	1992	UK	https://www.rebellionpublishing.com
18	Humanoids	1969	France	https://www.humanoids.com
19	Kodansha Comics	1909	Japan	https://www.kodanshacomics.com
20	Viz Media	1986	USA	https://www.vizmedia.com
\.


--
-- TOC entry 5104 (class 0 OID 32851)
-- Dependencies: 222
-- Data for Name: series; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.series (series_id, publisher_id, title, start_year, end_year, genre, description) FROM stdin;
2	3	The Incredible Guardians	2013	2014	Fantasy	In a world gone mad, only outlaws can restore order.
3	18	The Astonishing Watch	1941	1964	Crime	In a world gone mad, only outlaws can restore order.
4	6	The Cosmic Strike	1973	1974	Humor	A new generation must carry the weight of a broken legacy.
5	11	The Secret Order	1957	\N	Horror	One hero stands alone against an empire of darkness.
6	9	The Shadow Legion	1983	2003	Anthology	A team of unlikely heroes must unite to prevent catastrophe.
7	3	The Cosmic Crusaders	1953	1966	Romance	The line between hero and villain has never been thinner.
8	3	The Immortal Corps	2011	\N	Superhero	In a world gone mad, only outlaws can restore order.
9	9	The Deadly Guardians	1967	1980	Dark Superhero	Ancient evil returns, and the old ways may be the only hope.
10	9	The Dark Corps	1983	\N	Humor	One hero stands alone against an empire of darkness.
11	15	The Immortal Syndicate	2006	2012	Crime	The line between hero and villain has never been thinner.
12	2	The Incredible Division	1979	2004	Fantasy	A team of unlikely heroes must unite to prevent catastrophe.
13	19	The Secret Unit	1972	\N	Humor	Ancient evil returns, and the old ways may be the only hope.
14	15	The Last Assembly	1988	2009	Science Fiction	The line between hero and villain has never been thinner.
15	19	The Savage Division	2009	2021	Crime	The final war begins, and no one will emerge unchanged.
16	17	The Shadow Corps	1966	1971	Dark Superhero	One hero stands alone against an empire of darkness.
17	14	The Uncanny Legion	1957	1983	Western	One hero stands alone against an empire of darkness.
18	9	The Shadow Unit	2014	2023	Romance	A team of unlikely heroes must unite to prevent catastrophe.
19	4	The Spectacular Crusaders	1972	1983	Action	A new generation must carry the weight of a broken legacy.
20	9	The Dark Collective	1938	1967	Romance	Long-buried secrets threaten to destroy everything they built.
21	17	The Astonishing Legion	2018	\N	Western	In a world gone mad, only outlaws can restore order.
22	17	The Savage Corps	1958	1983	Superhero	The final war begins, and no one will emerge unchanged.
23	12	The Secret Assembly	1940	\N	Anthology	The line between hero and villain has never been thinner.
24	3	The Eternal Defenders	1968	1971	Humor	When gods fall, mortals must rise to fill the void.
25	16	The Mighty Crusaders	1954	\N	Romance	Long-buried secrets threaten to destroy everything they built.
26	18	The Invincible Vanguard	2015	2019	Anthology	In a world gone mad, only outlaws can restore order.
27	15	The Deadly Unit	1985	2002	Horror	In a world gone mad, only outlaws can restore order.
28	18	The Eternal Guardians	1981	\N	Fantasy	The final war begins, and no one will emerge unchanged.
29	8	The Eternal Warriors	1947	1949	Horror	A team of unlikely heroes must unite to prevent catastrophe.
30	16	The Secret Guardians	2003	\N	Fantasy	Two enemies discover they share a common enemy.
31	16	The Savage Strike	2011	2024	Anthology	A new generation must carry the weight of a broken legacy.
32	14	The Last Legion	1950	1962	Crime	When gods fall, mortals must rise to fill the void.
33	8	The Uncanny Unit	1981	1985	Fantasy	In a world gone mad, only outlaws can restore order.
34	15	The Incredible Collective	1955	1964	Fantasy	One hero stands alone against an empire of darkness.
35	8	The Spectacular Defenders	2007	2010	Science Fiction	A new generation must carry the weight of a broken legacy.
36	2	The Blazing Assembly	1965	1994	Science Fiction	A new generation must carry the weight of a broken legacy.
37	15	The Amazing Unit	1971	1997	Action	A new generation must carry the weight of a broken legacy.
38	7	The Incredible Assembly	1957	\N	Superhero	The final war begins, and no one will emerge unchanged.
39	19	The Incredible Defenders	1978	\N	Dark Superhero	Two enemies discover they share a common enemy.
40	6	The Astonishing Syndicate	1945	1948	Horror	The final war begins, and no one will emerge unchanged.
41	19	The Mighty Division	1989	\N	Fantasy	The final war begins, and no one will emerge unchanged.
42	19	The Immortal Defenders	2017	\N	Western	Two enemies discover they share a common enemy.
43	5	The Last Force	1968	\N	War	The line between hero and villain has never been thinner.
44	20	The Cosmic Force	1947	\N	Western	One hero stands alone against an empire of darkness.
45	12	The Last Vanguard	1971	\N	Horror	In a world gone mad, only outlaws can restore order.
46	10	The Hidden Circle	1958	1976	Western	Two enemies discover they share a common enemy.
47	5	The Amazing Crusaders	1976	1980	Action	One hero stands alone against an empire of darkness.
48	11	The Savage Order	1974	1997	Fantasy	The line between hero and villain has never been thinner.
49	2	The Astonishing Assembly	1970	1998	Horror	A new generation must carry the weight of a broken legacy.
50	5	The Invincible Defenders	1938	\N	War	The line between hero and villain has never been thinner.
51	3	The Incredible Patrol	2009	\N	Humor	Long-buried secrets threaten to destroy everything they built.
52	5	The Hidden Strike	2008	\N	Superhero	The line between hero and villain has never been thinner.
53	8	The Hidden Defenders	1983	\N	War	One hero stands alone against an empire of darkness.
54	5	The Hidden Crusaders	1990	2014	Fantasy	Long-buried secrets threaten to destroy everything they built.
55	11	The Dark Patrol	1941	\N	Anthology	A new generation must carry the weight of a broken legacy.
56	13	The Eternal Order	1958	1962	Superhero	When gods fall, mortals must rise to fill the void.
57	8	The Eternal Alliance	1996	\N	Fantasy	A team of unlikely heroes must unite to prevent catastrophe.
58	3	The Last Unit	1980	\N	Anthology	The line between hero and villain has never been thinner.
59	18	The Hidden Vanguard	1989	2016	Mystery	A team of unlikely heroes must unite to prevent catastrophe.
60	2	The Spectacular Order	1960	1969	Horror	The final war begins, and no one will emerge unchanged.
61	4	The Iron Corps	1978	1995	Crime	The final war begins, and no one will emerge unchanged.
62	17	The Last Order	1943	1944	Anthology	Two enemies discover they share a common enemy.
63	11	The Last Corps	1993	\N	Western	Ancient evil returns, and the old ways may be the only hope.
64	14	The Spectacular Circle	2002	\N	Mystery	A new generation must carry the weight of a broken legacy.
65	13	The Deadly Crusaders	1954	\N	War	Long-buried secrets threaten to destroy everything they built.
66	1	The Immortal Strike	1976	2003	Action	The line between hero and villain has never been thinner.
67	15	The Last Patrol	2012	2018	Dark Superhero	When gods fall, mortals must rise to fill the void.
68	20	The Blazing Syndicate	1948	\N	Mystery	One hero stands alone against an empire of darkness.
69	1	The Eternal Circle	1966	1971	Superhero	In a world gone mad, only outlaws can restore order.
70	19	The Blazing Watch	1947	1976	Fantasy	A new generation must carry the weight of a broken legacy.
71	1	The Blazing Unit	1969	\N	Anthology	One hero stands alone against an empire of darkness.
72	17	The Iron Division	1960	1983	Dark Superhero	A team of unlikely heroes must unite to prevent catastrophe.
73	17	The Spectacular Collective	1955	1977	Romance	The final war begins, and no one will emerge unchanged.
74	18	The Secret Collective	2016	2023	Dark Superhero	Long-buried secrets threaten to destroy everything they built.
75	9	The Blazing Collective	1971	1998	Anthology	Two enemies discover they share a common enemy.
76	10	The Blazing Division	1973	1996	Fantasy	The line between hero and villain has never been thinner.
77	5	The Secret Force	2007	\N	Fantasy	A new generation must carry the weight of a broken legacy.
78	18	The Savage Alliance	1946	1957	Dark Superhero	A new generation must carry the weight of a broken legacy.
79	19	The Uncanny Alliance	1991	\N	Humor	A team of unlikely heroes must unite to prevent catastrophe.
80	12	The Fearless Unit	1999	\N	Action	A new generation must carry the weight of a broken legacy.
81	16	The Iron Crusaders	2007	2015	Fantasy	The line between hero and villain has never been thinner.
82	13	The Iron Assembly	1941	\N	Humor	Long-buried secrets threaten to destroy everything they built.
83	19	The Cosmic Brotherhood	2017	2021	Western	A team of unlikely heroes must unite to prevent catastrophe.
84	2	The Mighty Patrol	1955	1961	Action	A new generation must carry the weight of a broken legacy.
85	13	The Secret Alliance	1996	\N	Action	A new generation must carry the weight of a broken legacy.
86	18	The Invincible Guardians	1998	\N	Superhero	Ancient evil returns, and the old ways may be the only hope.
87	1	The Uncanny Warriors	1969	\N	Western	Long-buried secrets threaten to destroy everything they built.
88	7	The Eternal Brotherhood	1998	2017	Dark Superhero	The line between hero and villain has never been thinner.
89	6	The Hidden Syndicate	2015	2017	Action	One hero stands alone against an empire of darkness.
90	13	The Fearless Warriors	1977	2007	Crime	In a world gone mad, only outlaws can restore order.
91	10	The Mighty Strike	2018	\N	War	The final war begins, and no one will emerge unchanged.
92	14	The Spectacular Strike	1943	\N	War	Ancient evil returns, and the old ways may be the only hope.
93	14	The Mighty Vanguard	2020	\N	Dark Superhero	One hero stands alone against an empire of darkness.
94	20	The Iron Syndicate	2004	2013	Anthology	Two enemies discover they share a common enemy.
95	8	The Iron Strike	1972	\N	Horror	The line between hero and villain has never been thinner.
96	13	The Cosmic Division	1997	2019	Mystery	A team of unlikely heroes must unite to prevent catastrophe.
97	9	The Blazing Force	1961	1973	Mystery	The line between hero and villain has never been thinner.
98	7	The Immortal Order	2009	\N	Horror	In a world gone mad, only outlaws can restore order.
99	13	The Cosmic Warriors	1949	\N	Humor	In a world gone mad, only outlaws can restore order.
100	12	The Deadly Strike	1985	2002	Crime	Two enemies discover they share a common enemy.
101	9	The Secret Corps	1996	\N	Fantasy	One hero stands alone against an empire of darkness.
102	19	The Dark Alliance	1965	1974	Anthology	Two enemies discover they share a common enemy.
103	8	The Immortal Circle	1950	1960	Mystery	Long-buried secrets threaten to destroy everything they built.
104	2	The Deadly Warriors	2006	\N	Superhero	Two enemies discover they share a common enemy.
105	4	The Deadly Brotherhood	2019	2023	Superhero	The final war begins, and no one will emerge unchanged.
106	2	The Deadly Assembly	1999	2005	Action	When gods fall, mortals must rise to fill the void.
107	2	The Spectacular Guardians	1989	2008	Science Fiction	Long-buried secrets threaten to destroy everything they built.
108	18	The Fearless Circle	1948	1952	Anthology	A new generation must carry the weight of a broken legacy.
109	17	The Immortal Watch	2017	\N	Crime	When gods fall, mortals must rise to fill the void.
110	19	The Cosmic Circle	2013	2018	Western	A team of unlikely heroes must unite to prevent catastrophe.
111	3	The Immortal Legion	1964	1973	Science Fiction	In a world gone mad, only outlaws can restore order.
112	14	The Dark Crusaders	1947	\N	Dark Superhero	The final war begins, and no one will emerge unchanged.
113	10	The Blazing Circle	1942	\N	Humor	When gods fall, mortals must rise to fill the void.
114	8	The Invincible Strike	1963	1981	War	Long-buried secrets threaten to destroy everything they built.
115	10	The Invincible Brotherhood	1947	\N	Western	The final war begins, and no one will emerge unchanged.
116	13	The Deadly Collective	1953	1963	Action	Two enemies discover they share a common enemy.
117	14	The Cosmic Guardians	2014	\N	Humor	Ancient evil returns, and the old ways may be the only hope.
118	19	The Amazing Guardians	1967	1994	Western	A team of unlikely heroes must unite to prevent catastrophe.
119	9	The Uncanny Syndicate	1998	2013	Science Fiction	The final war begins, and no one will emerge unchanged.
120	4	The Mighty Assembly	1982	1993	Science Fiction	Ancient evil returns, and the old ways may be the only hope.
121	1	The Secret Legion	1989	2016	War	Two enemies discover they share a common enemy.
122	12	The Cosmic Patrol	1944	\N	Western	When gods fall, mortals must rise to fill the void.
123	5	The Cosmic Defenders	1964	\N	Action	When gods fall, mortals must rise to fill the void.
124	8	The Blazing Legion	1941	1961	Humor	Long-buried secrets threaten to destroy everything they built.
125	4	The Iron Guardians	1966	1996	Dark Superhero	One hero stands alone against an empire of darkness.
126	14	The Savage Assembly	1975	1984	Dark Superhero	When gods fall, mortals must rise to fill the void.
127	7	The Eternal Collective	2008	\N	Western	Two enemies discover they share a common enemy.
128	14	The Savage Guardians	1973	2001	Mystery	Two enemies discover they share a common enemy.
129	19	The Invincible Warriors	1974	2001	Western	When gods fall, mortals must rise to fill the void.
130	18	The Savage Collective	2006	2017	Anthology	Two enemies discover they share a common enemy.
131	8	The Shadow Collective	1979	2002	Western	A new generation must carry the weight of a broken legacy.
132	16	The Eternal Patrol	1943	\N	Humor	A new generation must carry the weight of a broken legacy.
133	17	The Shadow Brotherhood	2001	2006	Western	Ancient evil returns, and the old ways may be the only hope.
134	5	The Spectacular Vanguard	1996	\N	Crime	Long-buried secrets threaten to destroy everything they built.
135	3	The Invincible Force	2017	2023	Mystery	Two enemies discover they share a common enemy.
136	18	The Shadow Force	2018	2022	Superhero	The final war begins, and no one will emerge unchanged.
137	4	The Deadly Division	1949	1953	Dark Superhero	Long-buried secrets threaten to destroy everything they built.
138	12	The Uncanny Force	1945	\N	Crime	Long-buried secrets threaten to destroy everything they built.
139	6	The Eternal Vanguard	1990	2016	Science Fiction	Long-buried secrets threaten to destroy everything they built.
140	16	The Mighty Watch	1986	1994	Western	Long-buried secrets threaten to destroy everything they built.
141	15	The Invincible Collective	1970	1999	Action	Two enemies discover they share a common enemy.
142	10	The Dark Guardians	1994	2013	War	A new generation must carry the weight of a broken legacy.
143	8	The Deadly Alliance	1987	1991	Crime	The final war begins, and no one will emerge unchanged.
144	13	The Deadly Circle	1940	1962	Action	A team of unlikely heroes must unite to prevent catastrophe.
145	8	The Fearless Defenders	2015	2020	Western	Ancient evil returns, and the old ways may be the only hope.
146	15	The Savage Legion	2018	2021	Superhero	The final war begins, and no one will emerge unchanged.
147	14	The Hidden Brotherhood	1949	1960	Science Fiction	In a world gone mad, only outlaws can restore order.
148	9	The Savage Crusaders	1984	2014	Science Fiction	The line between hero and villain has never been thinner.
149	13	The Shadow Crusaders	1984	\N	Superhero	The line between hero and villain has never been thinner.
150	9	The Incredible Legion	1996	\N	Western	A new generation must carry the weight of a broken legacy.
151	18	The Hidden Legion	1967	1987	Mystery	The final war begins, and no one will emerge unchanged.
152	2	The Iron Legion	1955	\N	Action	When gods fall, mortals must rise to fill the void.
153	13	The Spectacular Legion	1968	1973	Dark Superhero	Ancient evil returns, and the old ways may be the only hope.
154	16	The Fearless Brotherhood	1991	2018	Western	A new generation must carry the weight of a broken legacy.
155	12	The Hidden Alliance	1994	2002	Horror	Ancient evil returns, and the old ways may be the only hope.
156	7	The Incredible Corps	1945	\N	Horror	When gods fall, mortals must rise to fill the void.
157	2	The Mighty Alliance	2020	2021	Anthology	Ancient evil returns, and the old ways may be the only hope.
158	7	The Fearless Alliance	1946	1964	Western	In a world gone mad, only outlaws can restore order.
159	1	The Eternal Force	1956	1976	Action	Long-buried secrets threaten to destroy everything they built.
160	5	The Invincible Syndicate	1952	1953	Superhero	Ancient evil returns, and the old ways may be the only hope.
161	9	The Eternal Strike	1979	\N	Superhero	Long-buried secrets threaten to destroy everything they built.
162	15	The Iron Vanguard	1952	1968	Anthology	Ancient evil returns, and the old ways may be the only hope.
163	20	The Astonishing Strike	1951	1959	Superhero	Two enemies discover they share a common enemy.
164	4	The Amazing Defenders	1999	2013	Dark Superhero	When gods fall, mortals must rise to fill the void.
165	5	The Mighty Guardians	1979	1982	Action	The final war begins, and no one will emerge unchanged.
166	20	The Fearless Crusaders	1979	\N	Romance	The line between hero and villain has never been thinner.
167	18	The Cosmic Vanguard	2015	2017	Humor	In a world gone mad, only outlaws can restore order.
168	15	The Iron Collective	1967	1994	Crime	A new generation must carry the weight of a broken legacy.
169	9	The Spectacular Force	1992	\N	Mystery	Long-buried secrets threaten to destroy everything they built.
170	14	The Blazing Guardians	1949	1952	Horror	Ancient evil returns, and the old ways may be the only hope.
171	4	The Uncanny Strike	2009	2020	Crime	Ancient evil returns, and the old ways may be the only hope.
172	4	The Iron Defenders	1974	1986	Western	Two enemies discover they share a common enemy.
173	4	The Last Brotherhood	1999	\N	Mystery	Two enemies discover they share a common enemy.
174	20	The Incredible Watch	2016	2017	War	The line between hero and villain has never been thinner.
175	11	The Amazing Syndicate	1972	1982	Mystery	A team of unlikely heroes must unite to prevent catastrophe.
176	5	The Dark Brotherhood	2010	2012	Humor	A team of unlikely heroes must unite to prevent catastrophe.
177	11	The Secret Syndicate	1985	\N	Anthology	The final war begins, and no one will emerge unchanged.
178	20	The Immortal Guardians	1944	\N	Superhero	One hero stands alone against an empire of darkness.
179	17	The Immortal Collective	1991	\N	Horror	Ancient evil returns, and the old ways may be the only hope.
180	13	The Blazing Vanguard	1977	\N	Western	A team of unlikely heroes must unite to prevent catastrophe.
181	5	The Amazing Alliance	1976	2001	Anthology	The line between hero and villain has never been thinner.
182	14	The Deadly Force	1953	\N	Science Fiction	Long-buried secrets threaten to destroy everything they built.
183	3	The Mighty Unit	1943	1958	Mystery	The final war begins, and no one will emerge unchanged.
184	1	The Shadow Patrol	1975	\N	Mystery	Long-buried secrets threaten to destroy everything they built.
185	14	The Hidden Guardians	1993	2001	Western	A new generation must carry the weight of a broken legacy.
186	11	The Astonishing Guardians	1988	2012	Fantasy	Ancient evil returns, and the old ways may be the only hope.
187	12	The Astonishing Vanguard	1962	1974	Humor	Long-buried secrets threaten to destroy everything they built.
188	6	The Eternal Legion	1956	\N	Western	Long-buried secrets threaten to destroy everything they built.
189	19	The Mighty Syndicate	2018	2023	Dark Superhero	The final war begins, and no one will emerge unchanged.
190	15	The Immortal Force	2018	\N	Horror	When gods fall, mortals must rise to fill the void.
191	15	The Uncanny Corps	2002	\N	Dark Superhero	A team of unlikely heroes must unite to prevent catastrophe.
192	2	The Immortal Vanguard	1987	2005	Dark Superhero	The final war begins, and no one will emerge unchanged.
193	2	The Immortal Assembly	2002	\N	Dark Superhero	One hero stands alone against an empire of darkness.
194	17	The Uncanny Division	1994	2011	Western	Long-buried secrets threaten to destroy everything they built.
195	11	The Hidden Corps	1974	\N	War	The final war begins, and no one will emerge unchanged.
196	10	The Mighty Force	1950	1963	Action	The final war begins, and no one will emerge unchanged.
197	12	The Savage Force	1948	1953	Action	A new generation must carry the weight of a broken legacy.
198	13	The Savage Watch	1948	\N	War	Ancient evil returns, and the old ways may be the only hope.
199	17	The Savage Vanguard	1949	1963	Mystery	A team of unlikely heroes must unite to prevent catastrophe.
200	10	The Last Division	1955	\N	Anthology	One hero stands alone against an empire of darkness.
201	11	The Astonishing Crusaders	2005	\N	Anthology	The final war begins, and no one will emerge unchanged.
202	15	The Dark Syndicate	2017	2019	Superhero	A new generation must carry the weight of a broken legacy.
203	15	The Hidden Division	1994	2019	Fantasy	Two enemies discover they share a common enemy.
204	15	The Blazing Alliance	1985	2004	Dark Superhero	The line between hero and villain has never been thinner.
205	7	The Shadow Vanguard	2005	2011	Anthology	The final war begins, and no one will emerge unchanged.
206	17	The Uncanny Assembly	1985	1989	Horror	The line between hero and villain has never been thinner.
207	8	The Astonishing Brotherhood	1993	\N	Dark Superhero	Ancient evil returns, and the old ways may be the only hope.
208	12	The Amazing Patrol	1944	\N	Fantasy	A new generation must carry the weight of a broken legacy.
209	4	The Mighty Corps	1966	\N	Humor	Ancient evil returns, and the old ways may be the only hope.
210	16	The Savage Brotherhood	1942	\N	Humor	Long-buried secrets threaten to destroy everything they built.
211	7	The Immortal Warriors	1948	\N	Science Fiction	Two enemies discover they share a common enemy.
212	20	The Deadly Legion	1944	\N	Dark Superhero	One hero stands alone against an empire of darkness.
213	19	The Spectacular Assembly	2014	2023	Fantasy	Long-buried secrets threaten to destroy everything they built.
214	19	The Deadly Patrol	1938	1946	Crime	Long-buried secrets threaten to destroy everything they built.
215	13	The Incredible Warriors	1987	1989	Mystery	The line between hero and villain has never been thinner.
216	4	The Amazing Corps	1946	\N	Anthology	The final war begins, and no one will emerge unchanged.
217	11	The Secret Brotherhood	1943	\N	War	Long-buried secrets threaten to destroy everything they built.
218	5	The Cosmic Assembly	2018	\N	Horror	When gods fall, mortals must rise to fill the void.
219	7	The Uncanny Circle	1963	\N	Superhero	Ancient evil returns, and the old ways may be the only hope.
220	16	The Deadly Vanguard	1988	2006	Action	A team of unlikely heroes must unite to prevent catastrophe.
221	11	The Last Circle	1983	1985	Action	One hero stands alone against an empire of darkness.
222	13	The Hidden Patrol	1989	2018	Mystery	Long-buried secrets threaten to destroy everything they built.
223	4	The Iron Watch	1961	1972	Horror	Ancient evil returns, and the old ways may be the only hope.
224	15	The Cosmic Watch	1992	\N	Mystery	When gods fall, mortals must rise to fill the void.
225	2	The Immortal Patrol	1973	1999	Horror	A new generation must carry the weight of a broken legacy.
226	15	The Dark Warriors	1956	1978	Superhero	Long-buried secrets threaten to destroy everything they built.
227	15	The Shadow Strike	1942	1964	Mystery	Ancient evil returns, and the old ways may be the only hope.
228	9	The Astonishing Corps	1988	\N	Fantasy	One hero stands alone against an empire of darkness.
229	7	The Last Watch	1974	1990	Horror	Long-buried secrets threaten to destroy everything they built.
230	3	The Mighty Collective	1960	1975	Anthology	Ancient evil returns, and the old ways may be the only hope.
231	6	The Incredible Crusaders	1975	2003	Humor	Long-buried secrets threaten to destroy everything they built.
232	19	The Eternal Assembly	1941	\N	Mystery	When gods fall, mortals must rise to fill the void.
233	10	The Incredible Brotherhood	2016	2018	Crime	When gods fall, mortals must rise to fill the void.
234	5	The Astonishing Patrol	1990	1993	Mystery	One hero stands alone against an empire of darkness.
235	18	The Cosmic Collective	2004	\N	War	The final war begins, and no one will emerge unchanged.
236	8	The Deadly Syndicate	1958	\N	Mystery	Two enemies discover they share a common enemy.
237	5	The Invincible Alliance	2019	2022	War	The line between hero and villain has never been thinner.
238	19	The Immortal Crusaders	1949	1955	Western	Long-buried secrets threaten to destroy everything they built.
239	19	The Dark Watch	2015	\N	Superhero	A team of unlikely heroes must unite to prevent catastrophe.
240	7	The Mighty Defenders	2020	2023	Anthology	The final war begins, and no one will emerge unchanged.
241	10	The Amazing Assembly	2018	2024	Dark Superhero	In a world gone mad, only outlaws can restore order.
242	2	The Shadow Circle	1996	\N	Science Fiction	When gods fall, mortals must rise to fill the void.
243	11	The Cosmic Alliance	1981	1992	Humor	Ancient evil returns, and the old ways may be the only hope.
244	15	The Secret Division	1997	\N	Fantasy	Long-buried secrets threaten to destroy everything they built.
245	11	The Eternal Syndicate	1979	2003	Fantasy	Long-buried secrets threaten to destroy everything they built.
246	10	The Last Strike	1983	\N	Dark Superhero	The final war begins, and no one will emerge unchanged.
247	12	The Spectacular Patrol	1955	1979	Anthology	A new generation must carry the weight of a broken legacy.
248	18	The Shadow Defenders	2010	2016	Action	One hero stands alone against an empire of darkness.
249	4	The Invincible Watch	2016	\N	Crime	Ancient evil returns, and the old ways may be the only hope.
250	20	The Secret Crusaders	1984	1991	Romance	A new generation must carry the weight of a broken legacy.
251	11	The Astonishing Defenders	1943	\N	Anthology	When gods fall, mortals must rise to fill the void.
252	5	The Astonishing Collective	1957	1974	Mystery	The final war begins, and no one will emerge unchanged.
253	17	The Shadow Watch	1976	1993	Romance	When gods fall, mortals must rise to fill the void.
254	4	The Blazing Warriors	1985	\N	Crime	The final war begins, and no one will emerge unchanged.
255	17	The Fearless Division	1944	1950	War	The final war begins, and no one will emerge unchanged.
256	11	The Fearless Legion	1962	\N	Crime	Long-buried secrets threaten to destroy everything they built.
257	16	The Iron Alliance	1990	2010	Humor	A team of unlikely heroes must unite to prevent catastrophe.
258	17	The Last Crusaders	1979	1995	Crime	Ancient evil returns, and the old ways may be the only hope.
259	9	The Incredible Force	2007	\N	Western	When gods fall, mortals must rise to fill the void.
260	10	The Invincible Crusaders	1976	\N	Anthology	The line between hero and villain has never been thinner.
261	13	The Invincible Circle	1953	1971	Crime	Ancient evil returns, and the old ways may be the only hope.
262	3	The Savage Circle	1943	\N	Mystery	When gods fall, mortals must rise to fill the void.
263	18	The Invincible Assembly	1965	\N	Action	Two enemies discover they share a common enemy.
264	2	The Spectacular Watch	2013	\N	War	Two enemies discover they share a common enemy.
265	11	The Eternal Division	1944	\N	Humor	When gods fall, mortals must rise to fill the void.
266	6	The Spectacular Brotherhood	1938	1968	Crime	When gods fall, mortals must rise to fill the void.
267	18	The Deadly Defenders	1949	1957	Humor	A team of unlikely heroes must unite to prevent catastrophe.
268	10	The Dark Defenders	1988	1994	Superhero	A team of unlikely heroes must unite to prevent catastrophe.
269	17	The Secret Circle	1996	2014	Dark Superhero	Long-buried secrets threaten to destroy everything they built.
270	7	The Amazing Force	1975	2000	Science Fiction	The final war begins, and no one will emerge unchanged.
271	6	The Astonishing Force	1949	1953	Science Fiction	When gods fall, mortals must rise to fill the void.
272	9	The Amazing Order	1987	\N	Mystery	The line between hero and villain has never been thinner.
273	12	The Fearless Strike	1939	\N	Humor	In a world gone mad, only outlaws can restore order.
274	4	The Dark Unit	2002	2012	War	The line between hero and villain has never been thinner.
275	5	The Hidden Watch	1966	\N	Dark Superhero	Long-buried secrets threaten to destroy everything they built.
276	3	The Incredible Alliance	1969	1989	Romance	When gods fall, mortals must rise to fill the void.
277	6	The Incredible Vanguard	1963	1968	Mystery	Two enemies discover they share a common enemy.
278	3	The Cosmic Legion	1964	1980	Romance	When gods fall, mortals must rise to fill the void.
279	19	The Uncanny Collective	1954	1969	Superhero	Two enemies discover they share a common enemy.
280	14	The Uncanny Guardians	1998	\N	Science Fiction	Long-buried secrets threaten to destroy everything they built.
281	5	The Spectacular Syndicate	2006	\N	Humor	In a world gone mad, only outlaws can restore order.
282	18	The Amazing Warriors	1976	2000	Crime	Two enemies discover they share a common enemy.
283	9	The Shadow Division	1969	1974	Fantasy	One hero stands alone against an empire of darkness.
284	8	The Uncanny Patrol	2016	2017	Fantasy	One hero stands alone against an empire of darkness.
285	2	The Eternal Crusaders	1965	1990	Science Fiction	Two enemies discover they share a common enemy.
286	11	The Fearless Force	2011	2022	Fantasy	The line between hero and villain has never been thinner.
287	6	The Deadly Order	1945	1964	War	A new generation must carry the weight of a broken legacy.
288	13	The Secret Patrol	1990	\N	Science Fiction	Two enemies discover they share a common enemy.
289	17	The Uncanny Crusaders	1990	2008	Science Fiction	A new generation must carry the weight of a broken legacy.
290	2	The Uncanny Order	1986	2006	Horror	In a world gone mad, only outlaws can restore order.
291	16	The Last Alliance	1953	1978	Fantasy	The final war begins, and no one will emerge unchanged.
292	8	The Hidden Force	1990	\N	Humor	Long-buried secrets threaten to destroy everything they built.
293	5	The Incredible Strike	2012	2017	Fantasy	Ancient evil returns, and the old ways may be the only hope.
294	18	The Eternal Unit	2010	2018	War	Ancient evil returns, and the old ways may be the only hope.
295	2	The Uncanny Vanguard	1942	1945	Anthology	A team of unlikely heroes must unite to prevent catastrophe.
296	5	The Iron Brotherhood	2018	\N	Superhero	In a world gone mad, only outlaws can restore order.
297	18	The Iron Warriors	1940	1949	Action	A team of unlikely heroes must unite to prevent catastrophe.
298	7	The Dark Legion	1950	1958	Western	Two enemies discover they share a common enemy.
299	12	The Invincible Corps	1972	1975	Crime	When gods fall, mortals must rise to fill the void.
300	17	The Blazing Patrol	2020	2021	Superhero	In a world gone mad, only outlaws can restore order.
1	5	The Spectacular Warriors	1973	2024	Humor	One hero stands alone against an empire of darkness.
\.


--
-- TOC entry 5114 (class 0 OID 32951)
-- Dependencies: 232
-- Data for Name: story_arc; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.story_arc (arc_id, title, publisher_id, start_date, end_date, description) FROM stdin;
1	Dark Heroes	8	2004-07-12	2005-05-19	The villain wins — and the heroes must live with the consequences.
2	Age of the Machine	3	1998-09-17	2000-04-27	The last stand — not everyone will make it out alive.
3	End of Shadows	7	1940-09-03	1941-01-06	The villain wins — and the heroes must live with the consequences.
4	Trial of the Divide	7	1940-05-19	1942-01-13	A crossover event that touched every title in the line.
5	End of the Fallen	9	1978-04-20	1980-01-13	A universe-spanning event that reshapes the status quo forever.
6	Fall of the Abyss	5	1968-07-11	1969-05-21	The villain wins — and the heroes must live with the consequences.
7	Curse of the Machine	4	1946-04-28	1947-06-21	The first domino falls, setting off a chain of catastrophic events.
8	Legacy of the Divide	15	1961-09-24	1961-12-07	A crossover event that touched every title in the line.
9	Dark Destiny	10	1945-01-26	1946-09-13	The last stand — not everyone will make it out alive.
10	Legacy of the Sentinel	2	1955-04-02	1955-07-12	The villain wins — and the heroes must live with the consequences.
11	Return of the Cosmos	4	2014-09-26	2015-06-21	An intimate two-character story with massive implications.
12	Death of the Titan	6	1995-01-12	1996-02-19	The first domino falls, setting off a chain of catastrophic events.
13	Legacy of Judgment	3	1998-02-15	1998-12-15	The last stand — not everyone will make it out alive.
14	Fall of the Remnant	6	2003-06-01	2004-03-07	The definitive origin story, told for the first time in full.
15	Dawn of Chaos	8	1995-06-02	1997-01-22	The first domino falls, setting off a chain of catastrophic events.
16	Secret the Fallen	11	2011-09-23	2011-11-24	An intimate two-character story with massive implications.
17	Death of the Cosmos	11	1956-12-05	1958-08-07	The villain wins — and the heroes must live with the consequences.
18	Siege of Destiny	15	2017-05-15	2019-04-03	Heroes from across time must unite against an impossible threat.
19	Death of the Phoenix	18	1960-02-16	1961-10-12	A quiet, character-driven arc exploring loss and identity.
20	Escape from the Abyss	13	2018-07-19	2020-04-06	The first domino falls, setting off a chain of catastrophic events.
21	War of the Phoenix	3	1983-09-18	1985-03-06	A universe-spanning event that reshapes the status quo forever.
22	Dark the Phoenix	14	1994-04-17	1994-10-27	The last stand — not everyone will make it out alive.
23	Infinite Destiny	15	1972-03-27	1973-12-27	A crossover event that touched every title in the line.
24	Death of the Remnant	4	2015-03-24	2015-05-04	A crossover event that touched every title in the line.
25	Death of the Storm	14	1948-01-04	1948-11-29	Heroes from across time must unite against an impossible threat.
26	Birth of Heroes	17	2002-10-13	2003-08-08	Heroes from across time must unite against an impossible threat.
27	Trial of the Machine	10	2016-02-06	2017-12-07	A crossover event that touched every title in the line.
28	Wrath of Judgment	6	1951-09-18	1952-11-03	A crossover event that touched every title in the line.
29	Trial of Heroes	16	1991-09-26	1992-09-21	A universe-spanning event that reshapes the status quo forever.
30	Dark Vengeance	8	2016-10-31	2017-10-10	A universe-spanning event that reshapes the status quo forever.
31	War of the Sentinel	16	1945-01-24	1945-05-21	Decades of secrets come to a head in this explosive arc.
32	Hunt for the Phoenix	16	1949-07-09	1951-06-14	A crossover event that touched every title in the line.
33	Fall of Chaos	14	1985-05-04	1987-02-14	The villain wins — and the heroes must live with the consequences.
34	Hunt for Judgment	13	2001-12-17	2002-12-01	The first domino falls, setting off a chain of catastrophic events.
35	Birth of the Hollow	8	1978-07-04	1978-12-04	The villain wins — and the heroes must live with the consequences.
36	Infinite the Storm	18	1939-11-21	1941-08-14	The villain wins — and the heroes must live with the consequences.
37	Escape from the Fallen	2	1938-08-24	1938-12-04	The villain wins — and the heroes must live with the consequences.
38	Infinite Shadows	3	2015-02-14	2016-02-17	A crossover event that touched every title in the line.
39	War of Chaos	7	1998-01-07	1999-06-18	A crossover event that touched every title in the line.
40	Age of the Sentinel	8	1989-09-11	1991-02-07	The definitive origin story, told for the first time in full.
41	End of Judgment	14	1946-06-18	1946-10-25	The first domino falls, setting off a chain of catastrophic events.
42	End of the Abyss	4	1979-11-25	1980-02-18	A universe-spanning event that reshapes the status quo forever.
43	Dawn of the Storm	8	2009-10-28	2010-03-18	The villain wins — and the heroes must live with the consequences.
44	Rise of the Remnant	14	1978-04-01	1978-09-21	Heroes from across time must unite against an impossible threat.
45	War of the Cosmos	4	1977-10-03	1979-05-19	A universe-spanning event that reshapes the status quo forever.
46	Hunt for Heroes	6	1946-05-15	1947-02-11	An intimate two-character story with massive implications.
47	Siege of the Architect	2	1957-03-06	1958-05-20	Heroes from across time must unite against an impossible threat.
48	Dawn of Heroes	15	1973-01-10	1973-11-07	A quiet, character-driven arc exploring loss and identity.
49	End of the Remnant	5	1997-05-19	1998-10-29	The villain wins — and the heroes must live with the consequences.
50	Return of Judgment	18	1943-04-01	1944-12-14	A universe-spanning event that reshapes the status quo forever.
51	Curse of Shadows	16	1942-07-02	1944-03-21	A crossover event that touched every title in the line.
52	Trial of Reckoning	3	1943-02-07	1944-08-10	Heroes from across time must unite against an impossible threat.
53	Infinite the Divide	8	1944-02-05	1946-01-26	An intimate two-character story with massive implications.
54	Dark the Sentinel	20	1960-02-02	1961-10-16	A universe-spanning event that reshapes the status quo forever.
55	Wrath of the Cosmos	19	1975-08-12	1977-07-15	The last stand — not everyone will make it out alive.
56	Trial of the Storm	11	1961-05-24	1962-01-18	The villain wins — and the heroes must live with the consequences.
57	Death of Destiny	10	1949-09-28	1951-09-15	The definitive origin story, told for the first time in full.
58	Curse of the Cosmos	20	1938-11-02	1940-03-15	The last stand — not everyone will make it out alive.
59	Dark the Cosmos	17	1986-03-27	1986-11-30	A quiet, character-driven arc exploring loss and identity.
60	Age of Vengeance	8	2017-01-10	2017-04-20	The first domino falls, setting off a chain of catastrophic events.
61	Return of Reckoning	10	1977-04-24	1978-12-01	The last stand — not everyone will make it out alive.
62	Hunt for Eternity	5	1997-07-07	1997-11-20	A quiet, character-driven arc exploring loss and identity.
63	Dark the Machine	5	2004-08-09	2006-03-28	A quiet, character-driven arc exploring loss and identity.
64	Return of the Divide	7	1956-11-23	1957-12-09	A quiet, character-driven arc exploring loss and identity.
65	Trial of the Architect	3	1960-07-12	1960-10-02	An intimate two-character story with massive implications.
66	Death of Shadows	5	1938-04-27	1939-05-03	A quiet, character-driven arc exploring loss and identity.
67	Fall of the Titan	18	1987-06-30	1988-10-09	A universe-spanning event that reshapes the status quo forever.
68	Age of the Remnant	19	1941-03-26	1942-05-08	A crossover event that touched every title in the line.
69	Age of the Abyss	10	1949-06-08	1949-08-19	The first domino falls, setting off a chain of catastrophic events.
70	Secret Vengeance	8	1956-11-05	1958-11-03	Decades of secrets come to a head in this explosive arc.
71	Legacy of the Remnant	20	2017-04-27	2018-07-17	Heroes from across time must unite against an impossible threat.
72	War of Reckoning	14	2009-10-05	2010-05-04	A universe-spanning event that reshapes the status quo forever.
73	Fall of the Storm	8	2008-03-11	2009-06-05	A quiet, character-driven arc exploring loss and identity.
74	Fall of the Machine	16	1972-04-27	1972-07-05	The villain wins — and the heroes must live with the consequences.
75	Rise of the Titan	8	1969-05-15	1970-04-22	The villain wins — and the heroes must live with the consequences.
76	Final Judgment	9	1973-09-30	1974-10-01	Decades of secrets come to a head in this explosive arc.
77	Death of Vengeance	13	1995-07-21	1997-01-22	A crossover event that touched every title in the line.
78	Curse of Heroes	6	1948-05-07	1949-02-28	The last stand — not everyone will make it out alive.
79	Dark the Divide	11	1976-12-26	1978-01-13	An intimate two-character story with massive implications.
80	Wrath of the Hollow	19	1948-05-17	1949-07-15	The villain wins — and the heroes must live with the consequences.
81	End of Heroes	7	1984-08-23	1986-03-27	The first domino falls, setting off a chain of catastrophic events.
82	End of the Cosmos	20	1997-08-04	1998-08-07	The first domino falls, setting off a chain of catastrophic events.
83	Dark Eternity	14	1983-07-01	1984-06-11	The first domino falls, setting off a chain of catastrophic events.
84	Dawn of Eternity	7	1987-09-27	1988-03-05	An intimate two-character story with massive implications.
85	Dawn of Reckoning	10	1993-03-22	1994-11-24	An intimate two-character story with massive implications.
86	Return of Eternity	19	1956-11-09	1958-02-22	The last stand — not everyone will make it out alive.
87	Curse of the Titan	7	1977-08-20	1978-12-15	A crossover event that touched every title in the line.
88	Siege of Reckoning	10	1997-02-09	1997-06-05	A crossover event that touched every title in the line.
89	Wrath of the Storm	10	1946-05-19	1947-02-13	The villain wins — and the heroes must live with the consequences.
90	Rise of the Phoenix	8	1940-03-11	1940-05-27	The definitive origin story, told for the first time in full.
91	Birth of the Abyss	19	2017-07-01	2019-05-06	The villain wins — and the heroes must live with the consequences.
92	Dawn of the Architect	5	1973-11-08	1974-08-14	A universe-spanning event that reshapes the status quo forever.
93	Dark the Abyss	17	1957-08-19	1958-03-17	The definitive origin story, told for the first time in full.
94	Secret the Remnant	15	1960-05-10	1960-10-11	Heroes from across time must unite against an impossible threat.
95	Hunt for the Divide	20	1966-06-20	1967-10-16	A crossover event that touched every title in the line.
96	Birth of Reckoning	15	2004-09-19	2006-02-17	A quiet, character-driven arc exploring loss and identity.
97	Birth of the Cosmos	8	2002-01-06	2002-11-24	A quiet, character-driven arc exploring loss and identity.
98	Curse of the Storm	3	2018-02-12	2019-09-18	Heroes from across time must unite against an impossible threat.
99	Age of the Fallen	7	1972-05-13	1972-11-15	Decades of secrets come to a head in this explosive arc.
100	Curse of the Remnant	2	1979-10-20	1981-01-17	The villain wins — and the heroes must live with the consequences.
101	End of Destiny	1	2019-03-06	2020-11-23	The last stand — not everyone will make it out alive.
102	Final Vengeance	14	1964-10-15	1965-12-18	A crossover event that touched every title in the line.
103	War of the Architect	14	1957-09-08	1958-07-14	The definitive origin story, told for the first time in full.
104	Final Destiny	13	1968-02-27	1970-02-10	Heroes from across time must unite against an impossible threat.
105	Birth of the Phoenix	1	1993-10-29	1995-05-28	An intimate two-character story with massive implications.
106	Escape from the Sentinel	3	1997-06-25	1997-08-21	An intimate two-character story with massive implications.
107	Age of the Titan	9	1954-04-21	1954-07-11	An intimate two-character story with massive implications.
108	Curse of Judgment	11	1978-10-17	1979-10-16	An intimate two-character story with massive implications.
109	Death of the Abyss	16	1960-08-19	1960-12-10	A universe-spanning event that reshapes the status quo forever.
110	Hunt for Shadows	3	1969-05-25	1970-02-08	A universe-spanning event that reshapes the status quo forever.
111	Final the Fallen	20	1955-11-20	1956-01-09	Heroes from across time must unite against an impossible threat.
112	Siege of the Machine	15	1988-08-06	1989-04-16	A quiet, character-driven arc exploring loss and identity.
113	Legacy of Reckoning	4	1992-05-10	1994-02-20	Heroes from across time must unite against an impossible threat.
114	Return of the Machine	10	1989-12-01	1990-01-26	The last stand — not everyone will make it out alive.
115	Dawn of Destiny	3	2002-02-23	2002-10-14	The last stand — not everyone will make it out alive.
116	War of the Machine	20	2000-07-19	2001-06-22	Decades of secrets come to a head in this explosive arc.
117	Escape from Shadows	14	1969-02-24	1970-09-22	The first domino falls, setting off a chain of catastrophic events.
118	Infinite the Hollow	1	1996-02-04	1997-02-17	An intimate two-character story with massive implications.
119	End of Vengeance	5	1995-01-08	1996-05-22	An intimate two-character story with massive implications.
120	Fall of the Hollow	20	1996-05-10	1997-03-12	A crossover event that touched every title in the line.
121	Siege of the Titan	9	1977-01-28	1978-10-26	The first domino falls, setting off a chain of catastrophic events.
122	War of the Titan	13	1989-02-14	1990-11-30	The first domino falls, setting off a chain of catastrophic events.
123	Final the Architect	6	2014-05-06	2015-05-03	The definitive origin story, told for the first time in full.
124	Rise of Vengeance	11	2009-07-30	2010-05-20	A quiet, character-driven arc exploring loss and identity.
125	Wrath of Chaos	17	1987-11-12	1987-12-22	The villain wins — and the heroes must live with the consequences.
126	Infinite the Fallen	16	2002-08-08	2003-10-28	A crossover event that touched every title in the line.
127	Final the Cosmos	13	1964-05-25	1965-02-05	The villain wins — and the heroes must live with the consequences.
128	Return of the Sentinel	18	1971-02-09	1972-07-07	A crossover event that touched every title in the line.
129	Legacy of the Abyss	11	2004-12-02	2006-07-18	The first domino falls, setting off a chain of catastrophic events.
130	Birth of Chaos	8	1965-07-05	1966-04-18	Decades of secrets come to a head in this explosive arc.
131	Rise of the Storm	6	1948-09-22	1950-04-23	The villain wins — and the heroes must live with the consequences.
132	Rise of the Architect	17	1962-10-22	1964-07-16	The last stand — not everyone will make it out alive.
133	Rise of Eternity	6	1958-05-30	1959-07-03	A quiet, character-driven arc exploring loss and identity.
134	Final the Remnant	2	1949-05-10	1950-03-16	A universe-spanning event that reshapes the status quo forever.
135	Age of the Architect	19	1947-03-16	1947-04-27	A quiet, character-driven arc exploring loss and identity.
136	Birth of the Storm	9	1954-07-17	1954-10-07	The definitive origin story, told for the first time in full.
137	Infinite the Sentinel	5	1994-06-21	1994-09-13	Heroes from across time must unite against an impossible threat.
138	Escape from Eternity	4	1945-08-23	1946-06-03	A crossover event that touched every title in the line.
139	End of the Divide	8	1991-06-25	1993-04-18	A crossover event that touched every title in the line.
140	Dawn of the Titan	10	2019-07-04	2020-10-29	The last stand — not everyone will make it out alive.
141	End of Eternity	2	1989-01-05	1990-11-01	The last stand — not everyone will make it out alive.
142	Dark Judgment	9	1994-02-12	1994-10-16	Decades of secrets come to a head in this explosive arc.
143	Fall of the Fallen	3	1953-08-05	1955-03-23	Heroes from across time must unite against an impossible threat.
144	Final the Abyss	16	1978-06-02	1980-03-01	A quiet, character-driven arc exploring loss and identity.
145	Escape from Judgment	18	1976-02-21	1976-07-17	The villain wins — and the heroes must live with the consequences.
146	Age of Chaos	3	2012-02-29	2012-08-22	A universe-spanning event that reshapes the status quo forever.
147	Fall of Eternity	10	1991-05-21	1993-01-22	The definitive origin story, told for the first time in full.
148	Dark the Titan	13	1999-10-14	2000-09-19	A quiet, character-driven arc exploring loss and identity.
149	Trial of the Remnant	3	1982-04-20	1983-08-11	The last stand — not everyone will make it out alive.
150	Secret the Abyss	20	2003-11-25	2004-11-19	A quiet, character-driven arc exploring loss and identity.
151	Escape from Heroes	9	2006-08-11	2008-07-29	The last stand — not everyone will make it out alive.
152	Secret Reckoning	15	1980-03-18	1981-09-30	A quiet, character-driven arc exploring loss and identity.
153	Fall of the Sentinel	16	1977-02-08	1978-12-20	Decades of secrets come to a head in this explosive arc.
154	Siege of Vengeance	11	1974-08-20	1975-08-26	Decades of secrets come to a head in this explosive arc.
155	End of the Architect	13	1963-11-10	1965-10-18	A crossover event that touched every title in the line.
156	Secret the Titan	9	1945-11-25	1946-11-12	The first domino falls, setting off a chain of catastrophic events.
157	Hunt for the Titan	7	1975-01-28	1975-04-23	A crossover event that touched every title in the line.
158	Secret Judgment	5	1961-12-16	1963-07-31	A quiet, character-driven arc exploring loss and identity.
159	Birth of the Architect	20	1948-11-22	1949-01-20	The villain wins — and the heroes must live with the consequences.
160	Hunt for the Abyss	4	1946-05-13	1947-01-28	The definitive origin story, told for the first time in full.
161	Siege of Eternity	14	1983-08-27	1984-07-01	The definitive origin story, told for the first time in full.
162	Siege of the Fallen	5	1978-12-24	1980-08-09	An intimate two-character story with massive implications.
163	Rise of the Divide	3	1983-08-07	1984-01-23	A quiet, character-driven arc exploring loss and identity.
164	End of the Storm	9	2008-09-01	2010-03-04	A universe-spanning event that reshapes the status quo forever.
165	Siege of the Phoenix	16	1978-01-23	1979-08-27	The first domino falls, setting off a chain of catastrophic events.
166	Hunt for Destiny	7	1978-11-07	1979-11-01	The villain wins — and the heroes must live with the consequences.
167	Escape from Destiny	2	1958-12-15	1960-03-09	The first domino falls, setting off a chain of catastrophic events.
168	Dawn of the Phoenix	5	1982-06-09	1982-08-15	A crossover event that touched every title in the line.
169	Escape from the Storm	15	2016-01-10	2016-05-21	Decades of secrets come to a head in this explosive arc.
170	Trial of the Titan	14	1939-05-18	1939-11-11	Heroes from across time must unite against an impossible threat.
171	Infinite the Architect	11	2008-02-12	2008-12-09	The last stand — not everyone will make it out alive.
172	Dawn of the Cosmos	18	2014-06-01	2015-06-02	An intimate two-character story with massive implications.
173	Curse of the Architect	2	2016-04-07	2017-11-12	The last stand — not everyone will make it out alive.
174	Return of the Fallen	14	2004-12-30	2005-05-01	Decades of secrets come to a head in this explosive arc.
175	Final Shadows	10	1967-02-07	1967-05-05	The first domino falls, setting off a chain of catastrophic events.
176	Trial of the Abyss	6	1988-10-09	1990-10-07	Heroes from across time must unite against an impossible threat.
177	Fall of the Cosmos	20	1992-09-05	1993-10-31	The villain wins — and the heroes must live with the consequences.
178	Siege of the Sentinel	15	1950-11-03	1951-07-28	A quiet, character-driven arc exploring loss and identity.
179	Final the Titan	18	2018-11-07	2019-09-27	Heroes from across time must unite against an impossible threat.
180	Infinite the Titan	10	1969-01-01	1970-09-24	An intimate two-character story with massive implications.
181	Dark the Fallen	12	1972-03-19	1973-11-24	The last stand — not everyone will make it out alive.
182	Death of Heroes	20	1988-10-09	1988-12-28	The definitive origin story, told for the first time in full.
183	Wrath of Vengeance	7	1957-08-25	1959-07-07	The last stand — not everyone will make it out alive.
184	Dark Shadows	2	1965-09-19	1967-01-13	The last stand — not everyone will make it out alive.
185	Legacy of the Phoenix	11	1946-02-01	1946-12-30	An intimate two-character story with massive implications.
186	Fall of Judgment	12	1949-11-09	1951-06-14	A crossover event that touched every title in the line.
187	Trial of Chaos	9	2012-07-03	2013-01-17	The definitive origin story, told for the first time in full.
188	Return of the Storm	15	2010-02-25	2010-07-22	Decades of secrets come to a head in this explosive arc.
189	Dawn of the Remnant	13	1970-10-25	1971-02-24	A universe-spanning event that reshapes the status quo forever.
190	Legacy of Chaos	12	1990-06-11	1991-08-05	Decades of secrets come to a head in this explosive arc.
191	Final the Divide	11	2017-04-30	2018-12-25	The last stand — not everyone will make it out alive.
192	Birth of Eternity	4	1996-03-31	1997-06-22	Heroes from across time must unite against an impossible threat.
193	Secret Shadows	4	1965-04-22	1966-10-08	Decades of secrets come to a head in this explosive arc.
194	War of the Remnant	15	1950-03-04	1951-05-05	The first domino falls, setting off a chain of catastrophic events.
195	Escape from the Phoenix	4	2017-06-08	2018-09-05	The definitive origin story, told for the first time in full.
196	Wrath of the Abyss	12	1963-02-05	1963-04-09	The villain wins — and the heroes must live with the consequences.
197	Birth of the Titan	4	1959-03-08	1960-04-12	The first domino falls, setting off a chain of catastrophic events.
198	Hunt for Vengeance	9	1943-06-08	1944-08-18	The villain wins — and the heroes must live with the consequences.
199	Infinite Judgment	20	1995-07-28	1997-06-11	A universe-spanning event that reshapes the status quo forever.
200	Secret the Storm	19	1959-11-08	1960-04-14	The villain wins — and the heroes must live with the consequences.
\.


--
-- TOC entry 5127 (class 0 OID 0)
-- Dependencies: 228
-- Name: character_character_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.character_character_id_seq', 1, false);


--
-- TOC entry 5128 (class 0 OID 0)
-- Dependencies: 223
-- Name: creator_creator_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.creator_creator_id_seq', 1, false);


--
-- TOC entry 5129 (class 0 OID 0)
-- Dependencies: 225
-- Name: issue_issue_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.issue_issue_id_seq', 1, false);


--
-- TOC entry 5130 (class 0 OID 0)
-- Dependencies: 219
-- Name: publisher_publisher_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.publisher_publisher_id_seq', 1, false);


--
-- TOC entry 5131 (class 0 OID 0)
-- Dependencies: 221
-- Name: series_series_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.series_series_id_seq', 1, false);


--
-- TOC entry 5132 (class 0 OID 0)
-- Dependencies: 231
-- Name: story_arc_arc_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.story_arc_arc_id_seq', 1, false);


--
-- TOC entry 4935 (class 2606 OID 32925)
-- Name: character character_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."character"
    ADD CONSTRAINT character_pkey PRIMARY KEY (character_id);


--
-- TOC entry 4929 (class 2606 OID 32878)
-- Name: creator creator_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.creator
    ADD CONSTRAINT creator_pkey PRIMARY KEY (creator_id);


--
-- TOC entry 4937 (class 2606 OID 32939)
-- Name: issue_character issue_character_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.issue_character
    ADD CONSTRAINT issue_character_pkey PRIMARY KEY (issue_id, character_id);


--
-- TOC entry 4933 (class 2606 OID 32903)
-- Name: issue_creator issue_creator_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.issue_creator
    ADD CONSTRAINT issue_creator_pkey PRIMARY KEY (issue_id, creator_id, role);


--
-- TOC entry 4931 (class 2606 OID 32890)
-- Name: issue issue_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.issue
    ADD CONSTRAINT issue_pkey PRIMARY KEY (issue_id);


--
-- TOC entry 4941 (class 2606 OID 32972)
-- Name: issue_story_arc issue_story_arc_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.issue_story_arc
    ADD CONSTRAINT issue_story_arc_pkey PRIMARY KEY (issue_id, arc_id);


--
-- TOC entry 4923 (class 2606 OID 32849)
-- Name: publisher publisher_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.publisher
    ADD CONSTRAINT publisher_name_key UNIQUE (name);


--
-- TOC entry 4925 (class 2606 OID 32847)
-- Name: publisher publisher_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.publisher
    ADD CONSTRAINT publisher_pkey PRIMARY KEY (publisher_id);


--
-- TOC entry 4927 (class 2606 OID 32861)
-- Name: series series_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.series
    ADD CONSTRAINT series_pkey PRIMARY KEY (series_id);


--
-- TOC entry 4939 (class 2606 OID 32960)
-- Name: story_arc story_arc_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.story_arc
    ADD CONSTRAINT story_arc_pkey PRIMARY KEY (arc_id);


--
-- TOC entry 4946 (class 2606 OID 32926)
-- Name: character character_publisher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."character"
    ADD CONSTRAINT character_publisher_id_fkey FOREIGN KEY (publisher_id) REFERENCES public.publisher(publisher_id);


--
-- TOC entry 4947 (class 2606 OID 32945)
-- Name: issue_character issue_character_character_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.issue_character
    ADD CONSTRAINT issue_character_character_id_fkey FOREIGN KEY (character_id) REFERENCES public."character"(character_id);


--
-- TOC entry 4948 (class 2606 OID 32940)
-- Name: issue_character issue_character_issue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.issue_character
    ADD CONSTRAINT issue_character_issue_id_fkey FOREIGN KEY (issue_id) REFERENCES public.issue(issue_id);


--
-- TOC entry 4944 (class 2606 OID 32909)
-- Name: issue_creator issue_creator_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.issue_creator
    ADD CONSTRAINT issue_creator_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.creator(creator_id);


--
-- TOC entry 4945 (class 2606 OID 32904)
-- Name: issue_creator issue_creator_issue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.issue_creator
    ADD CONSTRAINT issue_creator_issue_id_fkey FOREIGN KEY (issue_id) REFERENCES public.issue(issue_id);


--
-- TOC entry 4943 (class 2606 OID 32891)
-- Name: issue issue_series_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.issue
    ADD CONSTRAINT issue_series_id_fkey FOREIGN KEY (series_id) REFERENCES public.series(series_id);


--
-- TOC entry 4950 (class 2606 OID 32978)
-- Name: issue_story_arc issue_story_arc_arc_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.issue_story_arc
    ADD CONSTRAINT issue_story_arc_arc_id_fkey FOREIGN KEY (arc_id) REFERENCES public.story_arc(arc_id);


--
-- TOC entry 4951 (class 2606 OID 32973)
-- Name: issue_story_arc issue_story_arc_issue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.issue_story_arc
    ADD CONSTRAINT issue_story_arc_issue_id_fkey FOREIGN KEY (issue_id) REFERENCES public.issue(issue_id);


--
-- TOC entry 4942 (class 2606 OID 32862)
-- Name: series series_publisher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.series
    ADD CONSTRAINT series_publisher_id_fkey FOREIGN KEY (publisher_id) REFERENCES public.publisher(publisher_id);


--
-- TOC entry 4949 (class 2606 OID 32961)
-- Name: story_arc story_arc_publisher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.story_arc
    ADD CONSTRAINT story_arc_publisher_id_fkey FOREIGN KEY (publisher_id) REFERENCES public.publisher(publisher_id);


-- Completed on 2026-05-05 22:02:46

--
-- PostgreSQL database dump complete
--

\unrestrict 32zlYhPzJLp4IzbDZ2HNFutXhPtvhtcSL8tTZdGERU5P8OcKjbcBFGcSnairrpL

