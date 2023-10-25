--
-- PostgreSQL database dump
--

-- Dumped from database version 13.4 (Debian 13.4-1.pgdg110+1)
-- Dumped by pg_dump version 13.6 (Ubuntu 13.6-1.pgdg20.04+1+b1)

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
-- Name: agdc; Type: SCHEMA; Schema: -; Owner: agdc_admin
--

CREATE SCHEMA agdc;


ALTER SCHEMA agdc OWNER TO agdc_admin;

--
-- Name: pg_cron; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA public;


--
-- Name: EXTENSION pg_cron; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_cron IS 'Job scheduler for PostgreSQL';


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
-- Name: hstore; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS hstore WITH SCHEMA public;


--
-- Name: EXTENSION hstore; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION hstore IS 'data type for storing sets of (key, value) pairs';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: pgrouting; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgrouting WITH SCHEMA public;


--
-- Name: EXTENSION pgrouting; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgrouting IS 'pgRouting Extension';


--
-- Name: postgis_raster; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis_raster WITH SCHEMA public;


--
-- Name: EXTENSION postgis_raster; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis_raster IS 'PostGIS raster types and functions';


--
-- Name: postgis_topology; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis_topology WITH SCHEMA topology;


--
-- Name: EXTENSION postgis_topology; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis_topology IS 'PostGIS topology spatial types and functions';


--
-- Name: float8range; Type: TYPE; Schema: agdc; Owner: agdc_admin
--

CREATE TYPE agdc.float8range AS RANGE (
    subtype = double precision,
    subtype_diff = float8mi
);


ALTER TYPE agdc.float8range OWNER TO agdc_admin;

--
-- Name: common_timestamp(text); Type: FUNCTION; Schema: agdc; Owner: agdc_admin
--

CREATE FUNCTION agdc.common_timestamp(text) RETURNS timestamp with time zone
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$
select ($1)::timestamp at time zone 'utc';
$_$;


ALTER FUNCTION agdc.common_timestamp(text) OWNER TO agdc_admin;

--
-- Name: set_row_update_time(); Type: FUNCTION; Schema: agdc; Owner: agdc_admin
--

CREATE FUNCTION agdc.set_row_update_time() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  new.updated = now();
  return new;
end;
$$;


ALTER FUNCTION agdc.set_row_update_time() OWNER TO agdc_admin;

--
-- Name: asbinary(public.geometry); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.asbinary(public.geometry) RETURNS bytea
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/postgis-3', 'LWGEOM_asBinary';


ALTER FUNCTION public.asbinary(public.geometry) OWNER TO postgres;

--
-- Name: asbinary(public.geometry, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.asbinary(public.geometry, text) RETURNS bytea
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/postgis-3', 'LWGEOM_asBinary';


ALTER FUNCTION public.asbinary(public.geometry, text) OWNER TO postgres;

--
-- Name: astext(public.geometry); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.astext(public.geometry) RETURNS text
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/postgis-3', 'LWGEOM_asText';


ALTER FUNCTION public.astext(public.geometry) OWNER TO postgres;

--
-- Name: estimated_extent(text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.estimated_extent(text, text) RETURNS public.box2d
    LANGUAGE c IMMUTABLE STRICT SECURITY DEFINER
    AS '$libdir/postgis-3', 'geometry_estimated_extent';


ALTER FUNCTION public.estimated_extent(text, text) OWNER TO postgres;

--
-- Name: estimated_extent(text, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.estimated_extent(text, text, text) RETURNS public.box2d
    LANGUAGE c IMMUTABLE STRICT SECURITY DEFINER
    AS '$libdir/postgis-3', 'geometry_estimated_extent';


ALTER FUNCTION public.estimated_extent(text, text, text) OWNER TO postgres;

--
-- Name: geomfromtext(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.geomfromtext(text) RETURNS public.geometry
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$SELECT ST_GeomFromText($1)$_$;


ALTER FUNCTION public.geomfromtext(text) OWNER TO postgres;

--
-- Name: geomfromtext(text, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.geomfromtext(text, integer) RETURNS public.geometry
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$SELECT ST_GeomFromText($1, $2)$_$;


ALTER FUNCTION public.geomfromtext(text, integer) OWNER TO postgres;

--
-- Name: ndims(public.geometry); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.ndims(public.geometry) RETURNS smallint
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/postgis-3', 'LWGEOM_ndims';


ALTER FUNCTION public.ndims(public.geometry) OWNER TO postgres;

--
-- Name: setsrid(public.geometry, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.setsrid(public.geometry, integer) RETURNS public.geometry
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/postgis-3', 'LWGEOM_set_srid';


ALTER FUNCTION public.setsrid(public.geometry, integer) OWNER TO postgres;

--
-- Name: srid(public.geometry); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.srid(public.geometry) RETURNS integer
    LANGUAGE c IMMUTABLE STRICT
    AS '$libdir/postgis-3', 'LWGEOM_get_srid';


ALTER FUNCTION public.srid(public.geometry) OWNER TO postgres;

--
-- Name: st_asbinary(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_asbinary(text) RETURNS bytea
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$ SELECT ST_AsBinary($1::geometry);$_$;


ALTER FUNCTION public.st_asbinary(text) OWNER TO postgres;

--
-- Name: st_astext(bytea); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.st_astext(bytea) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$ SELECT ST_AsText($1::geometry);$_$;


ALTER FUNCTION public.st_astext(bytea) OWNER TO postgres;

--
-- Name: gist_geometry_ops; Type: OPERATOR FAMILY; Schema: public; Owner: postgres
--

CREATE OPERATOR FAMILY public.gist_geometry_ops USING gist;


ALTER OPERATOR FAMILY public.gist_geometry_ops USING gist OWNER TO postgres;

--
-- Name: gist_geometry_ops; Type: OPERATOR CLASS; Schema: public; Owner: postgres
--

CREATE OPERATOR CLASS public.gist_geometry_ops
    FOR TYPE public.geometry USING gist FAMILY public.gist_geometry_ops AS
    STORAGE public.box2df ,
    OPERATOR 1 public.<<(public.geometry,public.geometry) ,
    OPERATOR 2 public.&<(public.geometry,public.geometry) ,
    OPERATOR 3 public.&&(public.geometry,public.geometry) ,
    OPERATOR 4 public.&>(public.geometry,public.geometry) ,
    OPERATOR 5 public.>>(public.geometry,public.geometry) ,
    OPERATOR 6 public.~=(public.geometry,public.geometry) ,
    OPERATOR 7 public.~(public.geometry,public.geometry) ,
    OPERATOR 8 public.@(public.geometry,public.geometry) ,
    OPERATOR 9 public.&<|(public.geometry,public.geometry) ,
    OPERATOR 10 public.<<|(public.geometry,public.geometry) ,
    OPERATOR 11 public.|>>(public.geometry,public.geometry) ,
    OPERATOR 12 public.|&>(public.geometry,public.geometry) ,
    OPERATOR 13 public.<->(public.geometry,public.geometry) FOR ORDER BY pg_catalog.float_ops ,
    OPERATOR 14 public.<#>(public.geometry,public.geometry) FOR ORDER BY pg_catalog.float_ops ,
    FUNCTION 1 (public.geometry, public.geometry) public.geometry_gist_consistent_2d(internal,public.geometry,integer) ,
    FUNCTION 2 (public.geometry, public.geometry) public.geometry_gist_union_2d(bytea,internal) ,
    FUNCTION 3 (public.geometry, public.geometry) public.geometry_gist_compress_2d(internal) ,
    FUNCTION 4 (public.geometry, public.geometry) public.geometry_gist_decompress_2d(internal) ,
    FUNCTION 5 (public.geometry, public.geometry) public.geometry_gist_penalty_2d(internal,internal,internal) ,
    FUNCTION 6 (public.geometry, public.geometry) public.geometry_gist_picksplit_2d(internal,internal) ,
    FUNCTION 7 (public.geometry, public.geometry) public.geometry_gist_same_2d(public.geometry,public.geometry,internal) ,
    FUNCTION 8 (public.geometry, public.geometry) public.geometry_gist_distance_2d(internal,public.geometry,integer);


ALTER OPERATOR CLASS public.gist_geometry_ops USING gist OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: dataset; Type: TABLE; Schema: agdc; Owner: agdc_admin
--

CREATE TABLE agdc.dataset (
    id uuid NOT NULL,
    metadata_type_ref smallint NOT NULL,
    dataset_type_ref smallint NOT NULL,
    metadata jsonb NOT NULL,
    archived timestamp with time zone,
    added timestamp with time zone DEFAULT now() NOT NULL,
    added_by name DEFAULT CURRENT_USER NOT NULL,
    updated timestamp with time zone
);


ALTER TABLE agdc.dataset OWNER TO agdc_admin;

--
-- Name: dataset_location; Type: TABLE; Schema: agdc; Owner: agdc_admin
--

CREATE TABLE agdc.dataset_location (
    id integer NOT NULL,
    dataset_ref uuid NOT NULL,
    uri_scheme character varying NOT NULL,
    uri_body character varying NOT NULL,
    added timestamp with time zone DEFAULT now() NOT NULL,
    added_by name DEFAULT CURRENT_USER NOT NULL,
    archived timestamp with time zone
);


ALTER TABLE agdc.dataset_location OWNER TO agdc_admin;

--
-- Name: dataset_location_id_seq; Type: SEQUENCE; Schema: agdc; Owner: agdc_admin
--

CREATE SEQUENCE agdc.dataset_location_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE agdc.dataset_location_id_seq OWNER TO agdc_admin;

--
-- Name: dataset_location_id_seq; Type: SEQUENCE OWNED BY; Schema: agdc; Owner: agdc_admin
--

ALTER SEQUENCE agdc.dataset_location_id_seq OWNED BY agdc.dataset_location.id;


--
-- Name: dataset_source; Type: TABLE; Schema: agdc; Owner: agdc_admin
--

CREATE TABLE agdc.dataset_source (
    dataset_ref uuid NOT NULL,
    classifier character varying NOT NULL,
    source_dataset_ref uuid NOT NULL
);


ALTER TABLE agdc.dataset_source OWNER TO agdc_admin;

--
-- Name: dataset_type; Type: TABLE; Schema: agdc; Owner: agdc_admin
--

CREATE TABLE agdc.dataset_type (
    id smallint NOT NULL,
    name character varying NOT NULL,
    metadata jsonb NOT NULL,
    metadata_type_ref smallint NOT NULL,
    definition jsonb NOT NULL,
    added timestamp with time zone DEFAULT now() NOT NULL,
    added_by name DEFAULT CURRENT_USER NOT NULL,
    updated timestamp with time zone,
    CONSTRAINT ck_dataset_type_alphanumeric_name CHECK (((name)::text ~* '^\w+$'::text))
);


ALTER TABLE agdc.dataset_type OWNER TO agdc_admin;

--
-- Name: dataset_type_id_seq; Type: SEQUENCE; Schema: agdc; Owner: agdc_admin
--

CREATE SEQUENCE agdc.dataset_type_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE agdc.dataset_type_id_seq OWNER TO agdc_admin;

--
-- Name: dataset_type_id_seq; Type: SEQUENCE OWNED BY; Schema: agdc; Owner: agdc_admin
--

ALTER SEQUENCE agdc.dataset_type_id_seq OWNED BY agdc.dataset_type.id;


--
-- Name: metadata_type; Type: TABLE; Schema: agdc; Owner: agdc_admin
--

CREATE TABLE agdc.metadata_type (
    id smallint NOT NULL,
    name character varying NOT NULL,
    definition jsonb NOT NULL,
    added timestamp with time zone DEFAULT now() NOT NULL,
    added_by name DEFAULT CURRENT_USER NOT NULL,
    updated timestamp with time zone,
    CONSTRAINT ck_metadata_type_alphanumeric_name CHECK (((name)::text ~* '^\w+$'::text))
);


ALTER TABLE agdc.metadata_type OWNER TO agdc_admin;

--
-- Name: dv_eo3_dataset; Type: VIEW; Schema: agdc; Owner: odcuser
--

CREATE VIEW agdc.dv_eo3_dataset AS
 SELECT dataset.id,
    dataset.added AS indexed_time,
    dataset.added_by AS indexed_by,
    dataset_type.name AS product,
    dataset.dataset_type_ref AS dataset_type_id,
    metadata_type.name AS metadata_type,
    dataset.metadata_type_ref AS metadata_type_id,
    dataset.metadata AS metadata_doc,
    agdc.common_timestamp((dataset.metadata #>> '{properties,odc:processing_datetime}'::text[])) AS creation_time,
    (dataset.metadata #>> '{properties,odc:file_format}'::text[]) AS format,
    (dataset.metadata #>> '{label}'::text[]) AS label,
    agdc.float8range(((dataset.metadata #>> '{extent,lat,begin}'::text[]))::double precision, ((dataset.metadata #>> '{extent,lat,end}'::text[]))::double precision, '[]'::text) AS lat,
    agdc.float8range(((dataset.metadata #>> '{extent,lon,begin}'::text[]))::double precision, ((dataset.metadata #>> '{extent,lon,end}'::text[]))::double precision, '[]'::text) AS lon,
    tstzrange(LEAST(agdc.common_timestamp((dataset.metadata #>> '{properties,dtr:start_datetime}'::text[])), agdc.common_timestamp((dataset.metadata #>> '{properties,datetime}'::text[]))), GREATEST(agdc.common_timestamp((dataset.metadata #>> '{properties,dtr:end_datetime}'::text[])), agdc.common_timestamp((dataset.metadata #>> '{properties,datetime}'::text[]))), '[]'::text) AS "time",
    (dataset.metadata #>> '{properties,eo:platform}'::text[]) AS platform,
    (dataset.metadata #>> '{properties,eo:instrument}'::text[]) AS instrument,
    ((dataset.metadata #>> '{properties,eo:cloud_cover}'::text[]))::double precision AS cloud_cover,
    (dataset.metadata #>> '{properties,odc:region_code}'::text[]) AS region_code,
    (dataset.metadata #>> '{properties,odc:product_family}'::text[]) AS product_family,
    (dataset.metadata #>> '{properties,dea:dataset_maturity}'::text[]) AS dataset_maturity
   FROM ((agdc.dataset
     JOIN agdc.dataset_type ON ((dataset_type.id = dataset.dataset_type_ref)))
     JOIN agdc.metadata_type ON ((metadata_type.id = dataset_type.metadata_type_ref)))
  WHERE ((dataset.archived IS NULL) AND (dataset.metadata_type_ref = 1));


ALTER TABLE agdc.dv_eo3_dataset OWNER TO odcuser;

--
-- Name: dv_eo3_sentinel_ard_dataset; Type: VIEW; Schema: agdc; Owner: odcuser
--

CREATE VIEW agdc.dv_eo3_sentinel_ard_dataset AS
 SELECT dataset.id,
    dataset.added AS indexed_time,
    dataset.added_by AS indexed_by,
    dataset_type.name AS product,
    dataset.dataset_type_ref AS dataset_type_id,
    metadata_type.name AS metadata_type,
    dataset.metadata_type_ref AS metadata_type_id,
    dataset.metadata AS metadata_doc,
    agdc.common_timestamp((dataset.metadata #>> '{properties,odc:processing_datetime}'::text[])) AS creation_time,
    (dataset.metadata #>> '{properties,odc:file_format}'::text[]) AS format,
    (dataset.metadata #>> '{label}'::text[]) AS label,
    (dataset.metadata #>> '{properties,eo:platform}'::text[]) AS platform,
    (dataset.metadata #>> '{properties,eo:instrument}'::text[]) AS instrument,
    (dataset.metadata #>> '{properties,odc:product_family}'::text[]) AS product_family,
    (dataset.metadata #>> '{properties,odc:region_code}'::text[]) AS region_code,
    (dataset.metadata #>> '{crs}'::text[]) AS crs_raw,
    (dataset.metadata #>> '{properties,dea:dataset_maturity}'::text[]) AS dataset_maturity,
    ((dataset.metadata #>> '{properties,eo:cloud_cover}'::text[]))::double precision AS cloud_cover,
    tstzrange(LEAST(agdc.common_timestamp((dataset.metadata #>> '{properties,dtr:start_datetime}'::text[])), agdc.common_timestamp((dataset.metadata #>> '{properties,datetime}'::text[]))), GREATEST(agdc.common_timestamp((dataset.metadata #>> '{properties,dtr:end_datetime}'::text[])), agdc.common_timestamp((dataset.metadata #>> '{properties,datetime}'::text[]))), '[]'::text) AS "time",
    agdc.float8range(((dataset.metadata #>> '{extent,lon,begin}'::text[]))::double precision, ((dataset.metadata #>> '{extent,lon,end}'::text[]))::double precision, '[]'::text) AS lon,
    agdc.float8range(((dataset.metadata #>> '{extent,lat,begin}'::text[]))::double precision, ((dataset.metadata #>> '{extent,lat,end}'::text[]))::double precision, '[]'::text) AS lat,
    ((dataset.metadata #>> '{properties,eo:gsd}'::text[]))::double precision AS eo_gsd,
    ((dataset.metadata #>> '{properties,eo:sun_azimuth}'::text[]))::double precision AS eo_sun_azimuth,
    ((dataset.metadata #>> '{properties,eo:sun_elevation}'::text[]))::double precision AS eo_sun_elevation,
    (dataset.metadata #>> '{properties,sentinel:product_name}'::text[]) AS sentinel_product_name,
    (dataset.metadata #>> '{properties,sentinel:sentinel_tile_id}'::text[]) AS sentinel_tile_id,
    (dataset.metadata #>> '{properties,sentinel:datastrip_id}'::text[]) AS sentinel_datastrip_id,
    ((dataset.metadata #>> '{properties,fmask:clear}'::text[]))::double precision AS fmask_clear,
    ((dataset.metadata #>> '{properties,fmask:cloud_shadow}'::text[]))::double precision AS fmask_cloud_shadow,
    ((dataset.metadata #>> '{properties,fmask:snow}'::text[]))::double precision AS fmask_snow,
    ((dataset.metadata #>> '{properties,fmask:water}'::text[]))::double precision AS fmask_water,
    ((dataset.metadata #>> '{properties,gqa:abs_iterative_mean_x}'::text[]))::double precision AS gqa_abs_iterative_mean_x,
    ((dataset.metadata #>> '{properties,gqa:abs_iterative_mean_xy}'::text[]))::double precision AS gqa_abs_iterative_mean_xy,
    ((dataset.metadata #>> '{properties,gqa:abs_iterative_mean_y}'::text[]))::double precision AS gqa_abs_iterative_mean_y,
    ((dataset.metadata #>> '{properties,gqa:abs_x}'::text[]))::double precision AS gqa_abs_x,
    ((dataset.metadata #>> '{properties,gqa:abs_xy}'::text[]))::double precision AS gqa_abs_xy,
    ((dataset.metadata #>> '{properties,gqa:abs_y}'::text[]))::double precision AS gqa_abs_y,
    ((dataset.metadata #>> '{properties,gqa:cep90}'::text[]))::double precision AS gqa_cep90,
    ((dataset.metadata #>> '{properties,gqa:iterative_mean_x}'::text[]))::double precision AS gqa_iterative_mean_x,
    ((dataset.metadata #>> '{properties,gqa:iterative_mean_xy}'::text[]))::double precision AS gqa_iterative_mean_xy,
    ((dataset.metadata #>> '{properties,gqa:iterative_mean_y}'::text[]))::double precision AS gqa_iterative_mean_y,
    ((dataset.metadata #>> '{properties,gqa:iterative_stddev_x}'::text[]))::double precision AS gqa_iterative_stddev_x,
    ((dataset.metadata #>> '{properties,gqa:iterative_stddev_xy}'::text[]))::double precision AS gqa_iterative_stddev_xy,
    ((dataset.metadata #>> '{properties,gqa:iterative_stddev_y}'::text[]))::double precision AS gqa_iterative_stddev_y,
    ((dataset.metadata #>> '{properties,gqa:mean_x}'::text[]))::double precision AS gqa_mean_x,
    ((dataset.metadata #>> '{properties,gqa:mean_xy}'::text[]))::double precision AS gqa_mean_xy,
    ((dataset.metadata #>> '{properties,gqa:mean_y}'::text[]))::double precision AS gqa_mean_y,
    ((dataset.metadata #>> '{properties,gqa:stddev_x}'::text[]))::double precision AS gqa_stddev_x,
    ((dataset.metadata #>> '{properties,gqa:stddev_xy}'::text[]))::double precision AS gqa_stddev_xy,
    ((dataset.metadata #>> '{properties,gqa:stddev_y}'::text[]))::double precision AS gqa_stddev_y,
    ((dataset.metadata #>> '{properties,s2cloudless:clear}'::text[]))::double precision AS s2cloudless_clear,
    ((dataset.metadata #>> '{properties,s2cloudless:cloud}'::text[]))::double precision AS s2cloudless_cloud
   FROM ((agdc.dataset
     JOIN agdc.dataset_type ON ((dataset_type.id = dataset.dataset_type_ref)))
     JOIN agdc.metadata_type ON ((metadata_type.id = dataset_type.metadata_type_ref)))
  WHERE ((dataset.archived IS NULL) AND (dataset.metadata_type_ref = 4));


ALTER TABLE agdc.dv_eo3_sentinel_ard_dataset OWNER TO odcuser;

--
-- Name: dv_eo_dataset; Type: VIEW; Schema: agdc; Owner: odcuser
--

CREATE VIEW agdc.dv_eo_dataset AS
 SELECT dataset.id,
    dataset.added AS indexed_time,
    dataset.added_by AS indexed_by,
    dataset_type.name AS product,
    dataset.dataset_type_ref AS dataset_type_id,
    metadata_type.name AS metadata_type,
    dataset.metadata_type_ref AS metadata_type_id,
    dataset.metadata AS metadata_doc,
    agdc.common_timestamp((dataset.metadata #>> '{creation_dt}'::text[])) AS creation_time,
    (dataset.metadata #>> '{format,name}'::text[]) AS format,
    (dataset.metadata #>> '{ga_label}'::text[]) AS label,
    agdc.float8range(LEAST(((dataset.metadata #>> '{extent,coord,ur,lat}'::text[]))::double precision, ((dataset.metadata #>> '{extent,coord,lr,lat}'::text[]))::double precision, ((dataset.metadata #>> '{extent,coord,ul,lat}'::text[]))::double precision, ((dataset.metadata #>> '{extent,coord,ll,lat}'::text[]))::double precision), GREATEST(((dataset.metadata #>> '{extent,coord,ur,lat}'::text[]))::double precision, ((dataset.metadata #>> '{extent,coord,lr,lat}'::text[]))::double precision, ((dataset.metadata #>> '{extent,coord,ul,lat}'::text[]))::double precision, ((dataset.metadata #>> '{extent,coord,ll,lat}'::text[]))::double precision), '[]'::text) AS lat,
    agdc.float8range(LEAST(((dataset.metadata #>> '{extent,coord,ul,lon}'::text[]))::double precision, ((dataset.metadata #>> '{extent,coord,ur,lon}'::text[]))::double precision, ((dataset.metadata #>> '{extent,coord,ll,lon}'::text[]))::double precision, ((dataset.metadata #>> '{extent,coord,lr,lon}'::text[]))::double precision), GREATEST(((dataset.metadata #>> '{extent,coord,ul,lon}'::text[]))::double precision, ((dataset.metadata #>> '{extent,coord,ur,lon}'::text[]))::double precision, ((dataset.metadata #>> '{extent,coord,ll,lon}'::text[]))::double precision, ((dataset.metadata #>> '{extent,coord,lr,lon}'::text[]))::double precision), '[]'::text) AS lon,
    tstzrange(LEAST(agdc.common_timestamp((dataset.metadata #>> '{extent,from_dt}'::text[])), agdc.common_timestamp((dataset.metadata #>> '{extent,center_dt}'::text[]))), GREATEST(agdc.common_timestamp((dataset.metadata #>> '{extent,to_dt}'::text[])), agdc.common_timestamp((dataset.metadata #>> '{extent,center_dt}'::text[]))), '[]'::text) AS "time",
    (dataset.metadata #>> '{platform,code}'::text[]) AS platform,
    (dataset.metadata #>> '{instrument,name}'::text[]) AS instrument,
    (dataset.metadata #>> '{product_type}'::text[]) AS product_type
   FROM ((agdc.dataset
     JOIN agdc.dataset_type ON ((dataset_type.id = dataset.dataset_type_ref)))
     JOIN agdc.metadata_type ON ((metadata_type.id = dataset_type.metadata_type_ref)))
  WHERE ((dataset.archived IS NULL) AND (dataset.metadata_type_ref = 2));


ALTER TABLE agdc.dv_eo_dataset OWNER TO odcuser;

--
-- Name: dv_ga_s2am_ard_3_dataset; Type: VIEW; Schema: agdc; Owner: odcuser
--

CREATE VIEW agdc.dv_ga_s2am_ard_3_dataset AS
 SELECT dataset.id,
    dataset.added AS indexed_time,
    dataset.added_by AS indexed_by,
    dataset_type.name AS product,
    dataset.dataset_type_ref AS dataset_type_id,
    metadata_type.name AS metadata_type,
    dataset.metadata_type_ref AS metadata_type_id,
    dataset.metadata AS metadata_doc,
    agdc.common_timestamp((dataset.metadata #>> '{properties,odc:processing_datetime}'::text[])) AS creation_time,
    (dataset.metadata #>> '{properties,odc:file_format}'::text[]) AS format,
    (dataset.metadata #>> '{label}'::text[]) AS label,
    agdc.float8range(((dataset.metadata #>> '{extent,lat,begin}'::text[]))::double precision, ((dataset.metadata #>> '{extent,lat,end}'::text[]))::double precision, '[]'::text) AS lat,
    agdc.float8range(((dataset.metadata #>> '{extent,lon,begin}'::text[]))::double precision, ((dataset.metadata #>> '{extent,lon,end}'::text[]))::double precision, '[]'::text) AS lon,
    tstzrange(LEAST(agdc.common_timestamp((dataset.metadata #>> '{properties,dtr:start_datetime}'::text[])), agdc.common_timestamp((dataset.metadata #>> '{properties,datetime}'::text[]))), GREATEST(agdc.common_timestamp((dataset.metadata #>> '{properties,dtr:end_datetime}'::text[])), agdc.common_timestamp((dataset.metadata #>> '{properties,datetime}'::text[]))), '[]'::text) AS "time",
    ((dataset.metadata #>> '{properties,eo:gsd}'::text[]))::double precision AS eo_gsd,
    (dataset.metadata #>> '{crs}'::text[]) AS crs_raw,
    (dataset.metadata #>> '{properties,eo:platform}'::text[]) AS platform,
    ((dataset.metadata #>> '{properties,gqa:abs_x}'::text[]))::double precision AS gqa_abs_x,
    ((dataset.metadata #>> '{properties,gqa:abs_y}'::text[]))::double precision AS gqa_abs_y,
    ((dataset.metadata #>> '{properties,gqa:cep90}'::text[]))::double precision AS gqa_cep90,
    ((dataset.metadata #>> '{properties,fmask:snow}'::text[]))::double precision AS fmask_snow,
    ((dataset.metadata #>> '{properties,gqa:abs_xy}'::text[]))::double precision AS gqa_abs_xy,
    ((dataset.metadata #>> '{properties,gqa:mean_x}'::text[]))::double precision AS gqa_mean_x,
    ((dataset.metadata #>> '{properties,gqa:mean_y}'::text[]))::double precision AS gqa_mean_y,
    (dataset.metadata #>> '{properties,eo:instrument}'::text[]) AS instrument,
    ((dataset.metadata #>> '{properties,eo:cloud_cover}'::text[]))::double precision AS cloud_cover,
    ((dataset.metadata #>> '{properties,fmask:clear}'::text[]))::double precision AS fmask_clear,
    ((dataset.metadata #>> '{properties,fmask:water}'::text[]))::double precision AS fmask_water,
    ((dataset.metadata #>> '{properties,gqa:mean_xy}'::text[]))::double precision AS gqa_mean_xy,
    (dataset.metadata #>> '{properties,odc:region_code}'::text[]) AS region_code,
    ((dataset.metadata #>> '{properties,gqa:stddev_x}'::text[]))::double precision AS gqa_stddev_x,
    ((dataset.metadata #>> '{properties,gqa:stddev_y}'::text[]))::double precision AS gqa_stddev_y,
    ((dataset.metadata #>> '{properties,gqa:stddev_xy}'::text[]))::double precision AS gqa_stddev_xy,
    ((dataset.metadata #>> '{properties,eo:sun_azimuth}'::text[]))::double precision AS eo_sun_azimuth,
    (dataset.metadata #>> '{properties,odc:product_family}'::text[]) AS product_family,
    (dataset.metadata #>> '{properties,dea:dataset_maturity}'::text[]) AS dataset_maturity,
    ((dataset.metadata #>> '{properties,eo:sun_elevation}'::text[]))::double precision AS eo_sun_elevation,
    (dataset.metadata #>> '{properties,sentinel:sentinel_tile_id}'::text[]) AS sentinel_tile_id,
    ((dataset.metadata #>> '{properties,s2cloudless:clear}'::text[]))::double precision AS s2cloudless_clear,
    ((dataset.metadata #>> '{properties,s2cloudless:cloud}'::text[]))::double precision AS s2cloudless_cloud,
    ((dataset.metadata #>> '{properties,fmask:cloud_shadow}'::text[]))::double precision AS fmask_cloud_shadow,
    ((dataset.metadata #>> '{properties,gqa:iterative_mean_x}'::text[]))::double precision AS gqa_iterative_mean_x,
    ((dataset.metadata #>> '{properties,gqa:iterative_mean_y}'::text[]))::double precision AS gqa_iterative_mean_y,
    ((dataset.metadata #>> '{properties,gqa:iterative_mean_xy}'::text[]))::double precision AS gqa_iterative_mean_xy,
    (dataset.metadata #>> '{properties,sentinel:datastrip_id}'::text[]) AS sentinel_datastrip_id,
    (dataset.metadata #>> '{properties,sentinel:product_name}'::text[]) AS sentinel_product_name,
    ((dataset.metadata #>> '{properties,gqa:iterative_stddev_x}'::text[]))::double precision AS gqa_iterative_stddev_x,
    ((dataset.metadata #>> '{properties,gqa:iterative_stddev_y}'::text[]))::double precision AS gqa_iterative_stddev_y,
    ((dataset.metadata #>> '{properties,gqa:iterative_stddev_xy}'::text[]))::double precision AS gqa_iterative_stddev_xy,
    ((dataset.metadata #>> '{properties,gqa:abs_iterative_mean_x}'::text[]))::double precision AS gqa_abs_iterative_mean_x,
    ((dataset.metadata #>> '{properties,gqa:abs_iterative_mean_y}'::text[]))::double precision AS gqa_abs_iterative_mean_y,
    ((dataset.metadata #>> '{properties,gqa:abs_iterative_mean_xy}'::text[]))::double precision AS gqa_abs_iterative_mean_xy
   FROM ((agdc.dataset
     JOIN agdc.dataset_type ON ((dataset_type.id = dataset.dataset_type_ref)))
     JOIN agdc.metadata_type ON ((metadata_type.id = dataset_type.metadata_type_ref)))
  WHERE ((dataset.archived IS NULL) AND (dataset.dataset_type_ref = 1));


ALTER TABLE agdc.dv_ga_s2am_ard_3_dataset OWNER TO odcuser;

--
-- Name: dv_telemetry_dataset; Type: VIEW; Schema: agdc; Owner: odcuser
--

CREATE VIEW agdc.dv_telemetry_dataset AS
 SELECT dataset.id,
    dataset.added AS indexed_time,
    dataset.added_by AS indexed_by,
    dataset_type.name AS product,
    dataset.dataset_type_ref AS dataset_type_id,
    metadata_type.name AS metadata_type,
    dataset.metadata_type_ref AS metadata_type_id,
    dataset.metadata AS metadata_doc,
    agdc.common_timestamp((dataset.metadata #>> '{creation_dt}'::text[])) AS creation_time,
    (dataset.metadata #>> '{format,name}'::text[]) AS format,
    (dataset.metadata #>> '{ga_label}'::text[]) AS label,
    (dataset.metadata #>> '{acquisition,groundstation,code}'::text[]) AS gsi,
    tstzrange(agdc.common_timestamp((dataset.metadata #>> '{acquisition,aos}'::text[])), agdc.common_timestamp((dataset.metadata #>> '{acquisition,los}'::text[])), '[]'::text) AS "time",
    ((dataset.metadata #>> '{acquisition,platform_orbit}'::text[]))::integer AS orbit,
    numrange((((dataset.metadata #>> '{image,satellite_ref_point_start,y}'::text[]))::integer)::numeric, (GREATEST(((dataset.metadata #>> '{image,satellite_ref_point_end,y}'::text[]))::integer, ((dataset.metadata #>> '{image,satellite_ref_point_start,y}'::text[]))::integer))::numeric, '[]'::text) AS sat_row,
    (dataset.metadata #>> '{platform,code}'::text[]) AS platform,
    numrange((((dataset.metadata #>> '{image,satellite_ref_point_start,x}'::text[]))::integer)::numeric, (GREATEST(((dataset.metadata #>> '{image,satellite_ref_point_end,x}'::text[]))::integer, ((dataset.metadata #>> '{image,satellite_ref_point_start,x}'::text[]))::integer))::numeric, '[]'::text) AS sat_path,
    (dataset.metadata #>> '{instrument,name}'::text[]) AS instrument,
    (dataset.metadata #>> '{product_type}'::text[]) AS product_type
   FROM ((agdc.dataset
     JOIN agdc.dataset_type ON ((dataset_type.id = dataset.dataset_type_ref)))
     JOIN agdc.metadata_type ON ((metadata_type.id = dataset_type.metadata_type_ref)))
  WHERE ((dataset.archived IS NULL) AND (dataset.metadata_type_ref = 3));


ALTER TABLE agdc.dv_telemetry_dataset OWNER TO odcuser;

--
-- Name: metadata_type_id_seq; Type: SEQUENCE; Schema: agdc; Owner: agdc_admin
--

CREATE SEQUENCE agdc.metadata_type_id_seq
    AS smallint
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE agdc.metadata_type_id_seq OWNER TO agdc_admin;

--
-- Name: metadata_type_id_seq; Type: SEQUENCE OWNED BY; Schema: agdc; Owner: agdc_admin
--

ALTER SEQUENCE agdc.metadata_type_id_seq OWNED BY agdc.metadata_type.id;


--
-- Name: dataset_location id; Type: DEFAULT; Schema: agdc; Owner: agdc_admin
--

ALTER TABLE ONLY agdc.dataset_location ALTER COLUMN id SET DEFAULT nextval('agdc.dataset_location_id_seq'::regclass);


--
-- Name: dataset_type id; Type: DEFAULT; Schema: agdc; Owner: agdc_admin
--

ALTER TABLE ONLY agdc.dataset_type ALTER COLUMN id SET DEFAULT nextval('agdc.dataset_type_id_seq'::regclass);


--
-- Name: metadata_type id; Type: DEFAULT; Schema: agdc; Owner: agdc_admin
--

ALTER TABLE ONLY agdc.metadata_type ALTER COLUMN id SET DEFAULT nextval('agdc.metadata_type_id_seq'::regclass);


--
-- Data for Name: dataset; Type: TABLE DATA; Schema: agdc; Owner: agdc_admin
--

COPY agdc.dataset (id, metadata_type_ref, dataset_type_ref, metadata, archived, added, added_by, updated) FROM stdin;
52dda32c-cb4b-49eb-a31d-bcf70bf62751	4	1	{"id": "52dda32c-cb4b-49eb-a31d-bcf70bf62751", "crs": "epsg:32755", "grids": {"10": {"shape": [10980, 10980], "transform": [10.0, 0.0, 699960.0, 0.0, -10.0, 6100000.0, 0.0, 0.0, 1.0]}, "60": {"shape": [1830, 1830], "transform": [60.0, 0.0, 699960.0, 0.0, -60.0, 6100000.0, 0.0, 0.0, 1.0]}, "default": {"shape": [5490, 5490], "transform": [20.0, 0.0, 699960.0, 0.0, -20.0, 6100000.0, 0.0, 0.0, 1.0]}}, "label": "ga_s2am_ard_3-2-1_55HGA_2019-11-21_final", "extent": {"lat": {"end": -35.19525082885167, "begin": -36.21239114842929}, "lon": {"end": 150.4442681122013, "begin": 149.19710243283376}}, "$schema": "https://schemas.opendatacube.org/dataset", "lineage": {"source_datasets": {}}, "product": {"href": "https://collections.dea.ga.gov.au/product/ga_s2am_ard_3", "name": "ga_s2am_ard_3"}, "geometry": {"type": "Polygon", "coordinates": [[[699960.0, 6100000.0], [809760.0, 6100000.0], [809760.0, 5990200.0], [699960.0, 5990200.0], [699960.0, 6100000.0]]]}, "properties": {"eo:gsd": 10.0, "datetime": "2019-11-21 00:06:43.424350Z", "gqa:abs_x": 0.53, "gqa:abs_y": 0.47, "gqa:cep90": 0.97, "fmask:snow": 0.03551414892452248, "gqa:abs_xy": 0.71, "gqa:mean_x": 0.47, "gqa:mean_y": 0.35, "eo:platform": "sentinel-2a", "fmask:clear": 87.56730402354339, "fmask:cloud": 10.491776735976325, "fmask:water": 1.8309361946377085, "gqa:mean_xy": 0.58, "gqa:stddev_x": 0.64, "gqa:stddev_y": 0.6, "odc:producer": "ga.gov.au", "eo:instrument": "MSI", "gqa:stddev_xy": 0.88, "eo:cloud_cover": 10.491776735976325, "eo:sun_azimuth": 60.6247116497177, "odc:file_format": "GeoTIFF", "odc:region_code": "55HGA", "sat:orbit_state": "descending", "eo:constellation": "sentinel-2", "eo:sun_elevation": 27.0525040544586, "s2cloudless:clear": 100.0, "s2cloudless:cloud": 0.0, "fmask:cloud_shadow": 0.07446889691805933, "odc:product_family": "ard", "sat:relative_orbit": 30, "odc:dataset_version": "3.2.1", "dea:dataset_maturity": "final", "dea:product_maturity": "stable", "gqa:iterative_mean_x": 0.48, "gqa:iterative_mean_y": 0.34, "gqa:iterative_mean_xy": 0.59, "sentinel:datastrip_id": "S2A_OPER_MSI_L1C_DS_EPAE_20191121T011741_S20191121T000241_N02.08", "sentinel:product_name": "S2A_MSIL1C_20191121T000241_N0208_R030_T55HGA_20191121T011741", "gqa:iterative_stddev_x": 0.22, "gqa:iterative_stddev_y": 0.28, "gqa:iterative_stddev_xy": 0.36, "odc:processing_datetime": "2022-08-12 01:16:33.587148Z", "gqa:abs_iterative_mean_x": 0.48, "gqa:abs_iterative_mean_y": 0.37, "gqa:abs_iterative_mean_xy": 0.61, "sentinel:sentinel_tile_id": "S2A_OPER_MSI_L1C_TL_EPAE_20191121T011741_A023050_T55HGA_N02.08", "sentinel:datatake_start_datetime": "2019-11-21 01:17:41Z"}, "accessories": {"checksum:sha1": {"path": "ga_s2am_ard_3-2-1_55HGA_2019-11-21_final.sha1"}, "thumbnail:nbart": {"path": "ga_s2am_nbart_3-2-1_55HGA_2019-11-21_final_thumbnail.jpg"}, "metadata:processor": {"path": "ga_s2am_ard_3-2-1_55HGA_2019-11-21_final.proc-info.yaml"}}, "grid_spatial": {"projection": {"valid_data": {"type": "Polygon", "coordinates": [[[699960.0, 6100000.0], [809760.0, 6100000.0], [809760.0, 5990200.0], [699960.0, 5990200.0], [699960.0, 6100000.0]]]}, "geo_ref_points": {"ll": {"x": 699960.0, "y": 5990200.0}, "lr": {"x": 809760.0, "y": 5990200.0}, "ul": {"x": 699960.0, "y": 6100000.0}, "ur": {"x": 809760.0, "y": 6100000.0}}, "spatial_reference": "epsg:32755"}}, "measurements": {"oa_fmask": {"path": "ga_s2am_oa_3-2-1_55HGA_2019-11-21_final_fmask.tif"}, "nbart_red": {"grid": "10", "path": "ga_s2am_nbart_3-2-1_55HGA_2019-11-21_final_band04.tif"}, "nbart_blue": {"grid": "10", "path": "ga_s2am_nbart_3-2-1_55HGA_2019-11-21_final_band02.tif"}, "nbart_green": {"grid": "10", "path": "ga_s2am_nbart_3-2-1_55HGA_2019-11-21_final_band03.tif"}, "nbart_nir_1": {"grid": "10", "path": "ga_s2am_nbart_3-2-1_55HGA_2019-11-21_final_band08.tif"}, "nbart_nir_2": {"path": "ga_s2am_nbart_3-2-1_55HGA_2019-11-21_final_band08a.tif"}, "nbart_swir_2": {"path": "ga_s2am_nbart_3-2-1_55HGA_2019-11-21_final_band11.tif"}, "nbart_swir_3": {"path": "ga_s2am_nbart_3-2-1_55HGA_2019-11-21_final_band12.tif"}, "oa_time_delta": {"path": "ga_s2am_oa_3-2-1_55HGA_2019-11-21_final_time-delta.tif"}, "oa_solar_zenith": {"path": "ga_s2am_oa_3-2-1_55HGA_2019-11-21_final_solar-zenith.tif"}, "nbart_red_edge_1": {"path": "ga_s2am_nbart_3-2-1_55HGA_2019-11-21_final_band05.tif"}, "nbart_red_edge_2": {"path": "ga_s2am_nbart_3-2-1_55HGA_2019-11-21_final_band06.tif"}, "nbart_red_edge_3": {"path": "ga_s2am_nbart_3-2-1_55HGA_2019-11-21_final_band07.tif"}, "oa_exiting_angle": {"path": "ga_s2am_oa_3-2-1_55HGA_2019-11-21_final_exiting-angle.tif"}, "oa_solar_azimuth": {"path": "ga_s2am_oa_3-2-1_55HGA_2019-11-21_final_solar-azimuth.tif"}, "oa_incident_angle": {"path": "ga_s2am_oa_3-2-1_55HGA_2019-11-21_final_incident-angle.tif"}, "oa_relative_slope": {"path": "ga_s2am_oa_3-2-1_55HGA_2019-11-21_final_relative-slope.tif"}, "oa_satellite_view": {"path": "ga_s2am_oa_3-2-1_55HGA_2019-11-21_final_satellite-view.tif"}, "oa_nbart_contiguity": {"grid": "10", "path": "ga_s2am_oa_3-2-1_55HGA_2019-11-21_final_nbart-contiguity.tif"}, "oa_relative_azimuth": {"path": "ga_s2am_oa_3-2-1_55HGA_2019-11-21_final_relative-azimuth.tif"}, "oa_s2cloudless_mask": {"grid": "60", "path": "ga_s2am_oa_3-2-1_55HGA_2019-11-21_final_s2cloudless-mask.tif"}, "oa_s2cloudless_prob": {"grid": "60", "path": "ga_s2am_oa_3-2-1_55HGA_2019-11-21_final_s2cloudless-prob.tif"}, "oa_azimuthal_exiting": {"path": "ga_s2am_oa_3-2-1_55HGA_2019-11-21_final_azimuthal-exiting.tif"}, "oa_satellite_azimuth": {"path": "ga_s2am_oa_3-2-1_55HGA_2019-11-21_final_satellite-azimuth.tif"}, "nbart_coastal_aerosol": {"grid": "60", "path": "ga_s2am_nbart_3-2-1_55HGA_2019-11-21_final_band01.tif"}, "oa_azimuthal_incident": {"path": "ga_s2am_oa_3-2-1_55HGA_2019-11-21_final_azimuthal-incident.tif"}, "oa_combined_terrain_shadow": {"path": "ga_s2am_oa_3-2-1_55HGA_2019-11-21_final_combined-terrain-shadow.tif"}}}	\N	2023-10-25 02:25:03.101791+00	odcuser	\N
\.


--
-- Data for Name: dataset_location; Type: TABLE DATA; Schema: agdc; Owner: agdc_admin
--

COPY agdc.dataset_location (id, dataset_ref, uri_scheme, uri_body, added, added_by, archived) FROM stdin;
1	52dda32c-cb4b-49eb-a31d-bcf70bf62751	https	//data.dea.ga.gov.au/baseline/ga_s2am_ard_3/55/HGA/2019/11/21/20191121T011741/ga_s2am_ard_3-2-1_55HGA_2019-11-21_final.odc-metadata.yaml	2023-10-25 02:25:03.101791+00	odcuser	\N
\.


--
-- Data for Name: dataset_source; Type: TABLE DATA; Schema: agdc; Owner: agdc_admin
--

COPY agdc.dataset_source (dataset_ref, classifier, source_dataset_ref) FROM stdin;
\.


--
-- Data for Name: dataset_type; Type: TABLE DATA; Schema: agdc; Owner: agdc_admin
--

COPY agdc.dataset_type (id, name, metadata, metadata_type_ref, definition, added, added_by, updated) FROM stdin;
1	ga_s2am_ard_3	{"product": {"name": "ga_s2am_ard_3"}, "properties": {"eo:platform": "sentinel-2a", "odc:producer": "ga.gov.au", "eo:instrument": "MSI", "odc:product_family": "ard", "dea:product_maturity": "stable"}}	4	{"load": {"crs": "EPSG:3577", "align": {"x": 0, "y": 0}, "resolution": {"x": 10, "y": -10}}, "name": "ga_s2am_ard_3", "license": "CC-BY-4.0", "metadata": {"product": {"name": "ga_s2am_ard_3"}, "properties": {"eo:platform": "sentinel-2a", "odc:producer": "ga.gov.au", "eo:instrument": "MSI", "odc:product_family": "ard", "dea:product_maturity": "stable"}}, "description": "Geoscience Australia Sentinel 2A MSI Analysis Ready Data Collection 3", "measurements": [{"name": "nbart_coastal_aerosol", "dtype": "int16", "units": "1", "nodata": -999, "aliases": ["nbart_band01", "coastal_aerosol"]}, {"name": "nbart_blue", "dtype": "int16", "units": "1", "nodata": -999, "aliases": ["nbart_band02", "blue"]}, {"name": "nbart_green", "dtype": "int16", "units": "1", "nodata": -999, "aliases": ["nbart_band03", "green"]}, {"name": "nbart_red", "dtype": "int16", "units": "1", "nodata": -999, "aliases": ["nbart_band04", "red"]}, {"name": "nbart_red_edge_1", "dtype": "int16", "units": "1", "nodata": -999, "aliases": ["nbart_band05", "red_edge_1"]}, {"name": "nbart_red_edge_2", "dtype": "int16", "units": "1", "nodata": -999, "aliases": ["nbart_band06", "red_edge_2"]}, {"name": "nbart_red_edge_3", "dtype": "int16", "units": "1", "nodata": -999, "aliases": ["nbart_band07", "red_edge_3"]}, {"name": "nbart_nir_1", "dtype": "int16", "units": "1", "nodata": -999, "aliases": ["nbart_band08", "nir_1", "nbart_common_nir"]}, {"name": "nbart_nir_2", "dtype": "int16", "units": "1", "nodata": -999, "aliases": ["nbart_band8a", "nir_2"]}, {"name": "nbart_swir_2", "dtype": "int16", "units": "1", "nodata": -999, "aliases": ["nbart_band11", "swir_2", "nbart_common_swir_1", "swir2"]}, {"name": "nbart_swir_3", "dtype": "int16", "units": "1", "nodata": -999, "aliases": ["nbart_band12", "swir_3", "nbart_common_swir_2"]}, {"name": "oa_fmask", "dtype": "uint8", "units": "1", "nodata": 0, "aliases": ["fmask"], "flags_definition": {"fmask": {"bits": [0, 1, 2, 3, 4, 5, 6, 7], "values": {"0": "nodata", "1": "valid", "2": "cloud", "3": "shadow", "4": "snow", "5": "water"}, "description": "Fmask"}}}, {"name": "oa_nbart_contiguity", "dtype": "uint8", "units": "1", "nodata": 255, "aliases": ["nbart_contiguity"], "flags_definition": {"contiguous": {"bits": [0], "values": {"0": false, "1": true}}}}, {"name": "oa_azimuthal_exiting", "dtype": "float32", "units": "1", "nodata": "NaN", "aliases": ["azimuthal_exiting"]}, {"name": "oa_azimuthal_incident", "dtype": "float32", "units": "1", "nodata": "NaN", "aliases": ["azimuthal_incident"]}, {"name": "oa_combined_terrain_shadow", "dtype": "uint8", "units": "1", "nodata": 255, "aliases": ["combined_terrain_shadow"]}, {"name": "oa_exiting_angle", "dtype": "float32", "units": "1", "nodata": "NaN", "aliases": ["exiting_angle"]}, {"name": "oa_incident_angle", "dtype": "float32", "units": "1", "nodata": "NaN", "aliases": ["incident_angle"]}, {"name": "oa_relative_azimuth", "dtype": "float32", "units": "1", "nodata": "NaN", "aliases": ["relative_azimuth"]}, {"name": "oa_relative_slope", "dtype": "float32", "units": "1", "nodata": "NaN", "aliases": ["relative_slope"]}, {"name": "oa_satellite_azimuth", "dtype": "float32", "units": "1", "nodata": "NaN", "aliases": ["satellite_azimuth"]}, {"name": "oa_satellite_view", "dtype": "float32", "units": "1", "nodata": "NaN", "aliases": ["satellite_view"]}, {"name": "oa_solar_azimuth", "dtype": "float32", "units": "1", "nodata": "NaN", "aliases": ["solar_azimuth"]}, {"name": "oa_solar_zenith", "dtype": "float32", "units": "1", "nodata": "NaN", "aliases": ["solar_zenith"]}, {"name": "oa_time_delta", "dtype": "float32", "units": "1", "nodata": "NaN", "aliases": ["time_delta"]}, {"name": "oa_s2cloudless_mask", "dtype": "uint8", "units": "1", "nodata": 0, "aliases": ["s2cloudless_mask"], "flags_definition": {"s2cloudless_mask": {"bits": [0, 1, 2], "values": {"0": "nodata", "1": "valid", "2": "cloud"}, "description": "s2cloudless mask"}}}, {"name": "oa_s2cloudless_prob", "dtype": "float64", "units": "1", "nodata": "NaN", "aliases": ["s2cloudless_prob"]}], "metadata_type": "eo3_sentinel_ard"}	2023-10-12 05:08:42.486782+00	odcuser	\N
\.


--
-- Data for Name: metadata_type; Type: TABLE DATA; Schema: agdc; Owner: agdc_admin
--

COPY agdc.metadata_type (id, name, definition, added, added_by, updated) FROM stdin;
1	eo3	{"name": "eo3", "dataset": {"id": ["id"], "label": ["label"], "format": ["properties", "odc:file_format"], "sources": ["lineage", "source_datasets"], "creation_dt": ["properties", "odc:processing_datetime"], "grid_spatial": ["grid_spatial", "projection"], "measurements": ["measurements"], "search_fields": {"lat": {"type": "double-range", "max_offset": [["extent", "lat", "end"]], "min_offset": [["extent", "lat", "begin"]], "description": "Latitude range"}, "lon": {"type": "double-range", "max_offset": [["extent", "lon", "end"]], "min_offset": [["extent", "lon", "begin"]], "description": "Longitude range"}, "time": {"type": "datetime-range", "max_offset": [["properties", "dtr:end_datetime"], ["properties", "datetime"]], "min_offset": [["properties", "dtr:start_datetime"], ["properties", "datetime"]], "description": "Acquisition time range"}, "platform": {"offset": ["properties", "eo:platform"], "indexed": false, "description": "Platform code"}, "instrument": {"offset": ["properties", "eo:instrument"], "indexed": false, "description": "Instrument name"}, "cloud_cover": {"type": "double", "offset": ["properties", "eo:cloud_cover"], "indexed": false, "description": "Cloud cover percentage [0, 100]"}, "region_code": {"offset": ["properties", "odc:region_code"], "description": "Spatial reference code from the provider. For Landsat region_code is a scene path row:\\n        '{:03d}{:03d}.format(path,row)'.\\nFor Sentinel it is MGRS code. In general it is a unique string identifier that datasets covering roughly the same spatial region share.\\n"}, "product_family": {"offset": ["properties", "odc:product_family"], "indexed": false, "description": "Product family code"}, "dataset_maturity": {"offset": ["properties", "dea:dataset_maturity"], "indexed": false, "description": "One of - final|interim|nrt  (near real time)"}}}, "description": "Default EO3 with no custom fields"}	2023-10-12 04:21:56.398805+00	odcuser	\N
2	eo	{"name": "eo", "dataset": {"id": ["id"], "label": ["ga_label"], "format": ["format", "name"], "sources": ["lineage", "source_datasets"], "creation_dt": ["creation_dt"], "grid_spatial": ["grid_spatial", "projection"], "measurements": ["image", "bands"], "search_fields": {"lat": {"type": "double-range", "max_offset": [["extent", "coord", "ur", "lat"], ["extent", "coord", "lr", "lat"], ["extent", "coord", "ul", "lat"], ["extent", "coord", "ll", "lat"]], "min_offset": [["extent", "coord", "ur", "lat"], ["extent", "coord", "lr", "lat"], ["extent", "coord", "ul", "lat"], ["extent", "coord", "ll", "lat"]], "description": "Latitude range"}, "lon": {"type": "double-range", "max_offset": [["extent", "coord", "ul", "lon"], ["extent", "coord", "ur", "lon"], ["extent", "coord", "ll", "lon"], ["extent", "coord", "lr", "lon"]], "min_offset": [["extent", "coord", "ul", "lon"], ["extent", "coord", "ur", "lon"], ["extent", "coord", "ll", "lon"], ["extent", "coord", "lr", "lon"]], "description": "Longitude range"}, "time": {"type": "datetime-range", "max_offset": [["extent", "to_dt"], ["extent", "center_dt"]], "min_offset": [["extent", "from_dt"], ["extent", "center_dt"]], "description": "Acquisition time"}, "platform": {"offset": ["platform", "code"], "description": "Platform code"}, "instrument": {"offset": ["instrument", "name"], "description": "Instrument name"}, "product_type": {"offset": ["product_type"], "description": "Product code"}}}, "description": "Earth Observation datasets.\\n\\nExpected metadata structure produced by the eodatasets library, as used internally at GA.\\n\\nhttps://github.com/GeoscienceAustralia/eo-datasets\\n"}	2023-10-12 04:21:56.434106+00	odcuser	\N
3	telemetry	{"name": "telemetry", "dataset": {"id": ["id"], "label": ["ga_label"], "sources": ["lineage", "source_datasets"], "creation_dt": ["creation_dt"], "search_fields": {"gsi": {"offset": ["acquisition", "groundstation", "code"], "indexed": false, "description": "Ground Station Identifier (eg. ASA)"}, "time": {"type": "datetime-range", "max_offset": [["acquisition", "los"]], "min_offset": [["acquisition", "aos"]], "description": "Acquisition time"}, "orbit": {"type": "integer", "offset": ["acquisition", "platform_orbit"], "description": "Orbit number"}, "sat_row": {"type": "integer-range", "max_offset": [["image", "satellite_ref_point_end", "y"], ["image", "satellite_ref_point_start", "y"]], "min_offset": [["image", "satellite_ref_point_start", "y"]], "description": "Landsat row"}, "platform": {"offset": ["platform", "code"], "description": "Platform code"}, "sat_path": {"type": "integer-range", "max_offset": [["image", "satellite_ref_point_end", "x"], ["image", "satellite_ref_point_start", "x"]], "min_offset": [["image", "satellite_ref_point_start", "x"]], "description": "Landsat path"}, "instrument": {"offset": ["instrument", "name"], "description": "Instrument name"}, "product_type": {"offset": ["product_type"], "description": "Product code"}}}, "description": "Satellite telemetry datasets.\\n\\nExpected metadata structure produced by telemetry datasets from the eodatasets library, as used internally at GA.\\n\\nhttps://github.com/GeoscienceAustralia/eo-datasets\\n"}	2023-10-12 04:21:56.465921+00	odcuser	\N
4	eo3_sentinel_ard	{"name": "eo3_sentinel_ard", "dataset": {"id": ["id"], "label": ["label"], "format": ["properties", "odc:file_format"], "sources": ["lineage", "source_datasets"], "creation_dt": ["properties", "odc:processing_datetime"], "grid_spatial": ["grid_spatial", "projection"], "measurements": ["measurements"], "search_fields": {"lat": {"type": "double-range", "max_offset": [["extent", "lat", "end"]], "min_offset": [["extent", "lat", "begin"]], "description": "Latitude range"}, "lon": {"type": "double-range", "max_offset": [["extent", "lon", "end"]], "min_offset": [["extent", "lon", "begin"]], "description": "Longitude range"}, "time": {"type": "datetime-range", "max_offset": [["properties", "dtr:end_datetime"], ["properties", "datetime"]], "min_offset": [["properties", "dtr:start_datetime"], ["properties", "datetime"]], "description": "Acquisition time range"}, "eo_gsd": {"type": "double", "offset": ["properties", "eo:gsd"], "indexed": false, "description": "Ground sampling distance of the sensor’s best resolution band\\nin metres; represents the size (or spatial resolution) of one pixel.\\n"}, "crs_raw": {"offset": ["crs"], "indexed": false, "description": "The raw CRS string as it appears in metadata\\n\\n(e.g. ‘epsg:32654’)\\n"}, "platform": {"offset": ["properties", "eo:platform"], "indexed": false, "description": "Platform code"}, "gqa_abs_x": {"type": "double", "offset": ["properties", "gqa:abs_x"], "indexed": false, "description": "Absolute value of the x-axis (east-to-west) GCP residuals, in pixel units based on a 25 metre resolution reference image (i.e. 0.2 = 5 metres)\\n"}, "gqa_abs_y": {"type": "double", "offset": ["properties", "gqa:abs_y"], "indexed": false, "description": "Absolute value of the y-axis (north-to-south) GCP residuals, in pixel units based on a 25 metre resolution reference image (i.e. 0.2 = 5 metres)\\n"}, "gqa_cep90": {"type": "double", "offset": ["properties", "gqa:cep90"], "indexed": false, "description": "Circular error probable (90%) of the values of the GCP residuals, in pixel units based on a 25 metre resolution reference image (i.e. 0.2 = 5 metres)\\n"}, "fmask_snow": {"type": "double", "offset": ["properties", "fmask:snow"], "indexed": false, "description": "The proportion (from 0 to 100) of the dataset's valid data area that contains clear snow pixels according to the Fmask algorithm\\n"}, "gqa_abs_xy": {"type": "double", "offset": ["properties", "gqa:abs_xy"], "indexed": false, "description": "Absolute value of the total GCP residuals, in pixel units based on a 25 metre resolution reference image (i.e. 0.2 = 5 metres)\\n"}, "gqa_mean_x": {"type": "double", "offset": ["properties", "gqa:mean_x"], "indexed": false, "description": "Mean of the values of the x-axis (east-to-west) GCP residuals, in pixel units based on a 25 metre resolution reference image (i.e. 0.2 = 5 metres)\\n"}, "gqa_mean_y": {"type": "double", "offset": ["properties", "gqa:mean_y"], "indexed": false, "description": "Mean of the values of the y-axis (north-to-south) GCP residuals, in pixel units based on a 25 metre resolution reference image (i.e. 0.2 = 5 metres)\\n"}, "instrument": {"offset": ["properties", "eo:instrument"], "indexed": false, "description": "Instrument name"}, "cloud_cover": {"type": "double", "offset": ["properties", "eo:cloud_cover"], "description": "The proportion (from 0 to 100) of the dataset's valid data area that contains cloud pixels.\\n\\nFor these ARD products, this value comes from the Fmask algorithm.\\n"}, "fmask_clear": {"type": "double", "offset": ["properties", "fmask:clear"], "indexed": false, "description": "The proportion (from 0 to 100) of the dataset's valid data area that contains clear land pixels according to the Fmask algorithm\\n"}, "fmask_water": {"type": "double", "offset": ["properties", "fmask:water"], "indexed": false, "description": "The proportion (from 0 to 100) of the dataset's valid data area that contains clear water pixels according to the Fmask algorithm\\n"}, "gqa_mean_xy": {"type": "double", "offset": ["properties", "gqa:mean_xy"], "indexed": false, "description": "Mean of the values of the GCP residuals, in pixel units based on a 25 metre resolution reference image (i.e. 0.2 = 5 metres)\\n"}, "region_code": {"offset": ["properties", "odc:region_code"], "description": "Spatial reference code from the provider.\\nFor Sentinel it is MGRS code.\\n"}, "gqa_stddev_x": {"type": "double", "offset": ["properties", "gqa:stddev_x"], "indexed": false, "description": "Standard Deviation of the values of the x-axis (east-to-west) GCP residuals, in pixel units based on a 25 metre resolution reference image (i.e. 0.2 = 5 metres)\\n"}, "gqa_stddev_y": {"type": "double", "offset": ["properties", "gqa:stddev_y"], "indexed": false, "description": "Standard Deviation of the values of the y-axis (north-to-south) GCP residuals, in pixel units based on a 25 metre resolution reference image (i.e. 0.2 = 5 metres)\\n"}, "gqa_stddev_xy": {"type": "double", "offset": ["properties", "gqa:stddev_xy"], "indexed": false, "description": "Standard Deviation of the values of the GCP residuals, in pixel units based on a 25 metre resolution reference image (i.e. 0.2 = 5 metres)\\n"}, "eo_sun_azimuth": {"type": "double", "offset": ["properties", "eo:sun_azimuth"], "indexed": false, "description": "The azimuth angle of the sun at the moment of acquisition, in degree units measured clockwise from due north\\n"}, "product_family": {"offset": ["properties", "odc:product_family"], "indexed": false, "description": "Product family code"}, "dataset_maturity": {"offset": ["properties", "dea:dataset_maturity"], "indexed": false, "description": "One of - final|interim|nrt  (near real time)"}, "eo_sun_elevation": {"type": "double", "offset": ["properties", "eo:sun_elevation"], "indexed": false, "description": "The elevation angle of the sun at the moment of acquisition, in degree units relative to the horizon.\\n"}, "sentinel_tile_id": {"offset": ["properties", "sentinel:sentinel_tile_id"], "indexed": false, "description": "Granule ID according to the ESA naming convention\\n\\n(e.g. ‘S2A_OPER_MSI_L1C_TL_SGS__20161214T040601_A007721_T53KRB_N02.04’)\\n"}, "s2cloudless_clear": {"type": "double", "offset": ["properties", "s2cloudless:clear"], "description": "The proportion (from 0 to 100) of the dataset's valid data area that contains clear land pixels according to s3cloudless\\n"}, "s2cloudless_cloud": {"type": "double", "offset": ["properties", "s2cloudless:cloud"], "description": "The proportion (from 0 to 100) of the dataset's valid data area that contains cloud land pixels according to s3cloudless\\n"}, "fmask_cloud_shadow": {"type": "double", "offset": ["properties", "fmask:cloud_shadow"], "indexed": false, "description": "The proportion (from 0 to 100) of the dataset's valid data area that contains cloud shadow pixels according to the Fmask algorithm\\n"}, "gqa_iterative_mean_x": {"type": "double", "offset": ["properties", "gqa:iterative_mean_x"], "indexed": false, "description": "Mean of the values of the x-axis (east-to-west) GCP residuals after removal of outliers, in pixel units based on a 25 metre resolution reference image (i.e. 0.2 = 5 metres)\\n"}, "gqa_iterative_mean_y": {"type": "double", "offset": ["properties", "gqa:iterative_mean_y"], "indexed": false, "description": "Mean of the values of the y-axis (north-to-south) GCP residuals after removal of outliers, in pixel units based on a 25 metre resolution reference image (i.e. 0.2 = 5 metres)\\n"}, "gqa_iterative_mean_xy": {"type": "double", "offset": ["properties", "gqa:iterative_mean_xy"], "indexed": false, "description": "Mean of the values of the GCP residuals after removal of outliers, in pixel units based on a 25 metre resolution reference image (i.e. 0.2 = 5 metres)\\n"}, "sentinel_datastrip_id": {"offset": ["properties", "sentinel:datastrip_id"], "indexed": false, "description": "Unique identifier for a datastrip relative to a given Datatake.\\n\\n(e.g. ‘S2A_OPER_MSI_L1C_DS_SGS__20161214T040601_S20161214T005840_N02.04’)\\n"}, "sentinel_product_name": {"offset": ["properties", "sentinel:product_name"], "indexed": false, "description": "ESA product URI, with the '.SAFE' ending removed.\\n\\n(e.g. 'S2A_MSIL1C_20220303T000731_N0400_R073_T56LNM_20220303T012845')\\n"}, "gqa_iterative_stddev_x": {"type": "double", "offset": ["properties", "gqa:iterative_stddev_x"], "indexed": false, "description": "Standard Deviation of the values of the x-axis (east-to-west) GCP residuals after removal of outliers, in pixel units based on a 25 metre resolution reference image (i.e. 0.2 = 5 metres)\\n"}, "gqa_iterative_stddev_y": {"type": "double", "offset": ["properties", "gqa:iterative_stddev_y"], "indexed": false, "description": "Standard Deviation of the values of the y-axis (north-to-south) GCP residuals after removal of outliers, in pixel units based on a 25 metre resolution reference image (i.e. 0.2 = 5 metres)\\n"}, "gqa_iterative_stddev_xy": {"type": "double", "offset": ["properties", "gqa:iterative_stddev_xy"], "indexed": false, "description": "Standard Deviation of the values of the GCP residuals after removal of outliers, in pixel units based on a 25 metre resolution reference image (i.e. 0.2 = 5 metres)\\n"}, "gqa_abs_iterative_mean_x": {"type": "double", "offset": ["properties", "gqa:abs_iterative_mean_x"], "indexed": false, "description": "Mean of the absolute values of the x-axis (east-to-west) GCP residuals after removal of outliers, in pixel units based on a 25 metre resolution reference image (i.e. 0.2 = 5 metres)\\n"}, "gqa_abs_iterative_mean_y": {"type": "double", "offset": ["properties", "gqa:abs_iterative_mean_y"], "indexed": false, "description": "Mean of the absolute values of the y-axis (north-to-south) GCP residuals after removal of outliers, in pixel units based on a 25 metre resolution reference image (i.e. 0.2 = 5 metres)\\n"}, "gqa_abs_iterative_mean_xy": {"type": "double", "offset": ["properties", "gqa:abs_iterative_mean_xy"], "indexed": false, "description": "Mean of the absolute values of the GCP residuals after removal of outliers, in pixel units based on a 25 metre resolution reference image (i.e. 0.2 = 5 metres)\\n"}}}, "description": "EO3 for Sentinel 2 ARD"}	2023-10-12 05:08:37.567988+00	odcuser	\N
\.


--
-- Data for Name: job; Type: TABLE DATA; Schema: cron; Owner: postgres
--

COPY cron.job (jobid, schedule, command, nodename, nodeport, database, username, active, jobname) FROM stdin;
\.


--
-- Data for Name: job_run_details; Type: TABLE DATA; Schema: cron; Owner: postgres
--

COPY cron.job_run_details (jobid, runid, job_pid, database, username, command, status, return_message, start_time, end_time) FROM stdin;
\.


--
-- Data for Name: spatial_ref_sys; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.spatial_ref_sys (srid, auth_name, auth_srid, srtext, proj4text) FROM stdin;
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
-- Name: dataset_location_id_seq; Type: SEQUENCE SET; Schema: agdc; Owner: agdc_admin
--

SELECT pg_catalog.setval('agdc.dataset_location_id_seq', 1, true);


--
-- Name: dataset_type_id_seq; Type: SEQUENCE SET; Schema: agdc; Owner: agdc_admin
--

SELECT pg_catalog.setval('agdc.dataset_type_id_seq', 1, true);


--
-- Name: metadata_type_id_seq; Type: SEQUENCE SET; Schema: agdc; Owner: agdc_admin
--

SELECT pg_catalog.setval('agdc.metadata_type_id_seq', 4, true);


--
-- Name: jobid_seq; Type: SEQUENCE SET; Schema: cron; Owner: postgres
--

SELECT pg_catalog.setval('cron.jobid_seq', 1, false);


--
-- Name: runid_seq; Type: SEQUENCE SET; Schema: cron; Owner: postgres
--

SELECT pg_catalog.setval('cron.runid_seq', 1, false);


--
-- Name: dataset pk_dataset; Type: CONSTRAINT; Schema: agdc; Owner: agdc_admin
--

ALTER TABLE ONLY agdc.dataset
    ADD CONSTRAINT pk_dataset PRIMARY KEY (id);


--
-- Name: dataset_location pk_dataset_location; Type: CONSTRAINT; Schema: agdc; Owner: agdc_admin
--

ALTER TABLE ONLY agdc.dataset_location
    ADD CONSTRAINT pk_dataset_location PRIMARY KEY (id);


--
-- Name: dataset_source pk_dataset_source; Type: CONSTRAINT; Schema: agdc; Owner: agdc_admin
--

ALTER TABLE ONLY agdc.dataset_source
    ADD CONSTRAINT pk_dataset_source PRIMARY KEY (dataset_ref, classifier);


--
-- Name: dataset_type pk_dataset_type; Type: CONSTRAINT; Schema: agdc; Owner: agdc_admin
--

ALTER TABLE ONLY agdc.dataset_type
    ADD CONSTRAINT pk_dataset_type PRIMARY KEY (id);


--
-- Name: metadata_type pk_metadata_type; Type: CONSTRAINT; Schema: agdc; Owner: agdc_admin
--

ALTER TABLE ONLY agdc.metadata_type
    ADD CONSTRAINT pk_metadata_type PRIMARY KEY (id);


--
-- Name: dataset_location uq_dataset_location_uri_scheme; Type: CONSTRAINT; Schema: agdc; Owner: agdc_admin
--

ALTER TABLE ONLY agdc.dataset_location
    ADD CONSTRAINT uq_dataset_location_uri_scheme UNIQUE (uri_scheme, uri_body, dataset_ref);


--
-- Name: dataset_source uq_dataset_source_source_dataset_ref; Type: CONSTRAINT; Schema: agdc; Owner: agdc_admin
--

ALTER TABLE ONLY agdc.dataset_source
    ADD CONSTRAINT uq_dataset_source_source_dataset_ref UNIQUE (source_dataset_ref, dataset_ref);


--
-- Name: dataset_type uq_dataset_type_name; Type: CONSTRAINT; Schema: agdc; Owner: agdc_admin
--

ALTER TABLE ONLY agdc.dataset_type
    ADD CONSTRAINT uq_dataset_type_name UNIQUE (name);


--
-- Name: metadata_type uq_metadata_type_name; Type: CONSTRAINT; Schema: agdc; Owner: agdc_admin
--

ALTER TABLE ONLY agdc.metadata_type
    ADD CONSTRAINT uq_metadata_type_name UNIQUE (name);


--
-- Name: dix_ga_s2am_ard_3_cloud_cover; Type: INDEX; Schema: agdc; Owner: agdc_admin
--

CREATE INDEX dix_ga_s2am_ard_3_cloud_cover ON agdc.dataset USING btree ((((metadata #>> '{properties,eo:cloud_cover}'::text[]))::double precision)) WHERE ((archived IS NULL) AND (dataset_type_ref = 1));


--
-- Name: dix_ga_s2am_ard_3_lat_lon_time; Type: INDEX; Schema: agdc; Owner: agdc_admin
--

CREATE INDEX dix_ga_s2am_ard_3_lat_lon_time ON agdc.dataset USING gist (agdc.float8range(((metadata #>> '{extent,lat,begin}'::text[]))::double precision, ((metadata #>> '{extent,lat,end}'::text[]))::double precision, '[]'::text), agdc.float8range(((metadata #>> '{extent,lon,begin}'::text[]))::double precision, ((metadata #>> '{extent,lon,end}'::text[]))::double precision, '[]'::text), tstzrange(LEAST(agdc.common_timestamp((metadata #>> '{properties,dtr:start_datetime}'::text[])), agdc.common_timestamp((metadata #>> '{properties,datetime}'::text[]))), GREATEST(agdc.common_timestamp((metadata #>> '{properties,dtr:end_datetime}'::text[])), agdc.common_timestamp((metadata #>> '{properties,datetime}'::text[]))), '[]'::text)) WHERE ((archived IS NULL) AND (dataset_type_ref = 1));


--
-- Name: dix_ga_s2am_ard_3_region_code; Type: INDEX; Schema: agdc; Owner: agdc_admin
--

CREATE INDEX dix_ga_s2am_ard_3_region_code ON agdc.dataset USING btree (((metadata #>> '{properties,odc:region_code}'::text[]))) WHERE ((archived IS NULL) AND (dataset_type_ref = 1));


--
-- Name: dix_ga_s2am_ard_3_s2cloudless_clear; Type: INDEX; Schema: agdc; Owner: agdc_admin
--

CREATE INDEX dix_ga_s2am_ard_3_s2cloudless_clear ON agdc.dataset USING btree ((((metadata #>> '{properties,s2cloudless:clear}'::text[]))::double precision)) WHERE ((archived IS NULL) AND (dataset_type_ref = 1));


--
-- Name: dix_ga_s2am_ard_3_s2cloudless_cloud; Type: INDEX; Schema: agdc; Owner: agdc_admin
--

CREATE INDEX dix_ga_s2am_ard_3_s2cloudless_cloud ON agdc.dataset USING btree ((((metadata #>> '{properties,s2cloudless:cloud}'::text[]))::double precision)) WHERE ((archived IS NULL) AND (dataset_type_ref = 1));


--
-- Name: dix_ga_s2am_ard_3_time_lat_lon; Type: INDEX; Schema: agdc; Owner: agdc_admin
--

CREATE INDEX dix_ga_s2am_ard_3_time_lat_lon ON agdc.dataset USING gist (tstzrange(LEAST(agdc.common_timestamp((metadata #>> '{properties,dtr:start_datetime}'::text[])), agdc.common_timestamp((metadata #>> '{properties,datetime}'::text[]))), GREATEST(agdc.common_timestamp((metadata #>> '{properties,dtr:end_datetime}'::text[])), agdc.common_timestamp((metadata #>> '{properties,datetime}'::text[]))), '[]'::text), agdc.float8range(((metadata #>> '{extent,lat,begin}'::text[]))::double precision, ((metadata #>> '{extent,lat,end}'::text[]))::double precision, '[]'::text), agdc.float8range(((metadata #>> '{extent,lon,begin}'::text[]))::double precision, ((metadata #>> '{extent,lon,end}'::text[]))::double precision, '[]'::text)) WHERE ((archived IS NULL) AND (dataset_type_ref = 1));


--
-- Name: ix_agdc_dataset_dataset_type_ref; Type: INDEX; Schema: agdc; Owner: agdc_admin
--

CREATE INDEX ix_agdc_dataset_dataset_type_ref ON agdc.dataset USING btree (dataset_type_ref);


--
-- Name: ix_agdc_dataset_location_dataset_ref; Type: INDEX; Schema: agdc; Owner: agdc_admin
--

CREATE INDEX ix_agdc_dataset_location_dataset_ref ON agdc.dataset_location USING btree (dataset_ref);


--
-- Name: dataset row_update_time_dataset; Type: TRIGGER; Schema: agdc; Owner: agdc_admin
--

CREATE TRIGGER row_update_time_dataset BEFORE UPDATE ON agdc.dataset FOR EACH ROW EXECUTE FUNCTION agdc.set_row_update_time();


--
-- Name: dataset_type row_update_time_dataset_type; Type: TRIGGER; Schema: agdc; Owner: agdc_admin
--

CREATE TRIGGER row_update_time_dataset_type BEFORE UPDATE ON agdc.dataset_type FOR EACH ROW EXECUTE FUNCTION agdc.set_row_update_time();


--
-- Name: metadata_type row_update_time_metadata_type; Type: TRIGGER; Schema: agdc; Owner: agdc_admin
--

CREATE TRIGGER row_update_time_metadata_type BEFORE UPDATE ON agdc.metadata_type FOR EACH ROW EXECUTE FUNCTION agdc.set_row_update_time();


--
-- Name: dataset fk_dataset_dataset_type_ref_dataset_type; Type: FK CONSTRAINT; Schema: agdc; Owner: agdc_admin
--

ALTER TABLE ONLY agdc.dataset
    ADD CONSTRAINT fk_dataset_dataset_type_ref_dataset_type FOREIGN KEY (dataset_type_ref) REFERENCES agdc.dataset_type(id);


--
-- Name: dataset_location fk_dataset_location_dataset_ref_dataset; Type: FK CONSTRAINT; Schema: agdc; Owner: agdc_admin
--

ALTER TABLE ONLY agdc.dataset_location
    ADD CONSTRAINT fk_dataset_location_dataset_ref_dataset FOREIGN KEY (dataset_ref) REFERENCES agdc.dataset(id);


--
-- Name: dataset fk_dataset_metadata_type_ref_metadata_type; Type: FK CONSTRAINT; Schema: agdc; Owner: agdc_admin
--

ALTER TABLE ONLY agdc.dataset
    ADD CONSTRAINT fk_dataset_metadata_type_ref_metadata_type FOREIGN KEY (metadata_type_ref) REFERENCES agdc.metadata_type(id);


--
-- Name: dataset_source fk_dataset_source_dataset_ref_dataset; Type: FK CONSTRAINT; Schema: agdc; Owner: agdc_admin
--

ALTER TABLE ONLY agdc.dataset_source
    ADD CONSTRAINT fk_dataset_source_dataset_ref_dataset FOREIGN KEY (dataset_ref) REFERENCES agdc.dataset(id);


--
-- Name: dataset_source fk_dataset_source_source_dataset_ref_dataset; Type: FK CONSTRAINT; Schema: agdc; Owner: agdc_admin
--

ALTER TABLE ONLY agdc.dataset_source
    ADD CONSTRAINT fk_dataset_source_source_dataset_ref_dataset FOREIGN KEY (source_dataset_ref) REFERENCES agdc.dataset(id);


--
-- Name: dataset_type fk_dataset_type_metadata_type_ref_metadata_type; Type: FK CONSTRAINT; Schema: agdc; Owner: agdc_admin
--

ALTER TABLE ONLY agdc.dataset_type
    ADD CONSTRAINT fk_dataset_type_metadata_type_ref_metadata_type FOREIGN KEY (metadata_type_ref) REFERENCES agdc.metadata_type(id);


--
-- Name: job cron_job_policy; Type: POLICY; Schema: cron; Owner: postgres
--

CREATE POLICY cron_job_policy ON cron.job USING ((username = CURRENT_USER));


--
-- Name: job_run_details cron_job_run_details_policy; Type: POLICY; Schema: cron; Owner: postgres
--

CREATE POLICY cron_job_run_details_policy ON cron.job_run_details USING ((username = CURRENT_USER));


--
-- Name: job; Type: ROW SECURITY; Schema: cron; Owner: postgres
--

ALTER TABLE cron.job ENABLE ROW LEVEL SECURITY;

--
-- Name: job_run_details; Type: ROW SECURITY; Schema: cron; Owner: postgres
--

ALTER TABLE cron.job_run_details ENABLE ROW LEVEL SECURITY;

--
-- Name: SCHEMA agdc; Type: ACL; Schema: -; Owner: agdc_admin
--

GRANT USAGE ON SCHEMA agdc TO agdc_user;
GRANT CREATE ON SCHEMA agdc TO agdc_manage;


--
-- Name: FUNCTION common_timestamp(text); Type: ACL; Schema: agdc; Owner: agdc_admin
--

GRANT ALL ON FUNCTION agdc.common_timestamp(text) TO agdc_user;


--
-- Name: TABLE dataset; Type: ACL; Schema: agdc; Owner: agdc_admin
--

GRANT SELECT ON TABLE agdc.dataset TO agdc_user;
GRANT INSERT ON TABLE agdc.dataset TO agdc_ingest;


--
-- Name: TABLE dataset_location; Type: ACL; Schema: agdc; Owner: agdc_admin
--

GRANT SELECT ON TABLE agdc.dataset_location TO agdc_user;
GRANT INSERT ON TABLE agdc.dataset_location TO agdc_ingest;


--
-- Name: SEQUENCE dataset_location_id_seq; Type: ACL; Schema: agdc; Owner: agdc_admin
--

GRANT SELECT,USAGE ON SEQUENCE agdc.dataset_location_id_seq TO agdc_ingest;


--
-- Name: TABLE dataset_source; Type: ACL; Schema: agdc; Owner: agdc_admin
--

GRANT SELECT ON TABLE agdc.dataset_source TO agdc_user;
GRANT INSERT ON TABLE agdc.dataset_source TO agdc_ingest;


--
-- Name: TABLE dataset_type; Type: ACL; Schema: agdc; Owner: agdc_admin
--

GRANT SELECT ON TABLE agdc.dataset_type TO agdc_user;
GRANT INSERT,DELETE ON TABLE agdc.dataset_type TO agdc_manage;


--
-- Name: SEQUENCE dataset_type_id_seq; Type: ACL; Schema: agdc; Owner: agdc_admin
--

GRANT SELECT,USAGE ON SEQUENCE agdc.dataset_type_id_seq TO agdc_ingest;


--
-- Name: TABLE metadata_type; Type: ACL; Schema: agdc; Owner: agdc_admin
--

GRANT SELECT ON TABLE agdc.metadata_type TO agdc_user;
GRANT INSERT,DELETE ON TABLE agdc.metadata_type TO agdc_manage;


--
-- Name: SEQUENCE metadata_type_id_seq; Type: ACL; Schema: agdc; Owner: agdc_admin
--

GRANT SELECT,USAGE ON SEQUENCE agdc.metadata_type_id_seq TO agdc_ingest;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: odcuser
--

ALTER DEFAULT PRIVILEGES FOR ROLE odcuser IN SCHEMA public GRANT SELECT ON TABLES  TO replicator;


--
-- PostgreSQL database dump complete
--

