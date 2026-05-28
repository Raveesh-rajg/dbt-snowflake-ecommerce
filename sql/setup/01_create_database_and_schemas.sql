-- ============================================================================
-- File:        01_create_database_and_schemas.sql
-- Project:     dbt-snowflake-ecommerce (Project 1 of portfolio)
-- Purpose:     Bootstrap Snowflake objects for Olist e-commerce analytics
-- Author:      Raveesh Grandhi
-- ============================================================================
-- This script is idempotent: safe to run multiple times.
-- Run as ACCOUNTADMIN. Creates database, schemas (medallion architecture),
-- and a cost-optimized warehouse for dbt development work.
-- ============================================================================

USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS OLIST_DB
  COMMENT = 'Brazilian e-commerce analytics platform - Project 1 portfolio';

USE DATABASE OLIST_DB;

CREATE SCHEMA IF NOT EXISTS RAW
  COMMENT = 'Bronze layer: data as loaded from source, no transformations';

CREATE SCHEMA IF NOT EXISTS STAGING
  COMMENT = 'Silver layer: cleaned, renamed, typed - one model per source table';

CREATE SCHEMA IF NOT EXISTS MARTS
  COMMENT = 'Gold layer: business-ready fact and dimension tables for BI';

CREATE WAREHOUSE IF NOT EXISTS DEV_WH
  WITH WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Development warehouse for dbt runs - auto-suspends after 60s idle';