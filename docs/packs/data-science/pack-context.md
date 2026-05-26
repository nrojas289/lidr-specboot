# Pack Context: data-science

Active pack: **data-science**.

Skills and agents must interpret OpenSpec user stories as **hypotheses or experiments**, not UI features.

- A user story typically maps to: a question to answer, a dataset to analyze, or a model to train.
- `tasks.md` should include: data contract check (`docs/data/<dataset>.yml`), EDA notebook, feature engineering with tests, baseline, candidate model(s), evaluation on test, model card.
- Acceptance criteria are **quantitative** (metric ≥ threshold, drift below limit, latency budget) — never "looks reasonable".
- Verification (`/verify`) checks: tests + lint + mypy, run manifest exists, primary metric meets threshold, model card present.

Standards to load alongside `base-standards.md`:

- `docs/data-science-standards.md`
- `docs/eda-standards.md`
- `docs/modeling-standards.md`

Agents available:

- `data-scientist` — owns EDA, feature engineering, modeling, evaluation.
- `data-engineer` — owns ingestion, pipelines, data quality, contracts.
