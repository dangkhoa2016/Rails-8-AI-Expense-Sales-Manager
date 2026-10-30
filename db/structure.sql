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
-- Name: finance_deny_confirmed_line_item_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.finance_deny_confirmed_line_item_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE tx_id bigint;
BEGIN
  tx_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.transaction_id ELSE NEW.transaction_id END;
  IF EXISTS (SELECT 1 FROM finance_transactions WHERE id = tx_id AND status = 'confirmed')
     OR (TG_OP = 'UPDATE' AND EXISTS (SELECT 1 FROM finance_transactions
        WHERE id = OLD.transaction_id AND status = 'confirmed')) THEN
    RAISE EXCEPTION 'confirmed finance line items cannot be changed';
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;


--
-- Name: finance_deny_confirmed_transaction_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.finance_deny_confirmed_transaction_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' AND OLD.status = 'confirmed' THEN
    RAISE EXCEPTION 'confirmed finance transaction cannot be deleted';
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.status = 'confirmed' THEN
    RAISE EXCEPTION 'confirmed finance transaction cannot be modified';
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;


--
-- Name: finance_deny_history_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.finance_deny_history_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'finance evidence is append-only';
END;
$$;


--
-- Name: finance_guard_correction_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.finance_guard_correction_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'finance corrections cannot be deleted';
  END IF;
  IF TG_OP = 'UPDATE' THEN
    IF OLD.status = 'confirmed' THEN
      RAISE EXCEPTION 'confirmed finance correction cannot be modified';
    END IF;
    IF NEW.original_transaction_id <> OLD.original_transaction_id
      OR NEW.replacement_transaction_id <> OLD.replacement_transaction_id
      OR NEW.workspace_id <> OLD.workspace_id
      OR NEW.requested_by_id <> OLD.requested_by_id
      OR NEW.reason <> OLD.reason THEN
      RAISE EXCEPTION 'finance correction provenance is immutable';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: finance_guard_line_item_tags(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.finance_guard_line_item_tags() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  item_tx bigint;
  item_workspace bigint;
  item_status text;
  tag_workspace bigint;
BEGIN
  SELECT tx.id, tx.workspace_id, tx.status
  INTO item_tx, item_workspace, item_status
  FROM finance_line_items li
  JOIN finance_transactions tx ON tx.id = li.transaction_id
  WHERE li.id = CASE WHEN TG_OP = 'DELETE' THEN OLD.line_item_id ELSE NEW.line_item_id END;

  IF item_tx IS NULL OR item_status <> 'draft' THEN
    RAISE EXCEPTION 'Confirmed or missing transaction line tags are immutable';
  END IF;

  IF TG_OP <> 'DELETE' THEN
    SELECT workspace_id INTO tag_workspace
    FROM finance_categories WHERE id = NEW.category_id;
    IF tag_workspace IS DISTINCT FROM item_workspace THEN
      RAISE EXCEPTION 'Cross-workspace line tags are forbidden';
    END IF;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION 'Update tag links by delete/insert only';
  END IF;

  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;


--
-- Name: finance_guard_transaction_context_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.finance_guard_transaction_context_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  tx_status text;
BEGIN
  IF TG_OP = 'DELETE' THEN
    SELECT status INTO tx_status FROM finance_transactions WHERE id = OLD.transaction_id;
    IF tx_status = 'confirmed' THEN
      RAISE EXCEPTION 'confirmed financial context cannot be removed';
    END IF;
    RETURN OLD;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NEW.transaction_id <> OLD.transaction_id
       OR NEW.recorded_by_id <> OLD.recorded_by_id
       OR NEW.source <> OLD.source THEN
      RAISE EXCEPTION 'financial context provenance cannot be changed';
    END IF;

    SELECT status INTO tx_status FROM finance_transactions WHERE id = OLD.transaction_id;
    IF tx_status = 'confirmed' THEN
      RAISE EXCEPTION 'confirmed financial context cannot be changed';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: finance_audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.finance_audit_events (
    id bigint NOT NULL,
    transaction_id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    actor_id bigint NOT NULL,
    event_type character varying NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: finance_audit_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.finance_audit_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: finance_audit_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.finance_audit_events_id_seq OWNED BY public.finance_audit_events.id;


--
-- Name: finance_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.finance_categories (
    id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    key character varying(50) NOT NULL,
    name_en character varying(120) NOT NULL,
    name_vi character varying(120) NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT finance_categories_nonempty_names CHECK (((char_length(btrim((name_en)::text)) > 0) AND (char_length(btrim((name_vi)::text)) > 0))),
    CONSTRAINT finance_categories_safe_key CHECK (((key)::text ~ '^[a-z][a-z0-9_]{1,49}$'::text))
);


--
-- Name: finance_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.finance_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: finance_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.finance_categories_id_seq OWNED BY public.finance_categories.id;


--
-- Name: finance_corrections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.finance_corrections (
    id bigint NOT NULL,
    original_transaction_id bigint NOT NULL,
    replacement_transaction_id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    requested_by_id bigint NOT NULL,
    confirmed_by_id bigint,
    reason text NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    confirmed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT finance_corrections_confirm_check CHECK ((((status)::text <> 'confirmed'::text) OR ((confirmed_by_id IS NOT NULL) AND (confirmed_at IS NOT NULL)))),
    CONSTRAINT finance_corrections_distinct_check CHECK ((original_transaction_id <> replacement_transaction_id)),
    CONSTRAINT finance_corrections_reason_check CHECK (((char_length(btrim(reason)) >= 10) AND (char_length(btrim(reason)) <= 2000))),
    CONSTRAINT finance_corrections_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'confirmed'::character varying])::text[])))
);


--
-- Name: finance_corrections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.finance_corrections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: finance_corrections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.finance_corrections_id_seq OWNED BY public.finance_corrections.id;


--
-- Name: finance_document_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.finance_document_versions (
    id bigint NOT NULL,
    transaction_id bigint NOT NULL,
    version_number integer NOT NULL,
    sha256 character varying(64) NOT NULL,
    original_filename character varying NOT NULL,
    content_type character varying NOT NULL,
    byte_size bigint NOT NULL,
    uploaded_by_id bigint NOT NULL,
    supersedes_version_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT finance_document_version_digest_check CHECK ((char_length((sha256)::text) = 64)),
    CONSTRAINT finance_document_version_valid_check CHECK (((version_number > 0) AND (byte_size > 0)))
);


--
-- Name: finance_document_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.finance_document_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: finance_document_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.finance_document_versions_id_seq OWNED BY public.finance_document_versions.id;


--
-- Name: finance_extraction_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.finance_extraction_runs (
    id bigint NOT NULL,
    document_version_id bigint NOT NULL,
    model_sha256 character varying(64) NOT NULL,
    prompt_sha256 character varying(64) NOT NULL,
    schema_version character varying NOT NULL,
    parse_status character varying NOT NULL,
    raw_output jsonb DEFAULT '{}'::jsonb NOT NULL,
    diagnostic_code text,
    created_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT finance_extraction_status_check CHECK (((parse_status)::text = ANY (ARRAY[('readable'::character varying)::text, ('partially_readable'::character varying)::text, ('unreadable'::character varying)::text, ('processing_error'::character varying)::text])))
);


--
-- Name: finance_extraction_runs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.finance_extraction_runs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: finance_extraction_runs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.finance_extraction_runs_id_seq OWNED BY public.finance_extraction_runs.id;


--
-- Name: finance_field_suggestions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.finance_field_suggestions (
    id bigint NOT NULL,
    transaction_id bigint NOT NULL,
    extraction_run_id bigint NOT NULL,
    field_key character varying NOT NULL,
    proposed_value text,
    review_status character varying DEFAULT 'pending'::character varying NOT NULL,
    reviewed_by_id bigint,
    reviewed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT finance_suggestions_review_check CHECK (((review_status)::text = ANY (ARRAY[('pending'::character varying)::text, ('accepted'::character varying)::text, ('rejected'::character varying)::text])))
);


--
-- Name: finance_field_suggestions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.finance_field_suggestions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: finance_field_suggestions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.finance_field_suggestions_id_seq OWNED BY public.finance_field_suggestions.id;


--
-- Name: finance_line_import_batches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.finance_line_import_batches (
    id bigint NOT NULL,
    transaction_id bigint NOT NULL,
    sha256 character varying(64) NOT NULL,
    row_count integer NOT NULL,
    uploaded_by_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT finance_line_import_valid_check CHECK (((row_count >= 1) AND (row_count <= 500) AND (char_length((sha256)::text) = 64)))
);


--
-- Name: finance_line_import_batches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.finance_line_import_batches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: finance_line_import_batches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.finance_line_import_batches_id_seq OWNED BY public.finance_line_import_batches.id;


--
-- Name: finance_line_item_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.finance_line_item_tags (
    id bigint NOT NULL,
    line_item_id bigint NOT NULL,
    category_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: finance_line_item_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.finance_line_item_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: finance_line_item_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.finance_line_item_tags_id_seq OWNED BY public.finance_line_item_tags.id;


--
-- Name: finance_line_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.finance_line_items (
    id bigint NOT NULL,
    transaction_id bigint NOT NULL,
    "position" integer NOT NULL,
    description text NOT NULL,
    amount numeric(20,2),
    entry_source character varying DEFAULT 'manual'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    quantity numeric(12,3),
    unit_price numeric(20,2),
    category character varying(100),
    occurred_on date,
    occurred_time time without time zone,
    location_text character varying(400),
    CONSTRAINT finance_line_items_amount_check CHECK (((amount IS NULL) OR (amount >= (0)::numeric))),
    CONSTRAINT finance_line_items_location_text_check CHECK (((location_text IS NULL) OR ((char_length(btrim((location_text)::text)) >= 1) AND (char_length(btrim((location_text)::text)) <= 400)))),
    CONSTRAINT finance_line_items_quantity_check CHECK (((quantity IS NULL) OR (quantity > (0)::numeric))),
    CONSTRAINT finance_line_items_unit_price_check CHECK (((unit_price IS NULL) OR (unit_price >= (0)::numeric)))
);


--
-- Name: finance_line_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.finance_line_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: finance_line_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.finance_line_items_id_seq OWNED BY public.finance_line_items.id;


--
-- Name: finance_transaction_contexts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.finance_transaction_contexts (
    id bigint NOT NULL,
    transaction_id bigint NOT NULL,
    purchase_details text,
    occurred_time time without time zone,
    location_text text,
    source character varying(24) DEFAULT 'manual'::character varying NOT NULL,
    recorded_by_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT finance_transaction_contexts_details_check CHECK (((purchase_details IS NULL) OR ((char_length(purchase_details) >= 1) AND (char_length(purchase_details) <= 1000)))),
    CONSTRAINT finance_transaction_contexts_location_check CHECK (((location_text IS NULL) OR ((char_length(location_text) >= 1) AND (char_length(location_text) <= 400)))),
    CONSTRAINT finance_transaction_contexts_source_check CHECK (((source)::text = ANY (ARRAY[('manual'::character varying)::text, ('demo_seed'::character varying)::text])))
);


--
-- Name: finance_transaction_contexts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.finance_transaction_contexts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: finance_transaction_contexts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.finance_transaction_contexts_id_seq OWNED BY public.finance_transaction_contexts.id;


--
-- Name: finance_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.finance_transactions (
    id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    kind character varying NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    transaction_date date,
    currency_code character varying DEFAULT 'VND'::character varying NOT NULL,
    amount numeric(20,2),
    description text,
    category character varying,
    entry_source character varying DEFAULT 'manual'::character varying NOT NULL,
    active_document_version_id bigint,
    created_by_id bigint NOT NULL,
    confirmed_by_id bigint,
    confirmed_at timestamp(6) without time zone,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT finance_transactions_amount_check CHECK (((amount IS NULL) OR (amount >= (0)::numeric))),
    CONSTRAINT finance_transactions_confirm_check CHECK ((((status)::text <> 'confirmed'::text) OR ((transaction_date IS NOT NULL) AND (amount > (0)::numeric) AND (confirmed_by_id IS NOT NULL) AND (confirmed_at IS NOT NULL)))),
    CONSTRAINT finance_transactions_kind_check CHECK (((kind)::text = ANY (ARRAY[('income'::character varying)::text, ('expense'::character varying)::text]))),
    CONSTRAINT finance_transactions_source_check CHECK (((entry_source)::text = ANY (ARRAY[('manual'::character varying)::text, ('ai_assisted'::character varying)::text]))),
    CONSTRAINT finance_transactions_status_check CHECK (((status)::text = ANY (ARRAY[('draft'::character varying)::text, ('confirmed'::character varying)::text])))
);


--
-- Name: finance_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.finance_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: finance_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.finance_transactions_id_seq OWNED BY public.finance_transactions.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    ip_address character varying,
    user_agent character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sessions_id_seq OWNED BY public.sessions.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email_address character varying NOT NULL,
    password_digest character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: workspaces; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.workspaces (
    id bigint NOT NULL,
    owner_id bigint NOT NULL,
    name character varying(120) NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: workspaces_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.workspaces_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: workspaces_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.workspaces_id_seq OWNED BY public.workspaces.id;


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: finance_audit_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_audit_events ALTER COLUMN id SET DEFAULT nextval('public.finance_audit_events_id_seq'::regclass);


--
-- Name: finance_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_categories ALTER COLUMN id SET DEFAULT nextval('public.finance_categories_id_seq'::regclass);


--
-- Name: finance_corrections id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_corrections ALTER COLUMN id SET DEFAULT nextval('public.finance_corrections_id_seq'::regclass);


--
-- Name: finance_document_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_document_versions ALTER COLUMN id SET DEFAULT nextval('public.finance_document_versions_id_seq'::regclass);


--
-- Name: finance_extraction_runs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_extraction_runs ALTER COLUMN id SET DEFAULT nextval('public.finance_extraction_runs_id_seq'::regclass);


--
-- Name: finance_field_suggestions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_field_suggestions ALTER COLUMN id SET DEFAULT nextval('public.finance_field_suggestions_id_seq'::regclass);


--
-- Name: finance_line_import_batches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_line_import_batches ALTER COLUMN id SET DEFAULT nextval('public.finance_line_import_batches_id_seq'::regclass);


--
-- Name: finance_line_item_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_line_item_tags ALTER COLUMN id SET DEFAULT nextval('public.finance_line_item_tags_id_seq'::regclass);


--
-- Name: finance_line_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_line_items ALTER COLUMN id SET DEFAULT nextval('public.finance_line_items_id_seq'::regclass);


--
-- Name: finance_transaction_contexts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_transaction_contexts ALTER COLUMN id SET DEFAULT nextval('public.finance_transaction_contexts_id_seq'::regclass);


--
-- Name: finance_transactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_transactions ALTER COLUMN id SET DEFAULT nextval('public.finance_transactions_id_seq'::regclass);


--
-- Name: sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions ALTER COLUMN id SET DEFAULT nextval('public.sessions_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: workspaces id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workspaces ALTER COLUMN id SET DEFAULT nextval('public.workspaces_id_seq'::regclass);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: finance_audit_events finance_audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_audit_events
    ADD CONSTRAINT finance_audit_events_pkey PRIMARY KEY (id);


--
-- Name: finance_categories finance_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_categories
    ADD CONSTRAINT finance_categories_pkey PRIMARY KEY (id);


--
-- Name: finance_corrections finance_corrections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_corrections
    ADD CONSTRAINT finance_corrections_pkey PRIMARY KEY (id);


--
-- Name: finance_document_versions finance_document_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_document_versions
    ADD CONSTRAINT finance_document_versions_pkey PRIMARY KEY (id);


--
-- Name: finance_extraction_runs finance_extraction_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_extraction_runs
    ADD CONSTRAINT finance_extraction_runs_pkey PRIMARY KEY (id);


--
-- Name: finance_field_suggestions finance_field_suggestions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_field_suggestions
    ADD CONSTRAINT finance_field_suggestions_pkey PRIMARY KEY (id);


--
-- Name: finance_line_import_batches finance_line_import_batches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_line_import_batches
    ADD CONSTRAINT finance_line_import_batches_pkey PRIMARY KEY (id);


--
-- Name: finance_line_item_tags finance_line_item_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_line_item_tags
    ADD CONSTRAINT finance_line_item_tags_pkey PRIMARY KEY (id);


--
-- Name: finance_line_items finance_line_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_line_items
    ADD CONSTRAINT finance_line_items_pkey PRIMARY KEY (id);


--
-- Name: finance_transaction_contexts finance_transaction_contexts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_transaction_contexts
    ADD CONSTRAINT finance_transaction_contexts_pkey PRIMARY KEY (id);


--
-- Name: finance_transactions finance_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_transactions
    ADD CONSTRAINT finance_transactions_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: workspaces workspaces_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workspaces
    ADD CONSTRAINT workspaces_pkey PRIMARY KEY (id);


--
-- Name: idx_finance_categories_tenant_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_finance_categories_tenant_key ON public.finance_categories USING btree (workspace_id, key);


--
-- Name: idx_finance_correction_original; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_finance_correction_original ON public.finance_corrections USING btree (original_transaction_id);


--
-- Name: idx_finance_correction_replacement; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_finance_correction_replacement ON public.finance_corrections USING btree (replacement_transaction_id);


--
-- Name: idx_finance_document_versions_sequence; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_finance_document_versions_sequence ON public.finance_document_versions USING btree (transaction_id, version_number);


--
-- Name: idx_finance_line_import_replay; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_finance_line_import_replay ON public.finance_line_import_batches USING btree (transaction_id, sha256);


--
-- Name: idx_finance_line_item_tags_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_finance_line_item_tags_unique ON public.finance_line_item_tags USING btree (line_item_id, category_id);


--
-- Name: idx_finance_tenant_status_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_finance_tenant_status_date ON public.finance_transactions USING btree (workspace_id, status, transaction_date);


--
-- Name: idx_finance_version_transaction_pair; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_finance_version_transaction_pair ON public.finance_document_versions USING btree (id, transaction_id);


--
-- Name: idx_on_transaction_id_review_status_091c50abb8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_transaction_id_review_status_091c50abb8 ON public.finance_field_suggestions USING btree (transaction_id, review_status);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_finance_audit_events_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_finance_audit_events_on_transaction_id ON public.finance_audit_events USING btree (transaction_id);


--
-- Name: index_finance_audit_events_on_workspace_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_finance_audit_events_on_workspace_id_and_created_at ON public.finance_audit_events USING btree (workspace_id, created_at);


--
-- Name: index_finance_categories_on_workspace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_finance_categories_on_workspace_id ON public.finance_categories USING btree (workspace_id);


--
-- Name: index_finance_extraction_runs_on_document_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_finance_extraction_runs_on_document_version_id ON public.finance_extraction_runs USING btree (document_version_id);


--
-- Name: index_finance_field_suggestions_on_extraction_run_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_finance_field_suggestions_on_extraction_run_id ON public.finance_field_suggestions USING btree (extraction_run_id);


--
-- Name: index_finance_field_suggestions_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_finance_field_suggestions_on_transaction_id ON public.finance_field_suggestions USING btree (transaction_id);


--
-- Name: index_finance_line_import_batches_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_finance_line_import_batches_on_transaction_id ON public.finance_line_import_batches USING btree (transaction_id);


--
-- Name: index_finance_line_item_tags_on_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_finance_line_item_tags_on_category_id ON public.finance_line_item_tags USING btree (category_id);


--
-- Name: index_finance_line_item_tags_on_line_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_finance_line_item_tags_on_line_item_id ON public.finance_line_item_tags USING btree (line_item_id);


--
-- Name: index_finance_line_items_on_transaction_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_finance_line_items_on_transaction_id_and_position ON public.finance_line_items USING btree (transaction_id, "position");


--
-- Name: index_finance_transaction_contexts_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_finance_transaction_contexts_on_transaction_id ON public.finance_transaction_contexts USING btree (transaction_id);


--
-- Name: index_sessions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_user_id ON public.sessions USING btree (user_id);


--
-- Name: index_users_on_email_address; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email_address ON public.users USING btree (email_address);


--
-- Name: index_workspaces_on_owner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_workspaces_on_owner_id ON public.workspaces USING btree (owner_id);


--
-- Name: finance_line_items deny_confirmed_finance_line_item_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER deny_confirmed_finance_line_item_mutation BEFORE INSERT OR DELETE OR UPDATE ON public.finance_line_items FOR EACH ROW EXECUTE FUNCTION public.finance_deny_confirmed_line_item_mutation();


--
-- Name: finance_transactions deny_confirmed_finance_transaction_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER deny_confirmed_finance_transaction_mutation BEFORE DELETE OR UPDATE ON public.finance_transactions FOR EACH ROW EXECUTE FUNCTION public.finance_deny_confirmed_transaction_mutation();


--
-- Name: finance_audit_events deny_finance_audit_events_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER deny_finance_audit_events_mutation BEFORE DELETE OR UPDATE ON public.finance_audit_events FOR EACH ROW EXECUTE FUNCTION public.finance_deny_history_mutation();


--
-- Name: finance_document_versions deny_finance_document_versions_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER deny_finance_document_versions_mutation BEFORE DELETE OR UPDATE ON public.finance_document_versions FOR EACH ROW EXECUTE FUNCTION public.finance_deny_history_mutation();


--
-- Name: finance_extraction_runs deny_finance_extraction_runs_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER deny_finance_extraction_runs_mutation BEFORE DELETE OR UPDATE ON public.finance_extraction_runs FOR EACH ROW EXECUTE FUNCTION public.finance_deny_history_mutation();


--
-- Name: finance_line_import_batches deny_finance_line_import_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER deny_finance_line_import_mutation BEFORE DELETE OR UPDATE ON public.finance_line_import_batches FOR EACH ROW EXECUTE FUNCTION public.finance_deny_history_mutation();


--
-- Name: finance_corrections guard_finance_correction_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER guard_finance_correction_mutation BEFORE DELETE OR UPDATE ON public.finance_corrections FOR EACH ROW EXECUTE FUNCTION public.finance_guard_correction_mutation();


--
-- Name: finance_line_item_tags guard_finance_line_item_tags; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER guard_finance_line_item_tags BEFORE INSERT OR DELETE OR UPDATE ON public.finance_line_item_tags FOR EACH ROW EXECUTE FUNCTION public.finance_guard_line_item_tags();


--
-- Name: finance_transaction_contexts guard_finance_transaction_context_mutation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER guard_finance_transaction_context_mutation BEFORE DELETE OR UPDATE ON public.finance_transaction_contexts FOR EACH ROW EXECUTE FUNCTION public.finance_guard_transaction_context_mutation();


--
-- Name: finance_transactions finance_active_doc_same_transaction; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_transactions
    ADD CONSTRAINT finance_active_doc_same_transaction FOREIGN KEY (active_document_version_id, id) REFERENCES public.finance_document_versions(id, transaction_id);


--
-- Name: finance_line_import_batches fk_rails_05f81bbd76; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_line_import_batches
    ADD CONSTRAINT fk_rails_05f81bbd76 FOREIGN KEY (transaction_id) REFERENCES public.finance_transactions(id);


--
-- Name: finance_audit_events fk_rails_0a567fa21f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_audit_events
    ADD CONSTRAINT fk_rails_0a567fa21f FOREIGN KEY (transaction_id) REFERENCES public.finance_transactions(id);


--
-- Name: finance_corrections fk_rails_0f4e0884b1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_corrections
    ADD CONSTRAINT fk_rails_0f4e0884b1 FOREIGN KEY (requested_by_id) REFERENCES public.users(id);


--
-- Name: finance_corrections fk_rails_2da7a4a247; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_corrections
    ADD CONSTRAINT fk_rails_2da7a4a247 FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id);


--
-- Name: finance_transaction_contexts fk_rails_4d99e76b28; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_transaction_contexts
    ADD CONSTRAINT fk_rails_4d99e76b28 FOREIGN KEY (transaction_id) REFERENCES public.finance_transactions(id);


--
-- Name: workspaces fk_rails_5506b4b37e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workspaces
    ADD CONSTRAINT fk_rails_5506b4b37e FOREIGN KEY (owner_id) REFERENCES public.users(id);


--
-- Name: finance_field_suggestions fk_rails_675e23ab8d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_field_suggestions
    ADD CONSTRAINT fk_rails_675e23ab8d FOREIGN KEY (extraction_run_id) REFERENCES public.finance_extraction_runs(id);


--
-- Name: sessions fk_rails_758836b4f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_758836b4f0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: finance_corrections fk_rails_78c574bb9f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_corrections
    ADD CONSTRAINT fk_rails_78c574bb9f FOREIGN KEY (original_transaction_id) REFERENCES public.finance_transactions(id);


--
-- Name: finance_line_item_tags fk_rails_7c6c9c7a09; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_line_item_tags
    ADD CONSTRAINT fk_rails_7c6c9c7a09 FOREIGN KEY (category_id) REFERENCES public.finance_categories(id);


--
-- Name: finance_extraction_runs fk_rails_904d81276c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_extraction_runs
    ADD CONSTRAINT fk_rails_904d81276c FOREIGN KEY (document_version_id) REFERENCES public.finance_document_versions(id);


--
-- Name: finance_transaction_contexts fk_rails_9449fdff0f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_transaction_contexts
    ADD CONSTRAINT fk_rails_9449fdff0f FOREIGN KEY (recorded_by_id) REFERENCES public.users(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: finance_corrections fk_rails_9a45617c0d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_corrections
    ADD CONSTRAINT fk_rails_9a45617c0d FOREIGN KEY (replacement_transaction_id) REFERENCES public.finance_transactions(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: finance_document_versions fk_rails_cd5fd6b9e2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_document_versions
    ADD CONSTRAINT fk_rails_cd5fd6b9e2 FOREIGN KEY (transaction_id) REFERENCES public.finance_transactions(id);


--
-- Name: finance_line_item_tags fk_rails_d97785cae7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_line_item_tags
    ADD CONSTRAINT fk_rails_d97785cae7 FOREIGN KEY (line_item_id) REFERENCES public.finance_line_items(id);


--
-- Name: finance_line_items fk_rails_deb878fa93; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_line_items
    ADD CONSTRAINT fk_rails_deb878fa93 FOREIGN KEY (transaction_id) REFERENCES public.finance_transactions(id);


--
-- Name: finance_categories fk_rails_e0aae8adf0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_categories
    ADD CONSTRAINT fk_rails_e0aae8adf0 FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id);


--
-- Name: finance_corrections fk_rails_e2c6c3aa97; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_corrections
    ADD CONSTRAINT fk_rails_e2c6c3aa97 FOREIGN KEY (confirmed_by_id) REFERENCES public.users(id);


--
-- Name: finance_transactions fk_rails_e6427fc872; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_transactions
    ADD CONSTRAINT fk_rails_e6427fc872 FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id);


--
-- Name: finance_field_suggestions fk_rails_e806ccf9fd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finance_field_suggestions
    ADD CONSTRAINT fk_rails_e806ccf9fd FOREIGN KEY (transaction_id) REFERENCES public.finance_transactions(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20261030110000'),
('20261030090000'),
('20261030080000'),
('20261030070000'),
('20261030061000'),
('20261030055000'),
('20261030034000'),
('20261030033800'),
('20261030033730'),
('20261030033703'),
('20261030033618'),
('20261030033617');
