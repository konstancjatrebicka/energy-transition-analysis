-- ============================================================
-- Project : Energy Transition Analysis — Poland vs EU-27
-- File    : 02_exploratory_analysis.sql
-- Purpose : Exploratory SQL queries used to validate data,
--           understand distributions, and develop analytical
--           logic before formalising into views (file 03)
-- Note    : These queries are kept for transparency and to
--           document the analytical reasoning process
-- Author  : Konstancja Trębicka
-- ============================================================


-- ============================================================
-- QUERY 1: Year-over-year change per country and indicator
-- ------------------------------------------------------------
--   How does each country's indicator value change year-over-year?
--   Which countries show consistent improvement vs. volatility?
-- Purpose:
--   Identify acceleration or deceleration of energy transition.
--   LAG() window function computes the difference between the
--   current year and the previous year within each country-indicator group.
-- ============================================================

SELECT
    country_code,
    year,
    indicator_code,
    value,
    value - LAG(value) OVER (
        PARTITION BY country_code, indicator_code
        ORDER BY year
    ) AS yoy_change
FROM fact_indicator_value
ORDER BY country_code, indicator_code, year;


-- ============================================================
-- QUERY 2: Country ranking within EU-27 per year and indicator
-- ------------------------------------------------------------
--   Where does each country rank within the EU-27 for a given
--   year and indicator? Is Poland's ranking improving over time?
-- Purpose:
--   Contextualise absolute values within a competitive EU frame.
--   RANK() with PARTITION BY year ensures each year is ranked
--   independently. Direction is indicator-specific:
--     GHG_PC:    ASC (lower emissions = better rank)
--     REN_SHARE: DESC (higher renewable share = better rank)
-- ============================================================

SELECT
    country_code,
    year,
    indicator_code,
    value,
    CASE
        WHEN indicator_code = 'REN_SHARE' THEN
            RANK() OVER (
                PARTITION BY year, indicator_code
                ORDER BY value DESC  -- higher renewable share = better
            )
        WHEN indicator_code = 'GHG_PC' THEN
            RANK() OVER (
                PARTITION BY year, indicator_code
                ORDER BY value ASC   -- lower emissions = better
            )
    END AS rank_in_eu
FROM fact_indicator_value
WHERE country_code <> 'EU27_2020'   -- exclude aggregate from country rankings
ORDER BY indicator_code, year, rank_in_eu;


-- ============================================================
-- QUERY 3: Poland's gap relative to EU-27 average per year
-- ------------------------------------------------------------
--   Is Poland closing the gap to the EU-27 average over time,
--   or is the distance growing?
-- Purpose:
--   Core analytical question of the project. Self-JOIN on
--   fact_indicator_value compares Poland's value to the EU
--   aggregate row (EU27_2020) for each year and indicator.
-- Note:
--   This query uses the Eurostat EU27_2020 aggregate, which
--   differs slightly from the unweighted average used in the
--   Power BI dashboard (see views in file 03 for methodology).
-- ============================================================

SELECT
    pl.year,
    pl.indicator_code,
    pl.value                    AS poland_value,
    eu.value                    AS eu_aggregate_value,
    pl.value - eu.value         AS gap_poland_vs_eu
FROM fact_indicator_value pl
JOIN fact_indicator_value eu
    ON  pl.year             = eu.year
    AND pl.indicator_code   = eu.indicator_code
WHERE pl.country_code = 'PL'
  AND eu.country_code = 'EU27_2020'
ORDER BY pl.indicator_code, pl.year;
