-- ============================================================
-- Project : Energy Transition Analysis — Poland vs EU-27
-- File    : 03_views_for_powerbi.sql
-- Purpose : Analytical views consumed by Power BI dashboard.
--           Each view corresponds to a specific analytical
--           question and feeds one or more dashboard visuals.
-- Author  : Konstancja Trębicka
-- ============================================================


-- ============================================================
-- VIEW 1: v_poland_vs_eu
-- ------------------------------------------------------------
--   How does Poland's indicator value compare to the EU-27
--   average each year, and is the gap growing or shrinking?
-- Methodology note:
--   EU-27 average is calculated as an unweighted arithmetic
--   mean of 27 member states (AVG over is_eu27=1, is_aggregate=0).
--   This differs from the Eurostat EU aggregate which is
--   population-weighted. Choice is deliberate: ensures
--   consistency across both indicators regardless of aggregate
--   availability in each dataset.
-- ============================================================

CREATE OR REPLACE VIEW v_poland_vs_eu AS
WITH eu_avg AS (
    SELECT
        f.year,
        f.indicator_code,
        AVG(f.value) AS eu_value   -- unweighted mean of 27 member states
    FROM fact_indicator_value f
    JOIN dim_country d ON d.country_code = f.country_code
    WHERE d.is_eu27      = 1
      AND d.is_aggregate = 0        -- exclude EU27_2020 aggregate row
      AND f.value IS NOT NULL       -- exclude missing data from average
    GROUP BY f.year, f.indicator_code
)
SELECT
    pl.year,
    pl.indicator_code,
    pl.value            AS poland_value,
    eu.eu_value,
    pl.value - eu.eu_value AS gap_pl_vs_eu   -- positive = Poland above EU avg
FROM fact_indicator_value pl
JOIN eu_avg eu
    ON  pl.year           = eu.year
    AND pl.indicator_code = eu.indicator_code
WHERE pl.country_code = 'PL';


-- ============================================================
-- VIEW 2: v_yoy_change
-- ------------------------------------------------------------
--   What is the year-over-year change in indicator value
--   for each country? Which years show the biggest shifts?
-- Note:
--   First year (2013) will have NULL yoy_change — expected behaviour.
-- ============================================================

CREATE OR REPLACE VIEW v_yoy_change AS
SELECT
    country_code,
    year,
    indicator_code,
    value,
    value - LAG(value) OVER (
        PARTITION BY country_code, indicator_code
        ORDER BY year
    ) AS yoy_change
FROM fact_indicator_value;


-- ============================================================
-- VIEW 3: v_country_rankings
-- ------------------------------------------------------------
--   How does each EU-27 country rank per year and indicator?
--   Is Poland's rank improving or declining over time?
-- Note:
--   Ranking direction is indicator-specific:
--     GHG_PC: ASC (lower emissions = rank 1 = best)
--     REN_SHARE: DESC (higher renewable share = rank 1 = best)
-- ============================================================

CREATE OR REPLACE VIEW v_country_rankings AS
SELECT
    country_code,
    year,
    indicator_code,
    value,
    CASE
        WHEN indicator_code = 'REN_SHARE' THEN
            RANK() OVER (
                PARTITION BY year, indicator_code
                ORDER BY value DESC
            )
        WHEN indicator_code = 'GHG_PC' THEN
            RANK() OVER (
                PARTITION BY year, indicator_code
                ORDER BY value ASC
            )
    END AS rank_in_eu
FROM fact_indicator_value
WHERE country_code <> 'EU27_2020';   -- exclude aggregate from country rankings


-- ============================================================
-- VIEW 4: v_change_over_period
-- ------------------------------------------------------------
--   How much did each country's indicator change from the
--   first to the last available year (2013 → 2024)?
--   Which countries improved the most in absolute and
--   percentage terms?
-- ============================================================

CREATE OR REPLACE VIEW v_change_over_period AS
WITH first_last AS (
    SELECT
        country_code,
        indicator_code,
        -- First available value, earliest year
        FIRST_VALUE(value) OVER (
            PARTITION BY country_code, indicator_code
            ORDER BY year
        ) AS start_value,
        FIRST_VALUE(year) OVER (
            PARTITION BY country_code, indicator_code
            ORDER BY year
        ) AS start_year,
        -- Last available value, latest year
        FIRST_VALUE(value) OVER (
            PARTITION BY country_code, indicator_code
            ORDER BY year DESC
        ) AS end_value,
        FIRST_VALUE(year) OVER (
            PARTITION BY country_code, indicator_code
            ORDER BY year DESC
        ) AS end_year
    FROM fact_indicator_value
)
SELECT DISTINCT
    country_code,
    indicator_code,
    first_year,
    last_year,
    start_value,
    end_value,
    end_value - start_value                                        AS absolute_change,
    CASE
		WHEN start_value = 0 OR start_value IS NULL THEN null
        ELSE (end_value - start_value) / start_value * 100
	END AS percent_change
FROM first_last;


-- ============================================================
-- VIEW 5: v_trend_index
-- ------------------------------------------------------------
--   Indexed to 2013 = 100, how does each country's trend
--   compare over time regardless of absolute starting level?
--   This normalises the comparison across countries with
--   very different baseline values.
-- ============================================================

CREATE OR REPLACE VIEW v_trend_index AS
WITH base AS (
    -- Anchor year: 2013 = 100 for all countries and indicators
    SELECT
        country_code,
        indicator_code,
        value AS base_value
    FROM fact_indicator_value
    WHERE year = 2013
),
indexed AS (
    SELECT
        f.country_code,
        f.year,
        f.indicator_code,
        f.value,
        b.base_value,
        ROUND((f.value / b.base_value) * 100, 2) AS trend_index_2013_100
    FROM fact_indicator_value f
    JOIN base b
        ON  f.country_code    = b.country_code
        AND f.indicator_code  = b.indicator_code
    WHERE b.base_value IS NOT NULL
      AND b.base_value <> 0   -- avoid division by zero
)
SELECT * FROM indexed;


-- ============================================================
-- VIEW 6: v_cagr
-- ------------------------------------------------------------
--   What is the compound annual growth rate (CAGR) of each
--   country's indicator over the analysis period?
--   CAGR smooths year-to-year volatility and enables fair
--   comparison of long-term trends across countries.
-- Formula:
--   CAGR = (last_value / first_value) ^ (1 / periods) - 1
-- ============================================================

CREATE OR REPLACE VIEW v_cagr AS
WITH first_last AS (
    SELECT
        country_code,
        indicator_code,
        MIN(year) AS first_year,
        MAX(year) AS last_year
    FROM fact_indicator_value
    WHERE value IS NOT NULL
    GROUP BY country_code, indicator_code
),
values_joined AS (
    SELECT
        fl.country_code,
        fl.indicator_code,
        fl.first_year,
        fl.last_year,
        f1.value                            AS start_value,
        f2.value                            AS end_value,
        fl.last_year - fl.first_year        AS periods
    FROM first_last fl
    JOIN fact_indicator_value f1
        ON  fl.country_code   = f1.country_code
        AND fl.indicator_code = f1.indicator_code
        AND fl.first_year     = f1.year
    JOIN fact_indicator_value f2
        ON  fl.country_code   = f2.country_code
        AND fl.indicator_code = f2.indicator_code
        AND fl.last_year      = f2.year
)
SELECT
    country_code,
    indicator_code,
    first_year,
    last_year,
    start_value,
    end_value,
    periods,
    ROUND(
        (POW(end_value / start_value, 1.0 / periods) - 1) * 100,
        2
    ) AS cagr_percent
FROM values_joined
WHERE start_value  IS NOT NULL
  AND end_value   IS NOT NULL
  AND start_value  > 0          -- CAGR undefined for zero or negative base
  AND periods      > 0;


-- ============================================================
-- VIEW 7: v_energy_climate_indicators
-- ------------------------------------------------------------
-- Purpose:
--   Denormalised master view joining fact table with both
--   dimension tables. Provides a single flat view with all
--   context needed for ad-hoc analysis and Power BI import.
-- ============================================================

CREATE OR REPLACE VIEW v_energy_climate_indicators AS
SELECT
    f.country_code,
    d.country_name,
    d.is_eu27,
    d.is_aggregate,
    f.year,
    f.indicator_code,
    i.indicator_name,
    i.unit,
    f.value
FROM fact_indicator_value f
JOIN dim_country  d ON f.country_code   = d.country_code
JOIN dim_indicator i ON f.indicator_code = i.indicator_code;
