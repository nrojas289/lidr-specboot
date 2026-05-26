# Modeling Standards

Rules for training, evaluating, and shipping ML models in projects using the `data-science` pack.

## 1. Define before you fit

Before any training code, the corresponding OpenSpec change MUST declare:

- **Problem type** — classification (binary/multiclass), regression, ranking, clustering, etc.
- **Target variable** — definition, source, leakage analysis.
- **Primary metric** — single number used to compare runs. Justify the choice (e.g., PR-AUC for class imbalance ≥ 95/5).
- **Secondary metrics** — at most 3, including a business/cost-aware metric when applicable.
- **Acceptance threshold** — quantitative bar the model must clear to ship.
- **Splits** — strategy (random/stratified/time-based), ratios, seed. Fixed before any training run.

## 2. Baseline first

Every modeling task starts with a trivial baseline (majority class, mean, last-value, simple heuristic) and a simple linear/tree baseline. Real models must beat both on the primary metric to be considered.

## 3. Training pipeline

- Entry point in `src/<pkg>/models/train.py`, callable as `python -m <pkg>.models.train --config configs/<exp>.yml`.
- Config-driven: hyperparams, paths, seeds live in YAML, not in code.
- Writes to `reports/<run-id>/`: `manifest.json`, `metrics.json`, `model.pkl|.joblib`, `confusion_matrix.png` (or task-appropriate plots), `feature_importance.json` when applicable.
- Idempotent given the same config + data hash.

## 4. Evaluation

- Always report on the held-out test set last, and only once per candidate.
- Include uncertainty: bootstrap CIs or cross-val standard deviation for the primary metric.
- Slice analysis: report primary metric across at least one business-relevant slice (segment, geography, time bucket).

## 5. Model card

Every model shipped (handed off, deployed, or shared) carries `reports/<run-id>/MODEL_CARD.md` covering:

- Intended use & out-of-scope use.
- Training data summary (source, period, size, known biases).
- Metrics on test + slices.
- Limitations and failure modes.
- Owner and contact.

## 6. Verification (`/verify`)

For DS user stories, `/verify` checks **both** code correctness and modeling success:

- All `pytest` green; `ruff` + `mypy --strict` clean on `src/`.
- Run manifest exists for the spec's experiment.
- Primary metric on test ≥ acceptance threshold declared in the spec.
- Model card present.

A model that passes tests but misses the metric threshold is **not** a passing verification — update the spec or iterate.
