--
-- PostgreSQL database dump
--

-- Dumped from database version 16.4 (Debian 16.4-1.pgdg110+2)
-- Dumped by pg_dump version 16.4 (Debian 16.4-1.pgdg110+2)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: app; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA app;


ALTER SCHEMA app OWNER TO postgres;

--
-- Name: tiger; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA tiger;


ALTER SCHEMA tiger OWNER TO postgres;

--
-- Name: tiger_data; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA tiger_data;


ALTER SCHEMA tiger_data OWNER TO postgres;

--
-- Name: topology; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA topology;


ALTER SCHEMA topology OWNER TO postgres;

--
-- Name: SCHEMA topology; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA topology IS 'PostGIS Topology schema';


--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: fuzzystrmatch; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS fuzzystrmatch WITH SCHEMA public;


--
-- Name: EXTENSION fuzzystrmatch; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION fuzzystrmatch IS 'determine similarities and distance between strings';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: postgis_tiger_geocoder; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder WITH SCHEMA tiger;


--
-- Name: EXTENSION postgis_tiger_geocoder; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis_tiger_geocoder IS 'PostGIS tiger geocoder and reverse geocoder';


--
-- Name: postgis_topology; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis_topology WITH SCHEMA topology;


--
-- Name: EXTENSION postgis_topology; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis_topology IS 'PostGIS topology spatial types and functions';


--
-- Name: activity_verb; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.activity_verb AS ENUM (
    'logged_tree',
    'earned_badge',
    'verified_id',
    'commented',
    'followed'
);


ALTER TYPE public.activity_verb OWNER TO postgres;

--
-- Name: comment_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.comment_status AS ENUM (
    'visible',
    'hidden',
    'removed'
);


ALTER TYPE public.comment_status OWNER TO postgres;

--
-- Name: consent_kind; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.consent_kind AS ENUM (
    'tos',
    'privacy',
    'coppa_guardian'
);


ALTER TYPE public.consent_kind OWNER TO postgres;

--
-- Name: deletion_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.deletion_status AS ENUM (
    'scheduled',
    'cancelled',
    'completed'
);


ALTER TYPE public.deletion_status OWNER TO postgres;

--
-- Name: export_format; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.export_format AS ENUM (
    'json',
    'csv'
);


ALTER TYPE public.export_format OWNER TO postgres;

--
-- Name: export_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.export_status AS ENUM (
    'queued',
    'processing',
    'ready',
    'failed',
    'expired'
);


ALTER TYPE public.export_status OWNER TO postgres;

--
-- Name: mod_action; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.mod_action AS ENUM (
    'hide',
    'remove',
    'warn',
    'ban',
    'dismiss',
    'restore'
);


ALTER TYPE public.mod_action OWNER TO postgres;

--
-- Name: photo_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.photo_status AS ENUM (
    'pending',
    'processed',
    'failed'
);


ALTER TYPE public.photo_status OWNER TO postgres;

--
-- Name: report_reason; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.report_reason AS ENUM (
    'inaccurate_id',
    'wrong_location',
    'spam',
    'offensive',
    'sensitive_species',
    'privacy',
    'other'
);


ALTER TYPE public.report_reason OWNER TO postgres;

--
-- Name: report_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.report_status AS ENUM (
    'open',
    'reviewing',
    'actioned',
    'dismissed'
);


ALTER TYPE public.report_status OWNER TO postgres;

--
-- Name: report_target; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.report_target AS ENUM (
    'tree',
    'comment',
    'user'
);


ALTER TYPE public.report_target OWNER TO postgres;

--
-- Name: tree_health; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.tree_health AS ENUM (
    'healthy',
    'stressed',
    'dead',
    'unknown'
);


ALTER TYPE public.tree_health OWNER TO postgres;

--
-- Name: tree_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.tree_status AS ENUM (
    'active',
    'hidden',
    'removed'
);


ALTER TYPE public.tree_status OWNER TO postgres;

--
-- Name: tree_visibility; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.tree_visibility AS ENUM (
    'public',
    'followers',
    'private'
);


ALTER TYPE public.tree_visibility OWNER TO postgres;

--
-- Name: user_role; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.user_role AS ENUM (
    'user',
    'moderator',
    'admin'
);


ALTER TYPE public.user_role OWNER TO postgres;

--
-- Name: apply_points(); Type: FUNCTION; Schema: app; Owner: postgres
--

CREATE FUNCTION app.apply_points() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  UPDATE users SET points = points + NEW.delta WHERE id = NEW.user_id;
  RETURN NEW;
END $$;


ALTER FUNCTION app.apply_points() OWNER TO postgres;

--
-- Name: bump_comment_count(); Type: FUNCTION; Schema: app; Owner: postgres
--

CREATE FUNCTION app.bump_comment_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE trees SET comment_count = comment_count + 1 WHERE id = NEW.tree_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE trees SET comment_count = GREATEST(comment_count - 1, 0) WHERE id = OLD.tree_id;
  END IF;
  RETURN NULL;
END $$;


ALTER FUNCTION app.bump_comment_count() OWNER TO postgres;

--
-- Name: bump_like_count(); Type: FUNCTION; Schema: app; Owner: postgres
--

CREATE FUNCTION app.bump_like_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE trees SET like_count = like_count + 1 WHERE id = NEW.tree_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE trees SET like_count = GREATEST(like_count - 1, 0) WHERE id = OLD.tree_id;
  END IF;
  RETURN NULL;
END $$;


ALTER FUNCTION app.bump_like_count() OWNER TO postgres;

--
-- Name: current_user_id(); Type: FUNCTION; Schema: app; Owner: postgres
--

CREATE FUNCTION app.current_user_id() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
    SELECT NULLIF(current_setting('app.user_id', true), '')::uuid
$$;


ALTER FUNCTION app.current_user_id() OWNER TO postgres;

--
-- Name: current_user_role(); Type: FUNCTION; Schema: app; Owner: postgres
--

CREATE FUNCTION app.current_user_role() RETURNS text
    LANGUAGE sql STABLE
    AS $$
    SELECT COALESCE(NULLIF(current_setting('app.user_role', true), ''), 'anon')
$$;


ALTER FUNCTION app.current_user_role() OWNER TO postgres;

--
-- Name: fuzz_point(public.geography, double precision); Type: FUNCTION; Schema: app; Owner: postgres
--

CREATE FUNCTION app.fuzz_point(exact public.geography, radius_m double precision DEFAULT 500) RETURNS public.geography
    LANGUAGE plpgsql
    AS $$
DECLARE
  azimuth  double precision := 2 * pi() * random();
  distance double precision := radius_m * sqrt(random());
BEGIN
  -- ST_Project works on geography and returns a geography point.
  RETURN ST_Project(exact, distance, azimuth);
END $$;


ALTER FUNCTION app.fuzz_point(exact public.geography, radius_m double precision) OWNER TO postgres;

--
-- Name: is_staff(); Type: FUNCTION; Schema: app; Owner: postgres
--

CREATE FUNCTION app.is_staff() RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
    SELECT app.current_user_role() IN ('moderator', 'admin')
$$;


ALTER FUNCTION app.is_staff() OWNER TO postgres;

--
-- Name: rate_hit(text, text, timestamp with time zone); Type: FUNCTION; Schema: app; Owner: postgres
--

CREATE FUNCTION app.rate_hit(p_bucket text, p_route text, p_window_start timestamp with time zone) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE new_count int;
BEGIN
  INSERT INTO rate_limit_counters (bucket, route, window_start, count)
  VALUES (p_bucket, p_route, p_window_start, 1)
  ON CONFLICT (bucket, route, window_start)
  DO UPDATE SET count = rate_limit_counters.count + 1
  RETURNING count INTO new_count;
  RETURN new_count;
END $$;


ALTER FUNCTION app.rate_hit(p_bucket text, p_route text, p_window_start timestamp with time zone) OWNER TO postgres;

--
-- Name: set_tree_location(uuid, double precision, double precision, double precision, boolean); Type: FUNCTION; Schema: app; Owner: postgres
--

CREATE FUNCTION app.set_tree_location(p_tree_id uuid, p_lat double precision, p_lng double precision, p_accuracy_m double precision, p_is_fuzzy boolean) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  g geography := ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography;
BEGIN
  INSERT INTO tree_exact_locations (tree_id, exact_geom, accuracy_m)
  VALUES (p_tree_id, g, p_accuracy_m)
  ON CONFLICT (tree_id)
  DO UPDATE SET exact_geom = EXCLUDED.exact_geom,
                accuracy_m = EXCLUDED.accuracy_m,
                captured_at = now();

  UPDATE trees
     SET fuzzy_geom = CASE WHEN p_is_fuzzy THEN app.fuzz_point(g, 500) ELSE g END,
         is_fuzzy   = p_is_fuzzy
   WHERE id = p_tree_id;
END $$;


ALTER FUNCTION app.set_tree_location(p_tree_id uuid, p_lat double precision, p_lng double precision, p_accuracy_m double precision, p_is_fuzzy boolean) OWNER TO postgres;

--
-- Name: touch_updated_at(); Type: FUNCTION; Schema: app; Owner: postgres
--

CREATE FUNCTION app.touch_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END $$;


ALTER FUNCTION app.touch_updated_at() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: account_deletion_requests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.account_deletion_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    status public.deletion_status DEFAULT 'scheduled'::public.deletion_status NOT NULL,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    purge_after timestamp with time zone DEFAULT (now() + '30 days'::interval) NOT NULL,
    completed_at timestamp with time zone
);


ALTER TABLE public.account_deletion_requests OWNER TO postgres;

--
-- Name: activity; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.activity (
    id bigint NOT NULL,
    actor_id uuid NOT NULL,
    verb public.activity_verb NOT NULL,
    object_type text,
    object_id uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.activity OWNER TO postgres;

--
-- Name: activity_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.activity ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.activity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: api_keys; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.api_keys (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    name text NOT NULL,
    key_hash text NOT NULL,
    scopes text[] DEFAULT '{}'::text[] NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    revoked_at timestamp with time zone,
    last_used timestamp with time zone
);


ALTER TABLE public.api_keys OWNER TO postgres;

--
-- Name: audit_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.audit_log (
    id bigint NOT NULL,
    actor_id uuid,
    action text NOT NULL,
    entity text,
    entity_id uuid,
    ip inet,
    user_agent text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.audit_log OWNER TO postgres;

--
-- Name: audit_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.audit_log ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.audit_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: badges; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.badges (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    description text,
    icon text,
    criteria jsonb DEFAULT '{}'::jsonb NOT NULL
);


ALTER TABLE public.badges OWNER TO postgres;

--
-- Name: comments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.comments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tree_id uuid NOT NULL,
    author_id uuid NOT NULL,
    body text NOT NULL,
    status public.comment_status DEFAULT 'visible'::public.comment_status NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT comments_body_check CHECK (((length(body) >= 1) AND (length(body) <= 2000)))
);


ALTER TABLE public.comments OWNER TO postgres;

--
-- Name: consents; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.consents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    kind public.consent_kind NOT NULL,
    version text NOT NULL,
    granted boolean NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.consents OWNER TO postgres;

--
-- Name: data_export_jobs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.data_export_jobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    format public.export_format DEFAULT 'json'::public.export_format NOT NULL,
    status public.export_status DEFAULT 'queued'::public.export_status NOT NULL,
    file_key text,
    download_url text,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    expires_at timestamp with time zone
);


ALTER TABLE public.data_export_jobs OWNER TO postgres;

--
-- Name: follows; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.follows (
    follower_id uuid NOT NULL,
    followee_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT no_self_follow CHECK ((follower_id <> followee_id))
);


ALTER TABLE public.follows OWNER TO postgres;

--
-- Name: leaderboard_week; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.leaderboard_week AS
SELECT
    NULL::uuid AS id,
    NULL::public.citext AS username,
    NULL::text AS display_name,
    NULL::text AS avatar_url,
    NULL::bigint AS logs;


ALTER VIEW public.leaderboard_week OWNER TO postgres;

--
-- Name: likes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.likes (
    tree_id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.likes OWNER TO postgres;

--
-- Name: moderation_actions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.moderation_actions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    moderator_id uuid NOT NULL,
    report_id uuid,
    target_type public.report_target NOT NULL,
    target_id uuid NOT NULL,
    action public.mod_action NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.moderation_actions OWNER TO postgres;

--
-- Name: points_ledger; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.points_ledger (
    id bigint NOT NULL,
    user_id uuid NOT NULL,
    delta integer NOT NULL,
    reason text NOT NULL,
    tree_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.points_ledger OWNER TO postgres;

--
-- Name: points_ledger_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.points_ledger ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.points_ledger_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: rate_limit_counters; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rate_limit_counters (
    bucket text NOT NULL,
    route text NOT NULL,
    window_start timestamp with time zone NOT NULL,
    count integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.rate_limit_counters OWNER TO postgres;

--
-- Name: refresh_tokens; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.refresh_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    token_hash text NOT NULL,
    user_agent text,
    ip inet,
    expires_at timestamp with time zone NOT NULL,
    revoked_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.refresh_tokens OWNER TO postgres;

--
-- Name: reports; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.reports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    reporter_id uuid,
    target_type public.report_target NOT NULL,
    target_id uuid NOT NULL,
    reason public.report_reason NOT NULL,
    details text,
    status public.report_status DEFAULT 'open'::public.report_status NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    resolved_at timestamp with time zone,
    resolver_id uuid
);


ALTER TABLE public.reports OWNER TO postgres;

--
-- Name: saved_trees; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.saved_trees (
    user_id uuid NOT NULL,
    tree_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.saved_trees OWNER TO postgres;

--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.schema_migrations (
    name text NOT NULL,
    applied_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.schema_migrations OWNER TO postgres;

--
-- Name: species; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.species (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    common_name text NOT NULL,
    scientific_name text NOT NULL,
    family text,
    native_range text,
    description text,
    gbif_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.species OWNER TO postgres;

--
-- Name: tree_exact_locations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tree_exact_locations (
    tree_id uuid NOT NULL,
    exact_geom public.geography(Point,4326) NOT NULL,
    accuracy_m numeric(6,1),
    captured_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE ONLY public.tree_exact_locations FORCE ROW LEVEL SECURITY;


ALTER TABLE public.tree_exact_locations OWNER TO postgres;

--
-- Name: tree_photos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tree_photos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tree_id uuid NOT NULL,
    organ text,
    storage_key text NOT NULL,
    public_url text,
    thumb_url text,
    width integer,
    height integer,
    exif_stripped boolean DEFAULT false NOT NULL,
    status public.photo_status DEFAULT 'pending'::public.photo_status NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT tree_photos_organ_check CHECK ((organ = ANY (ARRAY['whole'::text, 'bark'::text, 'leaf'::text, 'flower'::text, 'fruit'::text])))
);


ALTER TABLE public.tree_photos OWNER TO postgres;

--
-- Name: tree_verifications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tree_verifications (
    tree_id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.tree_verifications OWNER TO postgres;

--
-- Name: trees; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.trees (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    owner_id uuid NOT NULL,
    species_id uuid,
    common_name text NOT NULL,
    scientific_name text,
    height_m numeric(5,1),
    girth_m numeric(5,2),
    age_estimate text,
    health public.tree_health DEFAULT 'unknown'::public.tree_health NOT NULL,
    description text,
    features text[] DEFAULT '{}'::text[] NOT NULL,
    confidence integer,
    verified boolean DEFAULT false NOT NULL,
    visibility public.tree_visibility DEFAULT 'public'::public.tree_visibility NOT NULL,
    is_fuzzy boolean DEFAULT true NOT NULL,
    fuzzy_geom public.geography(Point,4326) NOT NULL,
    status public.tree_status DEFAULT 'active'::public.tree_status NOT NULL,
    like_count integer DEFAULT 0 NOT NULL,
    comment_count integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    client_tx_id text,
    CONSTRAINT trees_confidence_check CHECK (((confidence >= 0) AND (confidence <= 100)))
);


ALTER TABLE public.trees OWNER TO postgres;

--
-- Name: updates; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.updates (
    id bigint NOT NULL,
    app_version text NOT NULL,
    link text NOT NULL,
    release_notes text DEFAULT ''::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.updates OWNER TO postgres;

--
-- Name: updates_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.updates ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.updates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: user_badges; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_badges (
    user_id uuid NOT NULL,
    badge_id uuid NOT NULL,
    awarded_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.user_badges OWNER TO postgres;

--
-- Name: user_blocks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_blocks (
    blocker_id uuid NOT NULL,
    blocked_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT no_self_block CHECK ((blocker_id <> blocked_id))
);


ALTER TABLE public.user_blocks OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email public.citext NOT NULL,
    username public.citext NOT NULL,
    password_hash text NOT NULL,
    display_name text NOT NULL,
    bio text,
    avatar_url text,
    role public.user_role DEFAULT 'user'::public.user_role NOT NULL,
    birth_year integer,
    is_13_plus boolean DEFAULT true NOT NULL,
    location_label text,
    points integer DEFAULT 0 NOT NULL,
    level integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT users_min_age CHECK ((is_13_plus = true))
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Data for Name: account_deletion_requests; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.account_deletion_requests (id, user_id, status, requested_at, purge_after, completed_at) FROM stdin;
\.


--
-- Data for Name: activity; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.activity (id, actor_id, verb, object_type, object_id, metadata, created_at) FROM stdin;
1	3fd350cc-4898-404d-b560-d168f93b26cc	logged_tree	tree	af99d0e5-5bcd-4fe3-b017-d158bee037e6	{}	2026-07-09 22:53:07.045568+00
2	3fd350cc-4898-404d-b560-d168f93b26cc	earned_badge	badge	1f68e874-0eb8-4765-931c-365b50ce7c0a	{"code": "first_sprout", "name": "First Sprout"}	2026-07-09 23:07:15.925261+00
35	3fd350cc-4898-404d-b560-d168f93b26cc	logged_tree	tree	2656ccae-e8cd-411f-b20e-38810df6e249	{}	2026-07-09 23:11:02.476607+00
36	3fd350cc-4898-404d-b560-d168f93b26cc	logged_tree	tree	63dd6ebb-cd9d-47b7-ac11-46b53ac5be45	{}	2026-07-09 23:12:34.677936+00
37	3fd350cc-4898-404d-b560-d168f93b26cc	logged_tree	tree	297b527b-5091-4286-b392-4418400e6a8d	{}	2026-07-09 23:17:39.580593+00
38	9a2cd4f4-507c-43a9-bd35-f6317139ae25	logged_tree	tree	4421ad45-b3fd-4532-a7f7-4e7f3668e0b5	{}	2026-07-09 23:37:51.892645+00
39	9a2cd4f4-507c-43a9-bd35-f6317139ae25	earned_badge	badge	1f68e874-0eb8-4765-931c-365b50ce7c0a	{"code": "first_sprout", "name": "First Sprout"}	2026-07-09 23:40:20.19451+00
40	9a2cd4f4-507c-43a9-bd35-f6317139ae25	logged_tree	tree	a997f249-92aa-4ca9-a9e8-1f02d4346d59	{}	2026-07-09 23:43:26.216828+00
41	9a2cd4f4-507c-43a9-bd35-f6317139ae25	logged_tree	tree	e867cf62-071d-4c28-8ffd-3035af7b9460	{}	2026-07-09 23:44:18.641059+00
42	3fd350cc-4898-404d-b560-d168f93b26cc	logged_tree	tree	e8f565d8-ccb2-4f4c-a626-48d01970fa8f	{}	2026-07-13 09:01:18.950285+00
\.


--
-- Data for Name: api_keys; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.api_keys (id, user_id, name, key_hash, scopes, created_at, revoked_at, last_used) FROM stdin;
\.


--
-- Data for Name: audit_log; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.audit_log (id, actor_id, action, entity, entity_id, ip, user_agent, metadata, created_at) FROM stdin;
\.


--
-- Data for Name: badges; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.badges (id, code, name, description, icon, criteria) FROM stdin;
1f68e874-0eb8-4765-931c-365b50ce7c0a	first_sprout	First Sprout	Logged your first tree.	eco	{"gte": 1, "metric": "tree_count"}
57d42081-b036-4b86-a8f0-ef965588922a	explorer_25	Explorer 25	Logged 25 trees.	explore	{"gte": 25, "metric": "tree_count"}
1f18d167-63e8-4857-b9f3-e235fd86d435	oak_keeper	Oak Keeper	Logged 10 oaks.	star	{"gte": 10, "genus": "Quercus", "metric": "genus_count"}
c3325334-9e9f-4143-8fb0-8c67f3d541f9	verifier	Verifier	Verified 10 community IDs.	verified	{"gte": 10, "metric": "verifications"}
aa332fc0-ec22-4503-a9a0-2f6a3f990b63	rare_finder	Rare Finder	Logged a rare or notable species.	lock	{"gte": 1, "metric": "rare_count"}
eaeb3f04-ec9c-4008-b7ed-3f0f4a3fdabc	century_club	100 Club	Logged 100 trees.	lock	{"gte": 100, "metric": "tree_count"}
\.


--
-- Data for Name: comments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.comments (id, tree_id, author_id, body, status, created_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: consents; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.consents (id, user_id, kind, version, granted, created_at) FROM stdin;
03e4ca32-8260-4011-9ec4-0598ada06433	3fd350cc-4898-404d-b560-d168f93b26cc	tos	2026-05	t	2026-07-08 15:58:19.285128+00
9165ddd6-6103-4f3f-a2c8-f80a104db18a	3fd350cc-4898-404d-b560-d168f93b26cc	privacy	2026-05	t	2026-07-08 15:58:19.285128+00
6d2ab106-5fed-46c7-a5d6-81e875a61bdc	9a2cd4f4-507c-43a9-bd35-f6317139ae25	tos	2026-05	t	2026-07-09 23:37:47.380853+00
2f240a02-a684-45a3-980f-2762b67c4568	9a2cd4f4-507c-43a9-bd35-f6317139ae25	privacy	2026-05	t	2026-07-09 23:37:47.380853+00
366ef1e5-6358-49ad-9439-39f12b3d851c	4fed3221-815b-4b7a-8a3b-f817f5271e48	tos	2026-05	t	2026-09-26 14:40:48.554319+00
35135204-93f5-47b6-8616-237f7a4a36cd	4fed3221-815b-4b7a-8a3b-f817f5271e48	privacy	2026-05	t	2026-09-26 14:40:48.554319+00
\.


--
-- Data for Name: data_export_jobs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.data_export_jobs (id, user_id, format, status, file_key, download_url, requested_at, completed_at, expires_at) FROM stdin;
\.


--
-- Data for Name: follows; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.follows (follower_id, followee_id, created_at) FROM stdin;
\.


--
-- Data for Name: likes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.likes (tree_id, user_id, created_at) FROM stdin;
\.


--
-- Data for Name: moderation_actions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.moderation_actions (id, moderator_id, report_id, target_type, target_id, action, notes, created_at) FROM stdin;
\.


--
-- Data for Name: points_ledger; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.points_ledger (id, user_id, delta, reason, tree_id, created_at) FROM stdin;
1	3fd350cc-4898-404d-b560-d168f93b26cc	10	log_tree	af99d0e5-5bcd-4fe3-b017-d158bee037e6	2026-07-09 22:53:07.045568+00
2	3fd350cc-4898-404d-b560-d168f93b26cc	10	log_tree	2656ccae-e8cd-411f-b20e-38810df6e249	2026-07-09 23:11:02.476607+00
3	3fd350cc-4898-404d-b560-d168f93b26cc	10	log_tree	63dd6ebb-cd9d-47b7-ac11-46b53ac5be45	2026-07-09 23:12:34.677936+00
4	3fd350cc-4898-404d-b560-d168f93b26cc	10	log_tree	297b527b-5091-4286-b392-4418400e6a8d	2026-07-09 23:17:39.580593+00
5	9a2cd4f4-507c-43a9-bd35-f6317139ae25	10	log_tree	4421ad45-b3fd-4532-a7f7-4e7f3668e0b5	2026-07-09 23:37:51.892645+00
6	9a2cd4f4-507c-43a9-bd35-f6317139ae25	10	log_tree	a997f249-92aa-4ca9-a9e8-1f02d4346d59	2026-07-09 23:43:26.216828+00
7	9a2cd4f4-507c-43a9-bd35-f6317139ae25	10	log_tree	e867cf62-071d-4c28-8ffd-3035af7b9460	2026-07-09 23:44:18.641059+00
8	3fd350cc-4898-404d-b560-d168f93b26cc	10	log_tree	e8f565d8-ccb2-4f4c-a626-48d01970fa8f	2026-07-13 09:01:18.950285+00
\.


--
-- Data for Name: rate_limit_counters; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.rate_limit_counters (bucket, route, window_start, count) FROM stdin;
\.


--
-- Data for Name: refresh_tokens; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.refresh_tokens (id, user_id, token_hash, user_agent, ip, expires_at, revoked_at, created_at) FROM stdin;
aaf1bc21-0274-4877-b9c1-871a8ff3010d	3fd350cc-4898-404d-b560-d168f93b26cc	40d8b22da3d3857f45774767405afedce04fb18bf07acc397b874d9c663594d5	Dart/3.11 (dart:io)	192.168.65.1	2026-08-07 15:58:19.285128+00	2026-07-09 10:49:58.091471+00	2026-07-08 15:58:19.285128+00
07b1de31-0c1f-4200-9016-94a8789ae4fd	3fd350cc-4898-404d-b560-d168f93b26cc	f33e3a48df96051c2a0014baac9e8d4242c70de9cf417954290e5fd33e5789bb	Dart/3.11 (dart:io)	192.168.65.1	2026-08-08 11:13:59.443414+00	2026-07-09 11:14:08.078882+00	2026-07-09 11:13:59.443414+00
ef5e71b1-16fc-43d9-8344-5f594c1464a0	3fd350cc-4898-404d-b560-d168f93b26cc	9240775748b2fd8adce90352fb2ed60581c72ebb93bf2de2a4d3c23b3ac77d25	Dart/3.11 (dart:io)	192.168.65.1	2026-08-08 11:50:15.867545+00	2026-07-09 11:51:06.058578+00	2026-07-09 11:50:15.867545+00
5dcff2e4-d350-4f61-94fb-c93eaea7d897	3fd350cc-4898-404d-b560-d168f93b26cc	f29163493eac67aa9c48e4461ea8d528ebfe9071ae795d7b17c8f5c3ebe35e26	Dart/3.11 (dart:io)	192.168.65.1	2026-08-08 11:52:02.333298+00	2026-07-09 11:52:50.350719+00	2026-07-09 11:52:02.333298+00
4f2beded-d744-4ccb-bd31-33b07b79cba0	3fd350cc-4898-404d-b560-d168f93b26cc	0691785016fce47095f6a6df0f2fe88b01b99ec8929737eb5a49b8bdebfd0ba0	Dart/3.11 (dart:io)	192.168.65.1	2026-08-08 12:59:42.058046+00	2026-07-09 13:30:06.315378+00	2026-07-09 12:59:42.058046+00
8789a9a9-3625-4f4b-96e6-2d57ffc1d7a5	3fd350cc-4898-404d-b560-d168f93b26cc	2e84fcdc9f721204e14d13e1324597f3528614a92247fce86f8c025b6a99e87e	Dart/3.11 (dart:io)	192.168.65.1	2026-08-08 13:30:06.315378+00	2026-07-09 13:45:06.331267+00	2026-07-09 13:30:06.315378+00
bfe51da3-1ef4-4b93-ae99-b778ea407f1d	3fd350cc-4898-404d-b560-d168f93b26cc	122507d87f081aa21240487fefc7db214bfcdf5aefc221421422a611e92d52cd	Dart/3.11 (dart:io)	192.168.65.1	2026-08-08 13:45:06.331267+00	2026-07-09 14:00:56.798494+00	2026-07-09 13:45:06.331267+00
d5f5e8fc-8d5a-45e0-a74e-5fcfae227581	3fd350cc-4898-404d-b560-d168f93b26cc	6c5699f1b31af96bcf6b164eb942e77ce9ffb0c04134a6336a416ab40823d289	Dart/3.11 (dart:io)	192.168.65.1	2026-08-08 14:00:56.798494+00	2026-07-09 14:28:01.943218+00	2026-07-09 14:00:56.798494+00
203f8bba-0a00-42ac-a35a-c893b5d8c134	3fd350cc-4898-404d-b560-d168f93b26cc	26713c2fc192ee5e502e391559df473542c93ecaca6418f8d4ea8ca9dd9a825a	Dart/3.11 (dart:io)	192.168.65.1	2026-08-08 14:28:01.943218+00	2026-07-09 14:46:55.104378+00	2026-07-09 14:28:01.943218+00
eab5dedc-2691-455d-91bb-1c4a384be9f0	3fd350cc-4898-404d-b560-d168f93b26cc	15283ba65457fae055e3a12ee27e1d4f47c47920de7ba9a983801518acce0b89	Dart/3.11 (dart:io)	192.168.65.1	2026-08-08 14:46:55.104378+00	2026-07-09 15:22:32.259942+00	2026-07-09 14:46:55.104378+00
66b12b92-d5ff-4551-9eb2-7bb3b3f06b6c	3fd350cc-4898-404d-b560-d168f93b26cc	222bf60ebbc2760c3e58f9aa5703bf80be31cbc8f001706f9634ec978c6f7391	Dart/3.11 (dart:io)	192.168.65.1	2026-08-08 15:22:32.259942+00	2026-07-09 21:12:47.650157+00	2026-07-09 15:22:32.259942+00
5e227be8-909e-407e-a1b6-b68172ff748b	3fd350cc-4898-404d-b560-d168f93b26cc	5824dfed4eed3517d4e4193ccd79f61c63b6de7f59950045c3200de0e2554d59	Dart/3.11 (dart:io)	192.168.65.1	2026-08-08 21:12:47.650157+00	2026-07-09 21:45:20.931358+00	2026-07-09 21:12:47.650157+00
d8286f29-641e-4dd1-8530-0d47bc7c8daf	3fd350cc-4898-404d-b560-d168f93b26cc	ee8b683917ef491ef38080148b1fa719afb232131c27a39849e7cc30ce6a7605	Dart/3.11 (dart:io)	192.168.65.1	2026-08-08 21:45:20.931358+00	2026-07-09 22:01:10.854961+00	2026-07-09 21:45:20.931358+00
e6e17cb5-0f67-40ef-baca-985cfe313982	3fd350cc-4898-404d-b560-d168f93b26cc	a698bce4fdb65bc923089d99b20ca0ca541464291d311f9b52daa734e019289c	Dart/3.11 (dart:io)	192.168.65.1	2026-08-08 22:51:10.755824+00	2026-07-09 23:11:02.401417+00	2026-07-09 22:51:10.755824+00
b53ffce4-2871-46ae-b716-d935f96dff42	3fd350cc-4898-404d-b560-d168f93b26cc	333ba4400aeb4347c4ea8126dbabe43191b601db7e1a31de6838278ef1c348a5	Dart/3.11 (dart:io)	192.168.65.1	2026-08-08 23:11:02.488164+00	\N	2026-07-09 23:11:02.488164+00
17dcd48a-7cb6-4330-9eaa-442353c2a007	3fd350cc-4898-404d-b560-d168f93b26cc	6c9c4a7f48d108557aa6485a2e9f6a0c8f6d8ceac00d5217f683e155f6527930	Dart/3.11 (dart:io)	192.168.65.1	2026-08-08 23:11:02.401417+00	2026-07-09 23:11:02.492425+00	2026-07-09 23:11:02.401417+00
1dd477ce-5583-4a8c-a7d6-454785eb4f69	3fd350cc-4898-404d-b560-d168f93b26cc	51b74d8f851643884cdbf366b3ee4655df4970ea790d0805b86749549533efb8	Dart/3.11 (dart:io)	192.168.65.1	2026-08-08 23:11:02.492425+00	\N	2026-07-09 23:11:02.492425+00
7a15446e-c367-4494-8b9e-a4aac82799c7	3fd350cc-4898-404d-b560-d168f93b26cc	87d4998fa17870d7ca9230439367768c3656f33259dfb172b847f73094838a6f	Dart/3.11 (dart:io)	192.168.65.1	2026-08-08 22:01:10.854961+00	2026-07-09 23:24:33.979427+00	2026-07-09 22:01:10.854961+00
d0ab14d2-24a4-4ba8-bd94-b4d3c6c28183	9a2cd4f4-507c-43a9-bd35-f6317139ae25	ce2ea63596c711213bbdd80bb869f510c1f4d2d500dd10b8ea611fc3fcaf1b18	curl/8.7.1	192.168.65.1	2026-08-08 23:37:47.380853+00	\N	2026-07-09 23:37:47.380853+00
b45de2b6-53b6-4bf3-b3da-487f2843e0b0	9a2cd4f4-507c-43a9-bd35-f6317139ae25	8e6b32ab003e0fe2ecf1b937dbabec58233d5901285c09256e7c2ff0bf027b2d	curl/8.7.1	192.168.65.1	2026-08-08 23:43:20.57301+00	\N	2026-07-09 23:43:20.57301+00
2a931c78-194b-45c9-bfa6-c9a07065d6e6	9a2cd4f4-507c-43a9-bd35-f6317139ae25	f405a2d8270e6cf14ba8b0f59ce247f913ff2af1631c01505d6d18a2651db5a1	curl/8.7.1	192.168.65.1	2026-08-08 23:44:14.428301+00	\N	2026-07-09 23:44:14.428301+00
5d83fbac-43ca-4f73-9a24-bda9915953f6	3fd350cc-4898-404d-b560-d168f93b26cc	e9d5f62e65529a1831b426e367f302658caa5d573ff9a475d54a181cefcbaa07	Dart/3.11 (dart:io)	192.168.65.1	2026-08-08 23:24:33.979427+00	2026-07-09 23:46:28.922068+00	2026-07-09 23:24:33.979427+00
1fd5c4bc-8f10-40aa-a789-978f278ba209	3fd350cc-4898-404d-b560-d168f93b26cc	0a43562a067f3453103f209e97b1264ab96fbfcb920f301361724b8e445164da	Dart/3.11 (dart:io)	192.168.65.1	2026-08-08 23:46:28.922068+00	2026-07-10 00:03:32.105336+00	2026-07-09 23:46:28.922068+00
2f5c629c-b241-426a-8421-6e616a1d7b3d	3fd350cc-4898-404d-b560-d168f93b26cc	01747caa58a9cea52d9c5a1819b809ee3e0f8edd6d79c072cb632cc307659758	Dart/3.11 (dart:io)	192.168.65.1	2026-08-09 00:03:32.105336+00	2026-07-10 00:33:27.654215+00	2026-07-10 00:03:32.105336+00
af2930ad-62f5-4e5c-bf90-09bb44dc927a	3fd350cc-4898-404d-b560-d168f93b26cc	5feb15ef1d3e3795c08ee6b45c695ed5b9dba4a0176851ee4b2fb071da3d3eee	Dart/3.11 (dart:io)	192.168.65.1	2026-08-09 00:33:27.654215+00	2026-07-10 00:49:55.197425+00	2026-07-10 00:33:27.654215+00
2dbe7720-7606-40ff-bf68-acafb65e43bb	3fd350cc-4898-404d-b560-d168f93b26cc	dfb078cf85ede4436ec81e2595c65a429d73c86631060289a042e308f97dac77	Dart/3.11 (dart:io)	192.168.65.1	2026-08-09 00:49:55.197425+00	2026-07-10 01:26:20.424911+00	2026-07-10 00:49:55.197425+00
f49bc8d4-7c87-46ab-8c7f-ed2d610daa7d	3fd350cc-4898-404d-b560-d168f93b26cc	4a14e7887070d4c8a36a741317834064f0ac919a26b38945f6d48b539b92b322	Dart/3.11 (dart:io)	192.168.65.1	2026-08-09 01:26:20.424911+00	2026-07-13 08:03:47.078637+00	2026-07-10 01:26:20.424911+00
494737c4-0cc1-4877-b8b5-468c47235b86	3fd350cc-4898-404d-b560-d168f93b26cc	c8994f6817519f142b03305ef38bf9eeeecc4742bba0f229bf2439f2e5e39ad6	Dart/3.11 (dart:io)	192.168.65.1	2026-08-12 08:03:47.078637+00	2026-07-13 08:22:40.183502+00	2026-07-13 08:03:47.078637+00
195ffc4c-883a-46a2-9a36-3a9ff93330bf	3fd350cc-4898-404d-b560-d168f93b26cc	b0a192628ad1fd72289f3d63ddd1349cb33d1f393245c2ee90f6854668d640a8	Dart/3.11 (dart:io)	192.168.65.1	2026-08-12 08:22:40.183502+00	2026-07-13 08:49:39.280695+00	2026-07-13 08:22:40.183502+00
f8e611c9-caee-4244-8f1a-f5551d25f5fd	3fd350cc-4898-404d-b560-d168f93b26cc	bef11866a4c325efb4ea6a569ed1e4533198c3fdef1150df6c30cd335c0cf779	Dart/3.11 (dart:io)	192.168.65.1	2026-08-12 08:49:39.280695+00	2026-07-13 09:24:53.08198+00	2026-07-13 08:49:39.280695+00
603bae02-3218-4669-a8c1-7b7358153900	3fd350cc-4898-404d-b560-d168f93b26cc	1d068e0f781aafe1cae61fdbce34cad626835188e80203be85363824bb4043e1	Dart/3.11 (dart:io)	192.168.65.1	2026-08-12 09:24:53.08198+00	2026-07-13 10:11:24.81343+00	2026-07-13 09:24:53.08198+00
68eb2fe0-7f84-4c66-b4cf-3b60d2a911e6	3fd350cc-4898-404d-b560-d168f93b26cc	85c6844a944a540838a28f820544da569208d774974fc030e1006869e5a0a047	Dart/3.11 (dart:io)	192.168.65.1	2026-08-12 10:11:24.81343+00	2026-07-13 10:11:47.820089+00	2026-07-13 10:11:24.81343+00
7740fda1-18bf-4bad-b1ae-29949aec34d1	3fd350cc-4898-404d-b560-d168f93b26cc	db42433b8246b43bf8bad84a3e8c2f15d9d6ae4d29ab46dbc7a6108c5727b870	Dart/3.11 (dart:io)	192.168.65.1	2026-08-12 10:28:27.980752+00	2026-07-13 10:29:34.172874+00	2026-07-13 10:28:27.980752+00
05ca09a5-5fa6-451c-9760-e65049cffec7	3fd350cc-4898-404d-b560-d168f93b26cc	efdbdab544d4335cbfab4d28922d3f31fc5b21c8ffce99b89bbe019894a1c04f	Dart/3.11 (dart:io)	192.168.65.1	2026-08-12 10:33:55.512153+00	2026-07-13 10:37:43.531602+00	2026-07-13 10:33:55.512153+00
6c7227bf-6ec6-4786-9fd0-9c0e6e339402	4fed3221-815b-4b7a-8a3b-f817f5271e48	0d5acef3d696151991b105b8591ffacd23aecb9ecd7d7cbadec4d1811ba580fa	Dart/3.12 (dart:io)	192.168.65.1	2026-10-26 14:40:48.554319+00	2026-09-26 14:57:08.052559+00	2026-09-26 14:40:48.554319+00
eb0db591-3959-4949-8d35-5a4207b24bda	4fed3221-815b-4b7a-8a3b-f817f5271e48	5126d5ab5d7f890d2f3da5d88aa2c46bf8b29272aa429e22e9d50d5b4339c24f	Dart/3.12 (dart:io)	192.168.65.1	2026-10-26 14:57:08.052559+00	2026-09-26 14:59:30.441065+00	2026-09-26 14:57:08.052559+00
08be6212-638c-4f62-a180-c0ba63aa2975	4fed3221-815b-4b7a-8a3b-f817f5271e48	83d4ca168f5d1b77c7ce7f03196906699c1a36ca295914f21f2589a4b5250e3c	Dart/3.12 (dart:io)	192.168.65.1	2026-10-26 15:54:16.475737+00	2026-09-26 16:16:37.345359+00	2026-09-26 15:54:16.475737+00
75e96af4-ab64-4aed-8e48-1349c510c1d6	4fed3221-815b-4b7a-8a3b-f817f5271e48	b51ceeb4be6ea6d826a89930003ad655aa1d4e607eb71381dd2cdc4ee87bd5a7	Dart/3.12 (dart:io)	192.168.65.1	2026-10-26 16:16:37.345359+00	2026-09-26 16:40:01.106812+00	2026-09-26 16:16:37.345359+00
7056a6e7-24a0-4461-8d2e-6bb3122bd426	4fed3221-815b-4b7a-8a3b-f817f5271e48	8c4a7d83ff36fb2c49cb8c49af3b11da1507a4d2297c6e57d9743581b3c7b55f	Dart/3.12 (dart:io)	192.168.65.1	2026-10-26 16:40:01.106812+00	2026-09-26 16:57:08.879902+00	2026-09-26 16:40:01.106812+00
f12a9359-f683-44be-9997-60be641190e9	4fed3221-815b-4b7a-8a3b-f817f5271e48	146cb68b905f8a019dd964b3f7576e3f7c43a8097b4f957188b307137899da30	Dart/3.12 (dart:io)	192.168.65.1	2026-10-26 16:57:08.879902+00	2026-09-27 10:31:46.758003+00	2026-09-26 16:57:08.879902+00
f8d79204-89be-4cf2-96ec-cbddfeabbd33	4fed3221-815b-4b7a-8a3b-f817f5271e48	3251f8ab83616a91a0d6eeaedfd78d3d63c78d64118bae463fad462ff95d17b8	Dart/3.12 (dart:io)	172.18.0.1	2026-10-27 10:31:46.758003+00	2026-09-27 10:48:58.491808+00	2026-09-27 10:31:46.758003+00
aaf16b3c-8d58-4292-b54a-8d391fbdf593	4fed3221-815b-4b7a-8a3b-f817f5271e48	dc9913f05cf8812f94b3244d966350b0bae27911e256f05ae253f5f2a42360ba	Dart/3.12 (dart:io)	172.18.0.1	2026-10-27 10:48:58.491808+00	2026-09-27 10:48:59.224916+00	2026-09-27 10:48:58.491808+00
0beeb99f-d1fa-4b4d-8c4f-6f4c526468f4	4fed3221-815b-4b7a-8a3b-f817f5271e48	9f5fcb9b5db5be41509a6c14ea2a6dc3efa97b233a317012c48e3f2632de6a91	Dart/3.12 (dart:io)	172.18.0.1	2026-10-27 10:48:59.224916+00	\N	2026-09-27 10:48:59.224916+00
\.


--
-- Data for Name: reports; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.reports (id, reporter_id, target_type, target_id, reason, details, status, created_at, resolved_at, resolver_id) FROM stdin;
\.


--
-- Data for Name: saved_trees; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.saved_trees (user_id, tree_id, created_at) FROM stdin;
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.schema_migrations (name, applied_at) FROM stdin;
001_extensions.sql	2026-07-08 15:16:03.779649+00
002_core.sql	2026-07-08 15:16:04.276779+00
003_location_privacy.sql	2026-07-08 15:16:04.609095+00
004_social.sql	2026-07-08 15:16:04.66399+00
005_gamification.sql	2026-07-08 15:16:04.790111+00
006_moderation.sql	2026-07-08 15:16:04.948839+00
007_privacy_gdpr.sql	2026-07-08 15:16:05.063292+00
008_rate_limit.sql	2026-07-08 15:16:05.436927+00
009_rls_policies.sql	2026-07-08 15:16:05.492716+00
010_seed.sql	2026-07-08 15:16:05.806488+00
011_saved_trees.sql	2026-07-09 21:08:11.906575+00
012_tree_verifications.sql	2026-07-09 22:31:11.386342+00
013_idempotency.sql	2026-09-26 13:34:36.626389+00
014_app_updates.sql	2026-09-26 13:34:36.654644+00
\.


--
-- Data for Name: spatial_ref_sys; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.spatial_ref_sys (srid, auth_name, auth_srid, srtext, proj4text) FROM stdin;
\.


--
-- Data for Name: species; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.species (id, common_name, scientific_name, family, native_range, description, gbif_id, created_at) FROM stdin;
8f1c0970-9cab-4d02-8875-202afb5d790e	English Oak	Quercus robur	Fagaceae	Europe, W. Asia	Long-lived deciduous oak supporting more wildlife than almost any other native tree.	\N	2026-07-08 15:16:05.806488+00
301a66cf-1052-49ef-918c-ce1673d37386	Sugar Maple	Acer saccharum	Sapindaceae	Eastern North America	Famed for autumn colour and maple syrup.	\N	2026-07-08 15:16:05.806488+00
77509e68-98aa-4dfb-9f6d-fc513b3971e6	Eastern White Pine	Pinus strobus	Pinaceae	Eastern North America	Tall conifer with soft needles in bundles of five.	\N	2026-07-08 15:16:05.806488+00
152f50db-3880-4071-952d-e6b2e94f4a47	Silver Birch	Betula pendula	Betulaceae	Europe, Asia	Graceful birch with peeling white bark.	\N	2026-07-08 15:16:05.806488+00
19aa9c78-783b-4cc6-a106-448e54508719	Jacaranda	Jacaranda mimosifolia	Bignoniaceae	South America	Ornamental tree with vivid purple spring blooms.	\N	2026-07-08 15:16:05.806488+00
6ca0c307-9f3b-424b-a25a-8cff2b9ebc4e	Japanese Cherry	Prunus serrulata	Rosaceae	Japan, China, Korea	Ornamental cherry celebrated for spring blossom.	\N	2026-07-08 15:16:05.806488+00
04f6a9f6-f857-4e78-b706-d6bed9f8da1f	Weeping Willow	Salix babylonica	Salicaceae	China	Fast-growing willow with trailing branches, often by water.	\N	2026-07-08 15:16:05.806488+00
\.


--
-- Data for Name: tree_exact_locations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tree_exact_locations (tree_id, exact_geom, accuracy_m, captured_at) FROM stdin;
af99d0e5-5bcd-4fe3-b017-d158bee037e6	0101000020E6100000ED86C844A5434040C2DD59BBED42BD3F	\N	2026-07-09 22:53:07.045568+00
2656ccae-e8cd-411f-b20e-38810df6e249	0101000020E6100000ED86C844A5434040C2DD59BBED42BD3F	\N	2026-07-09 23:11:02.476607+00
63dd6ebb-cd9d-47b7-ac11-46b53ac5be45	0101000020E610000014C6BBC8A9434040F5238FF17222BD3F	\N	2026-07-09 23:12:34.677936+00
297b527b-5091-4286-b392-4418400e6a8d	0101000020E61000008A7A1C61AC4340401BB4FC659C2BBD3F	\N	2026-07-09 23:17:39.580593+00
4421ad45-b3fd-4532-a7f7-4e7f3668e0b5	0101000020E6100000B81E85EB51D853C03333333333D34540	\N	2026-07-09 23:37:51.892645+00
a997f249-92aa-4ca9-a9e8-1f02d4346d59	0101000020E6100000B81E85EB51D853C03333333333D34540	\N	2026-07-09 23:43:26.216828+00
e867cf62-071d-4c28-8ffd-3035af7b9460	0101000020E6100000B81E85EB51D853C03333333333D34540	\N	2026-07-09 23:44:18.641059+00
e8f565d8-ccb2-4f4c-a626-48d01970fa8f	0101000020E61000004C37894160855EC0DABB500A04B64240	\N	2026-07-13 09:01:18.950285+00
\.


--
-- Data for Name: tree_photos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tree_photos (id, tree_id, organ, storage_key, public_url, thumb_url, width, height, exif_stripped, status, "position", created_at) FROM stdin;
ccd63b08-7397-4f1e-bbe7-7a5eb7a8ab8b	e867cf62-071d-4c28-8ffd-3035af7b9460	leaf	uploads/9a2cd4f4-507c-43a9-bd35-f6317139ae25/e867cf62-071d-4c28-8ffd-3035af7b9460/4967099f-9501-400f-9a40-a0e3e03c3e05.jpg	public/9a2cd4f4-507c-43a9-bd35-f6317139ae25/e867cf62-071d-4c28-8ffd-3035af7b9460/4967099f-9501-400f-9a40-a0e3e03c3e05_1080.jpg	public/9a2cd4f4-507c-43a9-bd35-f6317139ae25/e867cf62-071d-4c28-8ffd-3035af7b9460/4967099f-9501-400f-9a40-a0e3e03c3e05_480.jpg	100	100	t	processed	0	2026-07-09 23:44:18.641059+00
fd27a2e3-0837-48d8-b375-937eb5f1bea6	a997f249-92aa-4ca9-a9e8-1f02d4346d59	leaf	uploads/9a2cd4f4-507c-43a9-bd35-f6317139ae25/a997f249-92aa-4ca9-a9e8-1f02d4346d59/e2cd2330-9d65-4d45-abe9-5f3c12313b7e.jpg	\N	\N	\N	\N	f	failed	0	2026-07-09 23:43:26.216828+00
1f5781df-80a7-4cdd-8437-4cdee7c4be4a	af99d0e5-5bcd-4fe3-b017-d158bee037e6	whole	uploads/3fd350cc-4898-404d-b560-d168f93b26cc/af99d0e5-5bcd-4fe3-b017-d158bee037e6/fb8d32f6-09db-4958-b398-50ad9da8acb5.jpg	\N	\N	\N	\N	f	failed	0	2026-07-09 22:53:07.045568+00
5e43043b-38a8-4118-b3b9-2561f3243372	2656ccae-e8cd-411f-b20e-38810df6e249	whole	uploads/3fd350cc-4898-404d-b560-d168f93b26cc/2656ccae-e8cd-411f-b20e-38810df6e249/734963ab-7bda-448e-99e3-126849685f3a.jpg	\N	\N	\N	\N	f	failed	0	2026-07-09 23:11:02.476607+00
4cde88ce-6cca-4d5e-ab33-b2ed1e7dd15f	63dd6ebb-cd9d-47b7-ac11-46b53ac5be45	whole	uploads/3fd350cc-4898-404d-b560-d168f93b26cc/63dd6ebb-cd9d-47b7-ac11-46b53ac5be45/75b280f7-e0bb-4ca7-b493-fa327fb5e17a.jpg	\N	\N	\N	\N	f	failed	0	2026-07-09 23:12:34.677936+00
f63a7ffb-2d56-477e-b0c8-73c76297eb55	297b527b-5091-4286-b392-4418400e6a8d	whole	uploads/3fd350cc-4898-404d-b560-d168f93b26cc/297b527b-5091-4286-b392-4418400e6a8d/a02007a3-dddf-4052-ab40-c80e847c35c0.jpg	\N	\N	\N	\N	f	failed	0	2026-07-09 23:17:39.580593+00
793e23c2-e788-4a0f-867d-f784368e473d	4421ad45-b3fd-4532-a7f7-4e7f3668e0b5	leaf	uploads/9a2cd4f4-507c-43a9-bd35-f6317139ae25/4421ad45-b3fd-4532-a7f7-4e7f3668e0b5/debae3a8-22ee-4221-8e5e-54dfe2da2ec7.jpg	\N	\N	\N	\N	f	failed	0	2026-07-09 23:37:51.892645+00
e2c0dd22-fb1b-474f-a793-4325e9fafdbd	e8f565d8-ccb2-4f4c-a626-48d01970fa8f	whole	uploads/3fd350cc-4898-404d-b560-d168f93b26cc/e8f565d8-ccb2-4f4c-a626-48d01970fa8f/f481277f-73e8-4b23-a186-f18ef4e21a40.jpg	public/3fd350cc-4898-404d-b560-d168f93b26cc/e8f565d8-ccb2-4f4c-a626-48d01970fa8f/f481277f-73e8-4b23-a186-f18ef4e21a40_1080.jpg	public/3fd350cc-4898-404d-b560-d168f93b26cc/e8f565d8-ccb2-4f4c-a626-48d01970fa8f/f481277f-73e8-4b23-a186-f18ef4e21a40_480.jpg	1080	810	t	processed	0	2026-07-13 09:01:18.950285+00
23ccb8f3-237d-48ba-a1c9-fda7c931601e	e8f565d8-ccb2-4f4c-a626-48d01970fa8f	bark	uploads/3fd350cc-4898-404d-b560-d168f93b26cc/e8f565d8-ccb2-4f4c-a626-48d01970fa8f/d9e60f16-15cc-4d0e-8d54-82e9cdae129e.jpg	public/3fd350cc-4898-404d-b560-d168f93b26cc/e8f565d8-ccb2-4f4c-a626-48d01970fa8f/d9e60f16-15cc-4d0e-8d54-82e9cdae129e_1080.jpg	public/3fd350cc-4898-404d-b560-d168f93b26cc/e8f565d8-ccb2-4f4c-a626-48d01970fa8f/d9e60f16-15cc-4d0e-8d54-82e9cdae129e_480.jpg	1080	810	t	processed	1	2026-07-13 09:01:18.950285+00
1ba73011-e4b8-4e2c-a51e-852a5d174637	e8f565d8-ccb2-4f4c-a626-48d01970fa8f	leaf	uploads/3fd350cc-4898-404d-b560-d168f93b26cc/e8f565d8-ccb2-4f4c-a626-48d01970fa8f/22965f65-0be5-471b-b9a2-2899a760bf04.jpg	public/3fd350cc-4898-404d-b560-d168f93b26cc/e8f565d8-ccb2-4f4c-a626-48d01970fa8f/22965f65-0be5-471b-b9a2-2899a760bf04_1080.jpg	public/3fd350cc-4898-404d-b560-d168f93b26cc/e8f565d8-ccb2-4f4c-a626-48d01970fa8f/22965f65-0be5-471b-b9a2-2899a760bf04_480.jpg	1080	810	t	processed	2	2026-07-13 09:01:18.950285+00
\.


--
-- Data for Name: tree_verifications; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tree_verifications (tree_id, user_id, created_at) FROM stdin;
\.


--
-- Data for Name: trees; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.trees (id, owner_id, species_id, common_name, scientific_name, height_m, girth_m, age_estimate, health, description, features, confidence, verified, visibility, is_fuzzy, fuzzy_geom, status, like_count, comment_count, created_at, updated_at, deleted_at, client_tx_id) FROM stdin;
af99d0e5-5bcd-4fe3-b017-d158bee037e6	3fd350cc-4898-404d-b560-d168f93b26cc	\N	English Oak	Quercus robur	12.0	\N	\N	healthy	here	{Hollow}	97	f	public	t	0101000020E61000006508F0CF6E434040A8EF7DAC2D34BD3F	active	0	0	2026-07-09 22:53:07.045568+00	2026-07-09 22:53:07.045568+00	\N	\N
2656ccae-e8cd-411f-b20e-38810df6e249	3fd350cc-4898-404d-b560-d168f93b26cc	\N	English Oak	Quercus robur	12.0	\N	\N	healthy	here	{Hollow}	97	f	public	t	0101000020E6100000970314F7924340409E30E3DD8A3BBD3F	active	0	0	2026-07-09 23:11:02.476607+00	2026-07-09 23:11:02.476607+00	\N	\N
63dd6ebb-cd9d-47b7-ac11-46b53ac5be45	3fd350cc-4898-404d-b560-d168f93b26cc	\N	Sessile Oak	Quercus petraea	12.0	\N	\N	healthy	u knw	{"Wildlife habitat"}	71	f	public	t	0101000020E6100000B7F093EC7B43404047C34946C925BE3F	active	0	0	2026-07-09 23:12:34.677936+00	2026-07-09 23:12:34.677936+00	\N	\N
297b527b-5091-4286-b392-4418400e6a8d	3fd350cc-4898-404d-b560-d168f93b26cc	\N	English Oak	Quercus robur	12.0	\N	\N	healthy	\N	{Flowering}	97	f	public	f	0101000020E61000008A7A1C61AC4340401BB4FC659C2BBD3F	active	0	0	2026-07-09 23:17:39.580593+00	2026-07-09 23:34:39.967906+00	\N	\N
4421ad45-b3fd-4532-a7f7-4e7f3668e0b5	9a2cd4f4-507c-43a9-bd35-f6317139ae25	\N	Test Maple	\N	\N	\N	\N	unknown	\N	{}	\N	f	public	t	0101000020E6100000827574B83BD853C0DB8DC1CAE2D24540	active	0	0	2026-07-09 23:37:51.892645+00	2026-07-09 23:37:51.892645+00	\N	\N
a997f249-92aa-4ca9-a9e8-1f02d4346d59	9a2cd4f4-507c-43a9-bd35-f6317139ae25	\N	Upload Test	\N	\N	\N	\N	unknown	\N	{}	\N	f	public	t	0101000020E61000002601BDBB6BD853C0A640870240D34540	active	0	0	2026-07-09 23:43:26.216828+00	2026-07-09 23:43:26.216828+00	\N	\N
e867cf62-071d-4c28-8ffd-3035af7b9460	9a2cd4f4-507c-43a9-bd35-f6317139ae25	\N	Real Photo Test	\N	\N	\N	\N	unknown	\N	{}	\N	f	public	t	0101000020E6100000781C5AEC16D853C04B1C557266D34540	active	0	0	2026-07-09 23:44:18.641059+00	2026-07-09 23:44:18.641059+00	\N	\N
e8f565d8-ccb2-4f4c-a626-48d01970fa8f	3fd350cc-4898-404d-b560-d168f93b26cc	\N	English Oak	Quercus robur	12.0	\N	\N	healthy	\N	{}	97	f	public	t	0101000020E6100000139FFCBC85855EC083D32F7918B64240	active	0	0	2026-07-13 09:01:18.950285+00	2026-07-13 09:01:18.950285+00	\N	\N
\.


--
-- Data for Name: updates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.updates (id, app_version, link, release_notes, created_at, updated_at) FROM stdin;
1	0.1.1	http://129.205.2.218/mwavuli/download/app-latest.apk	Initial release of Mwavuli	2026-09-26 13:34:36.654644+00	2026-09-26 13:34:36.654644+00
\.


--
-- Data for Name: user_badges; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_badges (user_id, badge_id, awarded_at) FROM stdin;
3fd350cc-4898-404d-b560-d168f93b26cc	1f68e874-0eb8-4765-931c-365b50ce7c0a	2026-07-09 23:07:15.925261+00
9a2cd4f4-507c-43a9-bd35-f6317139ae25	1f68e874-0eb8-4765-931c-365b50ce7c0a	2026-07-09 23:40:20.19451+00
\.


--
-- Data for Name: user_blocks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_blocks (blocker_id, blocked_id, created_at) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, email, username, password_hash, display_name, bio, avatar_url, role, birth_year, is_13_plus, location_label, points, level, created_at, updated_at, deleted_at) FROM stdin;
9a2cd4f4-507c-43a9-bd35-f6317139ae25	test888@test.com	user888	scrypt$25fdc07f14fa6a96a79431ad6e82639c$043a9f15fcc833a675d9c0274ee7f552cc752deb7a7fd5bf877f2f5ceae639e06e41fb7d9901f1b790bc425976a4820455ce022c7541df7ad7069e5061c66029	Test	\N	\N	user	1990	t	\N	30	1	2026-07-09 23:37:47.380853+00	2026-07-09 23:44:18.641059+00	\N
3fd350cc-4898-404d-b560-d168f93b26cc	kevin@gmail.com	Kevin	scrypt$b2d357c75aa2292c7b696dc6956ee46a$4be654c5ceac1988f24f21dd9f588ad253b519563a0da2eabfe4017c13c86e120fa6b70e1ad1490cfa094ad7f64ba1619c379caba471ca3486f1945fa54d430f	Kevin	I love trees	\N	user	2000	t	Kampala Capital City, Central Region	50	1	2026-07-08 15:58:19.285128+00	2026-07-13 09:01:18.950285+00	\N
4fed3221-815b-4b7a-8a3b-f817f5271e48	kenneth@ds.co.ug	kenn	scrypt$0388829266671334179c192cd71911ac$189dfce23a5db157dbe7c333478c380fc8d8d39b4101a2d104693534e96be09c937a504c8443b4fe1208bb16a6fdf734eef6486dd52ae2e19ed58bdaedd6bf13	kenn	\N	\N	user	2002	t	\N	0	1	2026-09-26 14:40:48.554319+00	2026-09-26 14:40:48.554319+00	\N
\.


--
-- Data for Name: geocode_settings; Type: TABLE DATA; Schema: tiger; Owner: postgres
--

COPY tiger.geocode_settings (name, setting, unit, category, short_desc) FROM stdin;
\.


--
-- Data for Name: pagc_gaz; Type: TABLE DATA; Schema: tiger; Owner: postgres
--

COPY tiger.pagc_gaz (id, seq, word, stdword, token, is_custom) FROM stdin;
\.


--
-- Data for Name: pagc_lex; Type: TABLE DATA; Schema: tiger; Owner: postgres
--

COPY tiger.pagc_lex (id, seq, word, stdword, token, is_custom) FROM stdin;
\.


--
-- Data for Name: pagc_rules; Type: TABLE DATA; Schema: tiger; Owner: postgres
--

COPY tiger.pagc_rules (id, rule, is_custom) FROM stdin;
\.


--
-- Data for Name: topology; Type: TABLE DATA; Schema: topology; Owner: postgres
--

COPY topology.topology (id, name, srid, "precision", hasz) FROM stdin;
\.


--
-- Data for Name: layer; Type: TABLE DATA; Schema: topology; Owner: postgres
--

COPY topology.layer (topology_id, layer_id, schema_name, table_name, feature_column, feature_type, level, child_id) FROM stdin;
\.


--
-- Name: activity_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.activity_id_seq', 42, true);


--
-- Name: audit_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.audit_log_id_seq', 1, false);


--
-- Name: points_ledger_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.points_ledger_id_seq', 8, true);


--
-- Name: updates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.updates_id_seq', 1, true);


--
-- Name: topology_id_seq; Type: SEQUENCE SET; Schema: topology; Owner: postgres
--

SELECT pg_catalog.setval('topology.topology_id_seq', 1, false);


--
-- Name: account_deletion_requests account_deletion_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.account_deletion_requests
    ADD CONSTRAINT account_deletion_requests_pkey PRIMARY KEY (id);


--
-- Name: activity activity_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.activity
    ADD CONSTRAINT activity_pkey PRIMARY KEY (id);


--
-- Name: api_keys api_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT api_keys_pkey PRIMARY KEY (id);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: badges badges_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.badges
    ADD CONSTRAINT badges_code_key UNIQUE (code);


--
-- Name: badges badges_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.badges
    ADD CONSTRAINT badges_pkey PRIMARY KEY (id);


--
-- Name: comments comments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);


--
-- Name: consents consents_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.consents
    ADD CONSTRAINT consents_pkey PRIMARY KEY (id);


--
-- Name: data_export_jobs data_export_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.data_export_jobs
    ADD CONSTRAINT data_export_jobs_pkey PRIMARY KEY (id);


--
-- Name: follows follows_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.follows
    ADD CONSTRAINT follows_pkey PRIMARY KEY (follower_id, followee_id);


--
-- Name: likes likes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.likes
    ADD CONSTRAINT likes_pkey PRIMARY KEY (tree_id, user_id);


--
-- Name: moderation_actions moderation_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.moderation_actions
    ADD CONSTRAINT moderation_actions_pkey PRIMARY KEY (id);


--
-- Name: points_ledger points_ledger_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.points_ledger
    ADD CONSTRAINT points_ledger_pkey PRIMARY KEY (id);


--
-- Name: rate_limit_counters rate_limit_counters_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rate_limit_counters
    ADD CONSTRAINT rate_limit_counters_pkey PRIMARY KEY (bucket, route, window_start);


--
-- Name: refresh_tokens refresh_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.refresh_tokens
    ADD CONSTRAINT refresh_tokens_pkey PRIMARY KEY (id);


--
-- Name: reports reports_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_pkey PRIMARY KEY (id);


--
-- Name: saved_trees saved_trees_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.saved_trees
    ADD CONSTRAINT saved_trees_pkey PRIMARY KEY (user_id, tree_id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (name);


--
-- Name: species species_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.species
    ADD CONSTRAINT species_pkey PRIMARY KEY (id);


--
-- Name: species species_scientific_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.species
    ADD CONSTRAINT species_scientific_name_key UNIQUE (scientific_name);


--
-- Name: tree_exact_locations tree_exact_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tree_exact_locations
    ADD CONSTRAINT tree_exact_locations_pkey PRIMARY KEY (tree_id);


--
-- Name: tree_photos tree_photos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tree_photos
    ADD CONSTRAINT tree_photos_pkey PRIMARY KEY (id);


--
-- Name: tree_verifications tree_verifications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tree_verifications
    ADD CONSTRAINT tree_verifications_pkey PRIMARY KEY (tree_id, user_id);


--
-- Name: trees trees_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trees
    ADD CONSTRAINT trees_pkey PRIMARY KEY (id);


--
-- Name: updates updates_app_version_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.updates
    ADD CONSTRAINT updates_app_version_key UNIQUE (app_version);


--
-- Name: updates updates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.updates
    ADD CONSTRAINT updates_pkey PRIMARY KEY (id);


--
-- Name: user_badges user_badges_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_badges
    ADD CONSTRAINT user_badges_pkey PRIMARY KEY (user_id, badge_id);


--
-- Name: user_blocks user_blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_blocks
    ADD CONSTRAINT user_blocks_pkey PRIMARY KEY (blocker_id, blocked_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: activity_actor_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX activity_actor_idx ON public.activity USING btree (actor_id, created_at DESC);


--
-- Name: activity_recent_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX activity_recent_idx ON public.activity USING btree (created_at DESC);


--
-- Name: api_keys_user_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX api_keys_user_idx ON public.api_keys USING btree (user_id) WHERE (revoked_at IS NULL);


--
-- Name: audit_actor_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX audit_actor_idx ON public.audit_log USING btree (actor_id, created_at DESC);


--
-- Name: audit_entity_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX audit_entity_idx ON public.audit_log USING btree (entity, entity_id, created_at DESC);


--
-- Name: comments_tree_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX comments_tree_idx ON public.comments USING btree (tree_id, created_at DESC) WHERE (status = 'visible'::public.comment_status);


--
-- Name: consents_user_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX consents_user_idx ON public.consents USING btree (user_id, kind, created_at DESC);


--
-- Name: deletion_active_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX deletion_active_idx ON public.account_deletion_requests USING btree (user_id) WHERE (status = 'scheduled'::public.deletion_status);


--
-- Name: export_jobs_user_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX export_jobs_user_idx ON public.data_export_jobs USING btree (user_id, requested_at DESC);


--
-- Name: follows_followee_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX follows_followee_idx ON public.follows USING btree (followee_id);


--
-- Name: mod_actions_target_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX mod_actions_target_idx ON public.moderation_actions USING btree (target_type, target_id);


--
-- Name: points_ledger_user_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX points_ledger_user_idx ON public.points_ledger USING btree (user_id, created_at DESC);


--
-- Name: refresh_tokens_user_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX refresh_tokens_user_idx ON public.refresh_tokens USING btree (user_id) WHERE (revoked_at IS NULL);


--
-- Name: reports_open_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX reports_open_idx ON public.reports USING btree (created_at DESC) WHERE (status = 'open'::public.report_status);


--
-- Name: reports_target_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX reports_target_idx ON public.reports USING btree (target_type, target_id);


--
-- Name: rlc_window_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX rlc_window_idx ON public.rate_limit_counters USING btree (window_start);


--
-- Name: saved_trees_user_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX saved_trees_user_idx ON public.saved_trees USING btree (user_id, created_at DESC);


--
-- Name: species_common_trgm; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX species_common_trgm ON public.species USING gin (common_name public.gin_trgm_ops);


--
-- Name: species_sci_trgm; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX species_sci_trgm ON public.species USING gin (scientific_name public.gin_trgm_ops);


--
-- Name: tree_exact_gix; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX tree_exact_gix ON public.tree_exact_locations USING gist (exact_geom);


--
-- Name: tree_photos_tree_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX tree_photos_tree_idx ON public.tree_photos USING btree (tree_id, "position");


--
-- Name: tree_verifications_tree_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX tree_verifications_tree_idx ON public.tree_verifications USING btree (tree_id);


--
-- Name: trees_feed_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX trees_feed_idx ON public.trees USING btree (created_at DESC) WHERE ((status = 'active'::public.tree_status) AND (visibility = 'public'::public.tree_visibility) AND (deleted_at IS NULL));


--
-- Name: trees_fuzzy_gix; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX trees_fuzzy_gix ON public.trees USING gist (fuzzy_geom);


--
-- Name: trees_owner_client_tx_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX trees_owner_client_tx_idx ON public.trees USING btree (owner_id, client_tx_id) WHERE (client_tx_id IS NOT NULL);


--
-- Name: trees_owner_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX trees_owner_idx ON public.trees USING btree (owner_id);


--
-- Name: trees_species_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX trees_species_idx ON public.trees USING btree (species_id);


--
-- Name: updates_created_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX updates_created_idx ON public.updates USING btree (created_at DESC);


--
-- Name: users_active_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX users_active_idx ON public.users USING btree (id) WHERE (deleted_at IS NULL);


--
-- Name: leaderboard_week _RETURN; Type: RULE; Schema: public; Owner: postgres
--

CREATE OR REPLACE VIEW public.leaderboard_week AS
 SELECT u.id,
    u.username,
    u.display_name,
    u.avatar_url,
    count(t.id) AS logs
   FROM (public.users u
     JOIN public.trees t ON ((t.owner_id = u.id)))
  WHERE ((t.created_at >= (now() - '7 days'::interval)) AND (t.deleted_at IS NULL) AND (u.deleted_at IS NULL))
  GROUP BY u.id
  ORDER BY (count(t.id)) DESC;


--
-- Name: comments comments_count; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER comments_count AFTER INSERT OR DELETE ON public.comments FOR EACH ROW EXECUTE FUNCTION app.bump_comment_count();


--
-- Name: likes likes_count; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER likes_count AFTER INSERT OR DELETE ON public.likes FOR EACH ROW EXECUTE FUNCTION app.bump_like_count();


--
-- Name: points_ledger points_apply; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER points_apply AFTER INSERT ON public.points_ledger FOR EACH ROW EXECUTE FUNCTION app.apply_points();


--
-- Name: trees trees_touch; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trees_touch BEFORE UPDATE ON public.trees FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();


--
-- Name: users users_touch; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER users_touch BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();


--
-- Name: account_deletion_requests account_deletion_requests_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.account_deletion_requests
    ADD CONSTRAINT account_deletion_requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: activity activity_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.activity
    ADD CONSTRAINT activity_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: api_keys api_keys_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT api_keys_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: audit_log audit_log_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: comments comments_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: comments comments_tree_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_tree_id_fkey FOREIGN KEY (tree_id) REFERENCES public.trees(id) ON DELETE CASCADE;


--
-- Name: consents consents_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.consents
    ADD CONSTRAINT consents_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: data_export_jobs data_export_jobs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.data_export_jobs
    ADD CONSTRAINT data_export_jobs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: follows follows_followee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.follows
    ADD CONSTRAINT follows_followee_id_fkey FOREIGN KEY (followee_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: follows follows_follower_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.follows
    ADD CONSTRAINT follows_follower_id_fkey FOREIGN KEY (follower_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: likes likes_tree_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.likes
    ADD CONSTRAINT likes_tree_id_fkey FOREIGN KEY (tree_id) REFERENCES public.trees(id) ON DELETE CASCADE;


--
-- Name: likes likes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.likes
    ADD CONSTRAINT likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: moderation_actions moderation_actions_moderator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.moderation_actions
    ADD CONSTRAINT moderation_actions_moderator_id_fkey FOREIGN KEY (moderator_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: moderation_actions moderation_actions_report_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.moderation_actions
    ADD CONSTRAINT moderation_actions_report_id_fkey FOREIGN KEY (report_id) REFERENCES public.reports(id) ON DELETE SET NULL;


--
-- Name: points_ledger points_ledger_tree_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.points_ledger
    ADD CONSTRAINT points_ledger_tree_id_fkey FOREIGN KEY (tree_id) REFERENCES public.trees(id) ON DELETE SET NULL;


--
-- Name: points_ledger points_ledger_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.points_ledger
    ADD CONSTRAINT points_ledger_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: refresh_tokens refresh_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.refresh_tokens
    ADD CONSTRAINT refresh_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: reports reports_reporter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: reports reports_resolver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_resolver_id_fkey FOREIGN KEY (resolver_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: saved_trees saved_trees_tree_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.saved_trees
    ADD CONSTRAINT saved_trees_tree_id_fkey FOREIGN KEY (tree_id) REFERENCES public.trees(id) ON DELETE CASCADE;


--
-- Name: saved_trees saved_trees_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.saved_trees
    ADD CONSTRAINT saved_trees_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: tree_exact_locations tree_exact_locations_tree_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tree_exact_locations
    ADD CONSTRAINT tree_exact_locations_tree_id_fkey FOREIGN KEY (tree_id) REFERENCES public.trees(id) ON DELETE CASCADE;


--
-- Name: tree_photos tree_photos_tree_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tree_photos
    ADD CONSTRAINT tree_photos_tree_id_fkey FOREIGN KEY (tree_id) REFERENCES public.trees(id) ON DELETE CASCADE;


--
-- Name: tree_verifications tree_verifications_tree_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tree_verifications
    ADD CONSTRAINT tree_verifications_tree_id_fkey FOREIGN KEY (tree_id) REFERENCES public.trees(id) ON DELETE CASCADE;


--
-- Name: tree_verifications tree_verifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tree_verifications
    ADD CONSTRAINT tree_verifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: trees trees_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trees
    ADD CONSTRAINT trees_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: trees trees_species_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trees
    ADD CONSTRAINT trees_species_id_fkey FOREIGN KEY (species_id) REFERENCES public.species(id) ON DELETE SET NULL;


--
-- Name: user_badges user_badges_badge_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_badges
    ADD CONSTRAINT user_badges_badge_id_fkey FOREIGN KEY (badge_id) REFERENCES public.badges(id) ON DELETE CASCADE;


--
-- Name: user_badges user_badges_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_badges
    ADD CONSTRAINT user_badges_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_blocks user_blocks_blocked_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_blocks
    ADD CONSTRAINT user_blocks_blocked_id_fkey FOREIGN KEY (blocked_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_blocks user_blocks_blocker_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_blocks
    ADD CONSTRAINT user_blocks_blocker_id_fkey FOREIGN KEY (blocker_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: audit_log audit_insert; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY audit_insert ON public.audit_log FOR INSERT WITH CHECK (true);


--
-- Name: audit_log; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_log audit_select; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY audit_select ON public.audit_log FOR SELECT USING (app.is_staff());


--
-- Name: comments; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;

--
-- Name: comments comments_delete; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY comments_delete ON public.comments FOR DELETE USING (((author_id = app.current_user_id()) OR app.is_staff()));


--
-- Name: comments comments_insert; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY comments_insert ON public.comments FOR INSERT WITH CHECK ((author_id = app.current_user_id()));


--
-- Name: comments comments_modify; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY comments_modify ON public.comments FOR UPDATE USING (((author_id = app.current_user_id()) OR app.is_staff()));


--
-- Name: comments comments_select; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY comments_select ON public.comments FOR SELECT USING (((status = 'visible'::public.comment_status) OR (author_id = app.current_user_id()) OR app.is_staff()));


--
-- Name: tree_exact_locations exact_read; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY exact_read ON public.tree_exact_locations FOR SELECT USING ((app.is_staff() OR (EXISTS ( SELECT 1
   FROM public.trees t
  WHERE ((t.id = tree_exact_locations.tree_id) AND (t.owner_id = app.current_user_id()))))));


--
-- Name: tree_exact_locations exact_write; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY exact_write ON public.tree_exact_locations USING ((app.is_staff() OR (EXISTS ( SELECT 1
   FROM public.trees t
  WHERE ((t.id = tree_exact_locations.tree_id) AND (t.owner_id = app.current_user_id())))))) WITH CHECK ((app.is_staff() OR (EXISTS ( SELECT 1
   FROM public.trees t
  WHERE ((t.id = tree_exact_locations.tree_id) AND (t.owner_id = app.current_user_id()))))));


--
-- Name: moderation_actions modactions_staff; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY modactions_staff ON public.moderation_actions USING (app.is_staff()) WITH CHECK (app.is_staff());


--
-- Name: moderation_actions; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.moderation_actions ENABLE ROW LEVEL SECURITY;

--
-- Name: tree_photos photos_select; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY photos_select ON public.tree_photos FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.trees t
  WHERE (t.id = tree_photos.tree_id))));


--
-- Name: tree_photos photos_write; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY photos_write ON public.tree_photos USING ((app.is_staff() OR (EXISTS ( SELECT 1
   FROM public.trees t
  WHERE ((t.id = tree_photos.tree_id) AND (t.owner_id = app.current_user_id())))))) WITH CHECK ((app.is_staff() OR (EXISTS ( SELECT 1
   FROM public.trees t
  WHERE ((t.id = tree_photos.tree_id) AND (t.owner_id = app.current_user_id()))))));


--
-- Name: reports; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

--
-- Name: reports reports_insert; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY reports_insert ON public.reports FOR INSERT WITH CHECK ((reporter_id = app.current_user_id()));


--
-- Name: reports reports_modify; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY reports_modify ON public.reports FOR UPDATE USING (app.is_staff());


--
-- Name: reports reports_select; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY reports_select ON public.reports FOR SELECT USING (((reporter_id = app.current_user_id()) OR app.is_staff()));


--
-- Name: saved_trees saved_delete; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY saved_delete ON public.saved_trees FOR DELETE USING ((user_id = app.current_user_id()));


--
-- Name: saved_trees saved_insert; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY saved_insert ON public.saved_trees FOR INSERT WITH CHECK ((user_id = app.current_user_id()));


--
-- Name: saved_trees saved_select; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY saved_select ON public.saved_trees FOR SELECT USING ((user_id = app.current_user_id()));


--
-- Name: saved_trees; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.saved_trees ENABLE ROW LEVEL SECURITY;

--
-- Name: tree_exact_locations; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.tree_exact_locations ENABLE ROW LEVEL SECURITY;

--
-- Name: tree_photos; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.tree_photos ENABLE ROW LEVEL SECURITY;

--
-- Name: trees; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.trees ENABLE ROW LEVEL SECURITY;

--
-- Name: trees trees_delete; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY trees_delete ON public.trees FOR DELETE USING (((owner_id = app.current_user_id()) OR app.is_staff()));


--
-- Name: trees trees_insert; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY trees_insert ON public.trees FOR INSERT WITH CHECK ((owner_id = app.current_user_id()));


--
-- Name: trees trees_modify; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY trees_modify ON public.trees FOR UPDATE USING (((owner_id = app.current_user_id()) OR app.is_staff()));


--
-- Name: trees trees_select; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY trees_select ON public.trees FOR SELECT USING (((deleted_at IS NULL) AND (app.is_staff() OR (owner_id = app.current_user_id()) OR ((status = 'active'::public.tree_status) AND ((visibility = 'public'::public.tree_visibility) OR ((visibility = 'followers'::public.tree_visibility) AND (EXISTS ( SELECT 1
   FROM public.follows f
  WHERE ((f.followee_id = trees.owner_id) AND (f.follower_id = app.current_user_id()))))))))));


--
-- Name: SCHEMA app; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA app TO mwavuli_app;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT USAGE ON SCHEMA public TO mwavuli_app;


--
-- Name: FUNCTION apply_points(); Type: ACL; Schema: app; Owner: postgres
--

GRANT ALL ON FUNCTION app.apply_points() TO mwavuli_app;


--
-- Name: FUNCTION bump_comment_count(); Type: ACL; Schema: app; Owner: postgres
--

GRANT ALL ON FUNCTION app.bump_comment_count() TO mwavuli_app;


--
-- Name: FUNCTION bump_like_count(); Type: ACL; Schema: app; Owner: postgres
--

GRANT ALL ON FUNCTION app.bump_like_count() TO mwavuli_app;


--
-- Name: FUNCTION current_user_id(); Type: ACL; Schema: app; Owner: postgres
--

GRANT ALL ON FUNCTION app.current_user_id() TO mwavuli_app;


--
-- Name: FUNCTION current_user_role(); Type: ACL; Schema: app; Owner: postgres
--

GRANT ALL ON FUNCTION app.current_user_role() TO mwavuli_app;


--
-- Name: FUNCTION fuzz_point(exact public.geography, radius_m double precision); Type: ACL; Schema: app; Owner: postgres
--

GRANT ALL ON FUNCTION app.fuzz_point(exact public.geography, radius_m double precision) TO mwavuli_app;


--
-- Name: FUNCTION is_staff(); Type: ACL; Schema: app; Owner: postgres
--

GRANT ALL ON FUNCTION app.is_staff() TO mwavuli_app;


--
-- Name: FUNCTION rate_hit(p_bucket text, p_route text, p_window_start timestamp with time zone); Type: ACL; Schema: app; Owner: postgres
--

GRANT ALL ON FUNCTION app.rate_hit(p_bucket text, p_route text, p_window_start timestamp with time zone) TO mwavuli_app;


--
-- Name: FUNCTION set_tree_location(p_tree_id uuid, p_lat double precision, p_lng double precision, p_accuracy_m double precision, p_is_fuzzy boolean); Type: ACL; Schema: app; Owner: postgres
--

GRANT ALL ON FUNCTION app.set_tree_location(p_tree_id uuid, p_lat double precision, p_lng double precision, p_accuracy_m double precision, p_is_fuzzy boolean) TO mwavuli_app;


--
-- Name: FUNCTION touch_updated_at(); Type: ACL; Schema: app; Owner: postgres
--

GRANT ALL ON FUNCTION app.touch_updated_at() TO mwavuli_app;


--
-- Name: TABLE account_deletion_requests; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.account_deletion_requests TO mwavuli_app;


--
-- Name: TABLE activity; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.activity TO mwavuli_app;


--
-- Name: SEQUENCE activity_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.activity_id_seq TO mwavuli_app;


--
-- Name: TABLE api_keys; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.api_keys TO mwavuli_app;


--
-- Name: TABLE audit_log; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.audit_log TO mwavuli_app;


--
-- Name: SEQUENCE audit_log_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.audit_log_id_seq TO mwavuli_app;


--
-- Name: TABLE badges; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.badges TO mwavuli_app;


--
-- Name: TABLE comments; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.comments TO mwavuli_app;


--
-- Name: TABLE consents; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.consents TO mwavuli_app;


--
-- Name: TABLE data_export_jobs; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.data_export_jobs TO mwavuli_app;


--
-- Name: TABLE follows; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.follows TO mwavuli_app;


--
-- Name: TABLE geography_columns; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.geography_columns TO mwavuli_app;


--
-- Name: TABLE geometry_columns; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.geometry_columns TO mwavuli_app;


--
-- Name: TABLE leaderboard_week; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.leaderboard_week TO mwavuli_app;


--
-- Name: TABLE likes; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.likes TO mwavuli_app;


--
-- Name: TABLE moderation_actions; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.moderation_actions TO mwavuli_app;


--
-- Name: TABLE points_ledger; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.points_ledger TO mwavuli_app;


--
-- Name: SEQUENCE points_ledger_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE public.points_ledger_id_seq TO mwavuli_app;


--
-- Name: TABLE rate_limit_counters; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.rate_limit_counters TO mwavuli_app;


--
-- Name: TABLE refresh_tokens; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.refresh_tokens TO mwavuli_app;


--
-- Name: TABLE reports; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.reports TO mwavuli_app;


--
-- Name: TABLE saved_trees; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.saved_trees TO mwavuli_app;


--
-- Name: TABLE schema_migrations; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.schema_migrations TO mwavuli_app;


--
-- Name: TABLE spatial_ref_sys; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.spatial_ref_sys TO mwavuli_app;


--
-- Name: TABLE species; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.species TO mwavuli_app;


--
-- Name: TABLE tree_exact_locations; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.tree_exact_locations TO mwavuli_app;


--
-- Name: TABLE tree_photos; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.tree_photos TO mwavuli_app;


--
-- Name: TABLE tree_verifications; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.tree_verifications TO mwavuli_app;


--
-- Name: TABLE trees; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.trees TO mwavuli_app;


--
-- Name: TABLE updates; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.updates TO mwavuli_app;


--
-- Name: TABLE user_badges; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.user_badges TO mwavuli_app;


--
-- Name: TABLE user_blocks; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.user_blocks TO mwavuli_app;


--
-- Name: TABLE users; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.users TO mwavuli_app;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO mwavuli_app;


--
-- PostgreSQL database dump complete
--

