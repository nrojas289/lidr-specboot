---
description: Standards for data-science projects bootstrapped with lidr-specboot. Load alongside base-standards.md.
alwaysApply: true
---

## 1. Project Layout

```
.
├── pyproject.toml          # uv/poetry, ruff, mypy, pytest config
├── uv.lock | poetry.lock   # committed
├── src/<package>/          # production code: ingestion, features, models, evaluation
│   ├── __init__.py
│   ├── data/               # loaders, validators
│   ├── features/           # feature engineering (pure functions, typed, tested)
│   ├── models/             # training, prediction, registry I/O
│   └── evaluation/         # metrics, reports
├── notebooks/              # exploratory work only; never imported from src/
│   ├── 01_eda_<topic>.ipynb
│   └── 02_model_<topic>.ipynb
├── tests/                  # pytest; mirrors src/ layout
├── data/                   # gitignored; raw/, interim/, processed/
├── models/                 # gitignored or DVC-tracked; trained artifacts
├── reports/                # rendered notebooks, figures, model cards
└── docs/                   # specs, base + pack standards
```

## 2. Environment & Tooling

- Pin Python in `pyproject.toml` (`requires-python = ">=3.11"`).
- Use `uv` (`uv sync`, `uv run pytest`) or `poetry`. Lockfile is the source of truth.
- `ruff check src/ tests/` and `ruff format src/ tests/` must be clean before commit.
- `mypy --strict src/` must pass. Notebooks are exempt from `mypy`.
- Pre-commit hooks recommended: `ruff`, `ruff-format`, `nbstripout` (strip notebook outputs from VCS unless they are the deliverable).

## 3. TDD adapted to data science

TDD applies to **deterministic code**, not to exploratory analysis.

- **MUST TDD**: data loaders, validators, feature transformations, metric implementations, pipeline glue, model wrapper APIs.
- **MAY skip TDD**: notebook exploration, one-off plots, hypothesis sketches. Promote stable code from notebooks to `src/` with tests before depending on it.
- **Tests for ML**: use small fixtures (`tests/fixtures/*.csv|parquet`) and assert on shape, dtypes, invariants, and edge cases. For models, test the wrapper (fit-predict contract, serialization), not the learned weights.

## 4. Reproducibility

- **Seeds**: fix `numpy`, `random`, framework-specific seeds in every training entry point.
- **Determinism**: log library versions (`pip freeze`) into `reports/<run-id>/env.txt`.
- **Data versioning**: prefer DVC or a registry; at minimum record dataset path + hash + row count in the run manifest.
- **Run manifest**: every training run writes `reports/<run-id>/manifest.json` with dataset id, hyperparams, metrics, code commit SHA.

## 5. Data contracts

Every input dataset must have a `data-spec.yml` (see `data-spec-template.yml`) declaring:

- Schema (columns, dtypes, nullability).
- Source and freshness SLA.
- Quality rules (uniqueness, ranges, allowed values).
- Owner.

Loaders in `src/<pkg>/data/` validate against the spec on read; failures raise, not warn.

## 6. Notebooks discipline

See `eda-standards.md`. Key rules:

- Notebooks are write-only artifacts for narrative; do not `from notebooks.X import Y`.
- Long-lived logic graduates to `src/` with tests.
- Commit notebooks with outputs only when the rendered notebook IS the deliverable; otherwise strip outputs.

## 7. Modeling

See `modeling-standards.md`. Key rules: baseline first, justified metric, train/val/test split fixed at the start, model card written before sharing results.
