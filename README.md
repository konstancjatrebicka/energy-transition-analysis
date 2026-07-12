# Energy Transition Analysis: Poland vs EU-27

An end-to-end Business Intelligence project analysing Poland's energy transition compared with the EU-27 between 2013 and 2024.

The project transforms raw Eurostat data into an interactive Power BI dashboard using SQL data preparation, dimensional modelling and reusable DAX measures.

## Project Overview

| Category          | Details                                                     |
| ----------------- | ----------------------------------------------------------- |
| **Domain**        | Energy & Climate                                            |
| **Scope**         | Poland vs EU-27                                             |
| **Period**        | 2013–2024                                                   |
| **Data Source**   | Eurostat                                                    |
| **Database**      | MySQL 8                                                     |
| **Visualisation** | Power BI                                                    |
| **Indicators**    | Greenhouse gas emissions per capita, renewable energy share |

### Quick Links

* **Live Dashboard:** [Open the interactive report](https://app.powerbi.com/viewr=eyJrIjoiNDI2YWU4YmItNjAyYy00NGI5LTlkYTMtYTUyYmU5NTgxNjQ0IiwidCI6IjQ1NDIwZThkLTg1NTItNGEwMy05YjkyLWE5MzFlZjgzOWQzZiIsImMiOjh9)
* **Power BI Report:** [Download the PBIX file](PowerBI/Energy_Transition.pbix)
* **SQL Scripts:** [View SQL scripts](SQL/)
* **DAX Measures:** [View DAX measures](PowerBI/measures_energy_transition.txt)
  
---

## Business Question

> **How has Poland's energy transition progressed relative to the EU-27, and is the country moving closer to or further away from the European average?**

The analysis focuses on two complementary indicators:

* **Greenhouse gas emissions per capita** - environmental impact
* **Renewable energy share** - progress towards cleaner energy

The dashboard combines historical trends, Poland–EU gap analysis and country benchmarking.

---

## Dashboard

### Overview

Compares Poland with the EU-27 average over time using dynamic KPIs, trend analysis and contextual commentary.

<img width="1153" height="648" alt="overview_renewables_shares" src="https://github.com/user-attachments/assets/5117686b-3c29-4aac-9b62-4c5326e1a480" />

### Country Ranking

Benchmarks Poland against other EU member states and identifies neighbouring countries and similar performers.

<img width="1154" height="651" alt="ranking_GHG_emissions" src="https://github.com/user-attachments/assets/988194af-e0d7-4ebe-acb0-4ef0e6b741c1" />

---

## Solution Architecture

```text
Eurostat TSV Files
        │
        ▼
SQL Staging & Transformation
        │
        ▼
Dimensional Model
        │
        ▼
Analytical SQL Views
        │
        ▼
Power BI Semantic Model
        │
        ▼
DAX Measures
        │
        ▼
Interactive Dashboard
```

SQL is responsible for cleaning, restructuring and validating the data, while Power BI handles calculations, interaction and visualisation.

This separation reduces duplicated logic and keeps the reporting model easier to maintain.

---

## Technical Implementation

The original Eurostat datasets were distributed as wide TSV files and required restructuring before analysis.

The SQL pipeline includes:

* parsing concatenated dimension fields,
* converting textual observations into numeric values,
* handling Eurostat missing-value symbols,
* transforming data into an analytical format,
* creating fact and dimension tables,
* exposing reusable views for Power BI.

The model follows a star-schema approach:

* `fact_indicator_value` - annual observations by country and indicator,
* `dim_country` - country names, codes and classification attributes.

Exploratory SQL queries use CTEs and window functions such as `LAG()` and `RANK()` to validate trends, year-over-year changes and country rankings.

The DAX layer includes:

* Poland and EU-27 values,
* gap calculations,
* country rankings,
* similarity analysis,
* dynamic titles and units,
* automatically generated business commentary.

Measures are used instead of calculated columns wherever possible, with `VAR` expressions improving readability and reducing repeated calculations.

---

## Key Findings

### Greenhouse Gas Emissions

Between 2013 and 2024, Poland reduced greenhouse gas emissions per capita by approximately **9.7%**.

Over the same period, the EU-27 average declined by approximately **25.6%**.

Poland therefore improved in absolute terms. However, the pace of improvement was insufficient to reduce the gap relative to the EU average.

### Renewable Energy

Poland's renewable energy share increased by more than **55%** between 2013 and 2024.

Despite this growth, Poland remained below the EU average, as many member states expanded renewable energy at a similar or faster pace.

### Overall Conclusion

Poland made measurable progress in both analysed areas, but its relative position within the EU did not improve substantially.

The project highlights an important distinction between **absolute improvement** and **relative performance**.

---

## Key Design Decisions

* Transformations were centralised in SQL to create a reusable source of truth and simplify the Power BI model.
* The analysis was limited to two complementary indicators to prioritise clarity over feature density.
* Rankings were included to show whether Poland's progress translated into a stronger position relative to other EU countries.
* Dimensional modelling was applied despite the small dataset to keep the solution scalable and easy to extend.

---

## Repository Structure

```text
energy-transition-analysis/
│
├── README.md
├── SQL/
│   ├── 01_staging_and_transform.sql
│   ├── 02_exploratory_analysis.sql
│   └── 03_views_for_powerbi.sql
│
├── PowerBI/
│   ├── Energy_Transition.pbix
│   └── measures_energy_transition.txt
│
└── Images/
    ├── dashboard_overview.png
    └── dashboard_ranking.png
```

---

## Running the Project

1. Import the Eurostat source files into MySQL.
2. Execute the SQL scripts in numerical order.
3. Open `Energy_Transition.pbix`, update the data source connection and refresh the model.

---

## Author

**Konstancja Trębicka**

Data Analytics | SQL | Power BI

---

## Licence

This project was created for educational and portfolio purposes.

The source datasets are provided by Eurostat under their respective terms of use.
