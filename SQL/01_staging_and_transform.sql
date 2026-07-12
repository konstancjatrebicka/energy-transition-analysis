-- ============================================================
-- Project : Energy Transition Analysis — Poland vs EU-27
-- File    : 01_staging_and_transform.sql
-- Purpose : Create staging tables, load raw Eurostat TSV data,
--           build star schema (fact_indicator_value + dim_country)
-- Source  : Eurostat datasets sdg_13_10 (GHG emissions per capita)
--           and nrg_ind_ren (share of renewable energy), 2013–2024
-- Author  : Konstancja Trębicka
-- ============================================================


-- ============================================================
-- SECTION 1: ENVIRONMENT SETUP
-- ============================================================

-- Enable local file loading (run once per session before LOAD DATA)
-- Required for LOAD DATA LOCAL INFILE to work in MySQL Workbench
SET GLOBAL local_infile = 1;


-- ============================================================
-- SECTION 2: STAGING TABLES
-- Raw data loaded as VARCHAR to avoid import errors on missing
-- values (':' in Eurostat TSV files) and trailing whitespace
-- ============================================================

-- Staging table for GHG emissions data (sdg_13_10)
CREATE TABLE stg_emissions (
  raw_key VARCHAR(100),   -- concatenated dimension key: freq,src_crf,unit,geo
  y2013 VARCHAR(20), y2014 VARCHAR(20), y2015 VARCHAR(20),
  y2016 VARCHAR(20), y2017 VARCHAR(20), y2018 VARCHAR(20),
  y2019 VARCHAR(20), y2020 VARCHAR(20), y2021 VARCHAR(20),
  y2022 VARCHAR(20), y2023 VARCHAR(20), y2024 VARCHAR(20)
);

-- Load raw TSV file into staging table
-- NOTE: Replace the file path with your local path to the downloaded Eurostat TSV file
-- Download from: https://ec.europa.eu/eurostat/databrowser/view/sdg_13_10
LOAD DATA LOCAL INFILE '/your/local/path/sdg_13_10_tabular.tsv'
INTO TABLE stg_emissions
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;


-- Staging table for renewable energy share data (nrg_ind_ren)
CREATE TABLE stg_renewables (
  raw_key VARCHAR(100),   -- concatenated dimension key: freq,nrg_bal,unit,geo
  y2013 VARCHAR(20), y2014 VARCHAR(20), y2015 VARCHAR(20),
  y2016 VARCHAR(20), y2017 VARCHAR(20), y2018 VARCHAR(20),
  y2019 VARCHAR(20), y2020 VARCHAR(20), y2021 VARCHAR(20),
  y2022 VARCHAR(20), y2023 VARCHAR(20), y2024 VARCHAR(20)
);

-- Load raw TSV file into staging table
-- NOTE: Replace the file path with your local path to the downloaded Eurostat TSV file
-- Download from: https://ec.europa.eu/eurostat/databrowser/view/nrg_ind_ren
LOAD DATA LOCAL INFILE '/your/local/path/nrg_ind_ren_tabular.tsv'
INTO TABLE stg_renewables
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;


-- ============================================================
-- SECTION 3: DIMENSION TABLE — dim_country
-- Canonical list of EU-27 member states + EU aggregate
-- Used as a filter to exclude non-EU countries present in
-- Eurostat files (e.g. NO, CH, TR)
-- is_aggregate flag separates EU27_2020 from individual countries
-- to prevent it from being included in country-level averages
-- ============================================================

CREATE TABLE dim_country (
  country_code VARCHAR(10) PRIMARY KEY,
  country_name VARCHAR(60),
  is_eu27      TINYINT,      -- 1 = EU member state, 0 = aggregate/non-member
  is_aggregate TINYINT       -- 1 = EU27 aggregate row, 0 = individual country
);

-- Insert all 27 EU member states + EU-27 aggregate
-- Note: Greece uses Eurostat code 'EL' (not ISO 'GR')
INSERT INTO dim_country (country_code, country_name, is_eu27, is_aggregate) VALUES
('AT','Austria',1,0),        ('BE','Belgium',1,0),
('BG','Bulgaria',1,0),       ('HR','Croatia',1,0),
('CY','Cyprus',1,0),         ('CZ','Czechia',1,0),
('DK','Denmark',1,0),        ('EE','Estonia',1,0),
('FI','Finland',1,0),        ('FR','France',1,0),
('DE','Germany',1,0),        ('EL','Greece',1,0),
('HU','Hungary',1,0),        ('IE','Ireland',1,0),
('IT','Italy',1,0),          ('LV','Latvia',1,0),
('LT','Lithuania',1,0),      ('LU','Luxembourg',1,0),
('MT','Malta',1,0),          ('NL','Netherlands',1,0),
('PL','Poland',1,0),         ('PT','Portugal',1,0),
('RO','Romania',1,0),        ('SK','Slovakia',1,0),
('SI','Slovenia',1,0),       ('ES','Spain',1,0),
('SE','Sweden',1,0),
('EU27_2020','European Union (27)',0,1);


-- ============================================================
-- SECTION 4: INDICATOR DIMENSION TABLE — dim_indicator
-- ============================================================

CREATE TABLE dim_indicator (
  indicator_code VARCHAR(20) PRIMARY KEY,
  indicator_name VARCHAR(100),
  unit           VARCHAR(50)
);

INSERT INTO dim_indicator VALUES
('GHG_PC',    'Greenhouse gas emissions per capita', 'tonnes CO2 equivalent per capita'),
('REN_SHARE', 'Share of renewable energy',           '% of gross final energy consumption');


-- ============================================================
-- SECTION 5: FACT TABLE — fact_indicator_value
-- Star schema fact table combining both indicators in long format
-- One row = one country x one year x one indicator
-- ============================================================

CREATE TABLE fact_indicator_value (
  country_code   VARCHAR(10),
  year           INT,
  indicator_code VARCHAR(20),
  value          DECIMAL(12,3)  -- NULL where Eurostat reports ':' (data not available)
);


-- ============================================================
-- SECTION 6: ETL — GHG EMISSIONS (sdg_13_10)
-- Steps:
--   1. Parse concatenated raw_key using SUBSTRING_INDEX
--   2. Filter to T_HAB (per capita) and TOTX4_MEMO (excl. LULUCF)
--   3. Unpivot 12 year columns into rows using UNION ALL
--   4. Convert ':' (missing) to NULL, cast text to DECIMAL
--   5. Filter to EU-27 canon via JOIN on dim_country
-- ============================================================

INSERT INTO fact_indicator_value (country_code, year, indicator_code, value)
WITH parsed AS (
    -- Parse the concatenated dimension key: freq,src_crf,unit,geo
    -- Filter to per-capita values (T_HAB) and standard sum variant (TOTX4_MEMO)
    SELECT
        SUBSTRING_INDEX(SUBSTRING_INDEX(raw_key, ',', 3), ',', -1) AS unit,
        SUBSTRING_INDEX(SUBSTRING_INDEX(raw_key, ',', 2), ',', -1) AS src_crf,
        SUBSTRING_INDEX(raw_key, ',', -1)                          AS geo,
        y2013, y2014, y2015, y2016, y2017, y2018,
        y2019, y2020, y2021, y2022, y2023, y2024
    FROM stg_emissions
    WHERE SUBSTRING_INDEX(SUBSTRING_INDEX(raw_key, ',', 3), ',', -1) = 'T_HAB'
      AND SUBSTRING_INDEX(SUBSTRING_INDEX(raw_key, ',', 2), ',', -1) = 'TOTX4_MEMO'
),
unpivoted AS (
    -- Unpivot 12 year columns into rows (wide to long format)
    -- MySQL has no native UNPIVOT, so UNION ALL is used instead
    SELECT geo, 2013 AS year, y2013 AS val FROM parsed
    UNION ALL SELECT geo, 2014, y2014 FROM parsed
    UNION ALL SELECT geo, 2015, y2015 FROM parsed
    UNION ALL SELECT geo, 2016, y2016 FROM parsed
    UNION ALL SELECT geo, 2017, y2017 FROM parsed
    UNION ALL SELECT geo, 2018, y2018 FROM parsed
    UNION ALL SELECT geo, 2019, y2019 FROM parsed
    UNION ALL SELECT geo, 2020, y2020 FROM parsed
    UNION ALL SELECT geo, 2021, y2021 FROM parsed
    UNION ALL SELECT geo, 2022, y2022 FROM parsed
    UNION ALL SELECT geo, 2023, y2023 FROM parsed
    UNION ALL SELECT geo, 2024, y2024 FROM parsed
)
SELECT
    u.geo                                                                    AS country_code,
    u.year,
    'GHG_PC'                                                                 AS indicator_code,
    -- Convert Eurostat missing value marker ':' to NULL (not zero)
    CASE WHEN TRIM(u.val) = ':' THEN NULL
         ELSE CAST(TRIM(u.val) AS DECIMAL(12,3))
    END                                                                      AS value
FROM unpivoted u
-- JOIN acts as a filter: only EU-27 countries and the EU aggregate pass through
JOIN dim_country d ON d.country_code = u.geo;


-- ============================================================
-- SECTION 7: ETL — RENEWABLE ENERGY SHARE (nrg_ind_ren)
-- Same pipeline as GHG; different dimension key structure:
--   freq,nrg_bal,unit,geo
-- Filter to REN (overall renewable share) and PC (percentage)
-- ============================================================

INSERT INTO fact_indicator_value (country_code, year, indicator_code, value)
WITH parsed AS (
    -- Parse the concatenated dimension key: freq,nrg_bal,unit,geo
    -- Filter to overall renewable share (REN) in percentage (PC)
    SELECT
        SUBSTRING_INDEX(SUBSTRING_INDEX(raw_key, ',', 2), ',', -1) AS nrg_bal,
        SUBSTRING_INDEX(SUBSTRING_INDEX(raw_key, ',', 3), ',', -1) AS unit,
        SUBSTRING_INDEX(raw_key, ',', -1)                          AS geo,
        y2013, y2014, y2015, y2016, y2017, y2018,
        y2019, y2020, y2021, y2022, y2023, y2024
    FROM stg_renewables
    WHERE SUBSTRING_INDEX(SUBSTRING_INDEX(raw_key, ',', 2), ',', -1) = 'REN'
      AND SUBSTRING_INDEX(SUBSTRING_INDEX(raw_key, ',', 3), ',', -1) = 'PC'
),
unpivoted AS (
    SELECT geo, 2013 AS year, y2013 AS val FROM parsed
    UNION ALL SELECT geo, 2014, y2014 FROM parsed
    UNION ALL SELECT geo, 2015, y2015 FROM parsed
    UNION ALL SELECT geo, 2016, y2016 FROM parsed
    UNION ALL SELECT geo, 2017, y2017 FROM parsed
    UNION ALL SELECT geo, 2018, y2018 FROM parsed
    UNION ALL SELECT geo, 2019, y2019 FROM parsed
    UNION ALL SELECT geo, 2020, y2020 FROM parsed
    UNION ALL SELECT geo, 2021, y2021 FROM parsed
    UNION ALL SELECT geo, 2022, y2022 FROM parsed
    UNION ALL SELECT geo, 2023, y2023 FROM parsed
    UNION ALL SELECT geo, 2024, y2024 FROM parsed
)
SELECT
    u.geo,
    u.year,
    'REN_SHARE'                                                              AS indicator_code,
    CASE WHEN TRIM(u.val) = ':' THEN NULL
         ELSE CAST(TRIM(u.val) AS DECIMAL(12,3))
    END                                                                      AS value
FROM unpivoted u
JOIN dim_country d ON d.country_code = u.geo;
