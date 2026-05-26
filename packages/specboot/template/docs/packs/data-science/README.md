# Data-Science Pack

For projects whose deliverables are insights, models, or data products (EDA reports, trained ML models, scoring services).

## Stack assumed by this pack

- **Language**: Python ≥ 3.11.
- **Env mgmt**: `uv` (preferred) or `poetry`; lockfile committed.
- **Code quality**: `ruff` (lint+format) and `mypy --strict` on `src/`.
- **Testing**: `pytest` + `pytest-cov`.
- **Core libs**: `pandas` or `polars`, `numpy`, `scikit-learn`, `matplotlib`/`seaborn`/`plotly`.
- **Notebooks**: Jupyter / VS Code notebooks for EDA and prototyping only.
- **Reproducibility**: fixed seeds, lockfile, optional `DVC` for data versioning.

## Contents

- `data-science-standards.md` — project layout, env mgmt, TDD adapted to DS, reproducibility.
- `eda-standards.md` — conventions for exploratory notebooks.
- `modeling-standards.md` — training pipeline, evaluation, model cards.
- `data-spec-template.yml` — contract template for input datasets (schema, quality, freshness).
- `pack-context.md` — short context loaded by skills/agents when this pack is active.

## Agents bundled

- `data-scientist` — EDA, feature engineering, modeling, evaluation.
- `data-engineer` — ingestion, pipelines, data quality, contracts.

## When to choose this pack

Choose `data-science` when the deliverable is an analytical artifact (report, dashboard input, predictive model, scoring API). For production data pipelines (Airflow/dbt/Spark) prefer the upcoming `data-engineering` pack.
