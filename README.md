# HabotConnect Hiring Project — Associate BigQuery Data Engineer

**Candidate:** Raja Saini
**Email:** rajasaini092004@gmail.com
**Submission for:** Associate BigQuery Data Engineer, HabotConnect FZCO
**Date:** 5 August 2026

---

## 1. Scenario Recap

A junior developer pushed a change that left unencrypted API credentials in
application code and introduced a database schema mismatch, breaking downstream
analytics. This repository restores system integrity across the three required areas:

| Task | Area | Location |
|------|------|----------|
| 1 | Secure staging provisioning (Terraform) | `terraform/` |
| 2 | Poka-Yoke fail-closed CI/CD gate | `.github/workflows/ci-poka-yoke.yml` |
| 3 | Schema mapping, DCYN validation, DRF serializer | `data_pipeline/` |

Supporting material: `docs/` (architecture diagram, schema mapping sheet, fail-closed
demo) and `presentation/` (slide deck).

## 2. Architecture Overview

```
Student Onboarding Form (JSON)
        |
        v
  Pub/Sub topic (onboarding-events)
        |
        v
  Cloud Function (validation + DCYN transform)
        |
   +----+-----+
   v          v
GCS D0     Dead-Letter topic
(raw       (rejected / malformed
landing)   payloads, for manual review)
   |
   v
BigQuery D1 (staged/enforced dataset)
- partitioned by onboarding_date
- clustered by lsa_region
- row access policy on analyst-facing views
- column-level policy tags on PII fields
```

Design intent: raw data always lands untouched in D0 first (audit trail, replay
capability). Only validated, schema-conformant records reach D1. Anything that fails
validation is routed to a dead-letter destination instead of being silently dropped or
silently corrupting the warehouse — this is the Poka-Yoke principle applied to data,
not just to code.

## 3. Task 1 — Terraform Secure Staging Provisioning

See `terraform/main.tf`. Provisions:

- **GCS bucket `d0-raw-landing`** — uniform bucket-level access, versioning enabled,
  Google-managed encryption, public access prevention enforced, lifecycle rule moving
  objects to Nearline storage after 30 days to control cost.
- **BigQuery dataset `d1_staged_enforced`** — no default table expiration (this is a
  persistent staged layer, not a scratch dataset), a row access policy restricting
  non-admin analysts to rows matching their assigned LSA region, and a
  `student_onboarding` table using the schema defined in Task 3.
- **Two IAM bindings**, both scoped to groups rather than individual users: a service
  account with `roles/storage.objectCreator` on D0 only (the ingestion pipeline needs
  to write, never delete or read arbitrary objects), and `roles/bigquery.dataViewer`
  on D1 restricted to a Google Group with an IAM condition limiting access to
  non-expired requests.

Run instructions:
```bash
cd terraform
terraform init
terraform plan -var="project_id=<your-gcp-project-id>"
terraform apply -var="project_id=<your-gcp-project-id>"
```

`<your-gcp-project-id>` is a Terraform input variable supplied at run time — see
`variables.tf`. No project ID or credential is committed to the repository, by design
(see `ASSUMPTIONS.md`, item 2).

## 4. Task 2 — Poka-Yoke CI/CD Build Gate

See `.github/workflows/ci-poka-yoke.yml`. The pipeline runs on every push and pull
request and enforces, in sequence:

1. **Terraform format & validate** (`terraform fmt -check`, `terraform validate`) —
   catches malformed or inconsistent IaC before it can be applied.
2. **Python lint** (`flake8`) and **format check** (`black --check`) across
   `data_pipeline/`.
3. **Secret scan** (`gitleaks`) across the full diff — blocks any commit containing
   patterns matching API keys, GCP service account keys, or other credential shapes.

Every job runs with GitHub Actions' default `continue-on-error: false`, and there is no
final "always succeed" step. A failure anywhere in the chain blocks the merge check —
this is what makes the gate fail-closed rather than fail-open. A fail-open design would
log a warning and let the merge proceed regardless; this pipeline cannot do that.

A worked example of a deliberately broken commit (hardcoded secret + unformatted
Python) and the resulting failed run is documented in `docs/fail-closed-demo.md`.

## 5. Task 3 — Schema Mapping & DCYN Validation

See `data_pipeline/`:

- `sample_payload.json` — an example incoming student onboarding JSON payload.
- `dcyn_library.py` — deconstructs the payload's boolean and tri-state business fields
  into a strict Yes/No (DCYN — Deconstructed Yes/No) representation. No null, blank, or
  free-text value is allowed to pass through; anything that cannot be resolved to a
  definite Yes or No is rejected before it reaches the warehouse.
- `serializers.py` — a Django REST Framework `ModelSerializer` with exact field
  constraints (`max_length`, `choices`, regex validators) so invalid data is rejected
  at the API boundary, before it is ever published to Pub/Sub or written to BigQuery.
- `models.py` — the corresponding Django model backing the serializer.

## 6. Repository Structure

```
habotconnect-bq-data-engineer/
├── README.md
├── ASSUMPTIONS.md
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── .github/workflows/ci-poka-yoke.yml
├── data_pipeline/
│   ├── sample_payload.json
│   ├── dcyn_library.py
│   ├── serializers.py
│   └── models.py
├── docs/
│   ├── architecture-diagram.png
│   ├── schema-mapping.xlsx
│   └── fail-closed-demo.md
└── presentation/
    └── HabotConnect-Associate-BigQuery-DataEngineer-Submission.pptx
```

## 7. Assumptions

Every assumption made where the brief was ambiguous is listed and justified in
`ASSUMPTIONS.md`, including the naming discrepancy between the Hiring Project Form
header ("Junior Cloud & DevOps Engineer") and the job advertisement ("Associate
BigQuery Data Engineer"). Nothing in this repository relies on an undocumented guess.
