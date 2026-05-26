# EDA Standards

Conventions for exploratory notebooks under `notebooks/`.

## Naming

`NN_<phase>_<topic>.ipynb` where `NN` is a zero-padded sequence and `<phase>` is one of `eda`, `feature`, `model`, `eval`. Example: `03_feature_churn_signals.ipynb`.

## Required structure

Every EDA notebook MUST include these top-level markdown sections, in order:

1. **Context** — problem, dataset(s), owner, date, related user story / spec.
2. **Hypotheses** — what we expect to find; falsifiable statements.
3. **Data load & validation** — read via `src/<pkg>/data/` loaders, not ad-hoc `pd.read_*`.
4. **Profiling** — schema, missingness, distributions, cardinality. Use `ydata-profiling` for first pass, then targeted plots.
5. **Findings** — bullet list of observations linked to plots; each labelled as `[confirmed]`, `[refuted]`, or `[new]`.
6. **Next steps** — concrete actions: features to engineer, code to graduate to `src/`, follow-up questions.

## Quality rules

- One question per notebook section; if it grows, split.
- All plots must have title, axis labels, and units. No default `matplotlib` titles.
- No hardcoded paths; use a `paths.py` helper or env vars.
- No credentials, no PII in notebook output. Strip outputs (`nbstripout`) unless the notebook is the deliverable.
- Reproducible execution: kernel restart + run-all must succeed top-to-bottom.

## Graduating code from notebook to `src/`

A snippet graduates when **any** of these is true:

- Reused in ≥ 2 notebooks.
- Required by a model training pipeline.
- Encodes a business rule that will outlive the notebook.

Graduation checklist:

1. Extract into a pure function in `src/<pkg>/features/` (or appropriate module).
2. Add type hints; `mypy --strict` clean.
3. Add `pytest` test with a small fixture covering happy path + one edge case.
4. Replace the notebook snippet with the import.
