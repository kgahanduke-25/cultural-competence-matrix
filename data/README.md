# Data — availability and schema

**The scored dataset for this project is not published in this repository.**

The framework definition (`domains_metadata.csv`) is included because it describes
the six domains and their theoretical mapping. The **scored data** —
`example_matrix.csv` (population × domain scores) and `pluralism_transition.csv`
(the care-seeking transition) — is held privately.

## Requesting the data

The dataset is **available on reasonable request**. Please reach out:

**Kamalakanta Gahan** · kgahan.duke@gmail.com

Please include a short note on your intended use. *(Replace this address with your
preferred contact before publishing if different.)*

The four figures committed in `figures/` were generated from the full dataset and
illustrate the expected output.

---

## Schema (so the structure is clear without the data)

### `example_matrix.csv` — one row per (population × domain)

| column | type | meaning |
|---|---|---|
| `population` | text | group being assessed |
| `region` | text | geographic context |
| `case_type` | text | `Documented case` or `Illustrative (synthetic)` |
| `domain_id` | text | `D1`–`D6` (joins to `domains_metadata.csv`) |
| `score` | integer | ordinal **0–3** (0 = absent/hostile … 3 = strong/concordant) |
| `provenance` | text | how the score was derived (ethnographic vs. illustrative) |

### `pluralism_transition.csv` — care-seeking over time (case illustration)

| column | type | meaning |
|---|---|---|
| `system` | text | therapeutic system (traditional / primary / referral) |
| `period` | text | time point label |
| `period_order` | integer | sort order for periods |
| `reliance` | numeric | share of care-seeking (0–1, illustrative) |
| `note` | text | provenance note |

### `domains_metadata.csv` — *included in the repo* (framework, not data)

Defines the six domains with `domain_id`, `domain`, `short_label`,
`betancourt_level`, `andersen_stage`, `access_type`, and `literature_anchor`.

---

## Running the code without the dataset

The analysis scripts and the Shiny app require `example_matrix.csv` and
`pluralism_transition.csv`. Without them the loaders stop with a message pointing
here. To run the pipeline, obtain the data (above) and place the two CSVs in this
`data/` folder, then:

```r
Rscript scripts/generate_figures.R
```
