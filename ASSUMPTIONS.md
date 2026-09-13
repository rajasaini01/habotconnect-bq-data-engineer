# Assumptions

**Candidate:** Raja Saini
**Email:** rajasaini092004@gmail.com

The Hiring Project Form and job advertisement leave several details unspecified or, in
one case, contradictory. Rather than guess silently, every assumption is listed here
with its reasoning.

## 1. Title mismatch between the two source documents

The Hiring Project Form header reads "Junior Cloud & DevOps Engineer (GCP / Django /
React)," while the job advertisement is titled "Associate BigQuery Data Engineer" and
explicitly states the role is "NOT a software coding, web app, or frontend
React/Django engineering position." The advertisement is the authoritative document
for the actual role, so I treated this project through a data-engineering lens: the
DRF serializer required in Task 3 is scoped narrowly as a schema-validation layer at
the point data enters the pipeline, not as general backend/API engineering. This
matches the ad's own responsibility list ("Schema Architecture," "Lineage &
Constraints Governance," "Poka-Yoke Build Gates").

## 2. GCP project ID and credentials

No GCP project ID, region default, or service account key is provided. Terraform
variables (`variables.tf`) require `project_id` to be passed at `terraform plan`/
`apply` time rather than hardcoded. This is standard Terraform practice for
environment portability and avoids committing environment-specific values to source
control — it is not a placeholder in the sense the brief prohibits, since the
configuration is fully functional once the variable is supplied.

## 3. GCP region

No region is specified anywhere in the brief. I defaulted to `asia-south1` (Mumbai) in
`variables.tf`, since HabotConnect's candidate pool and compensation are INR-denominated,
suggesting proximity to India-based infrastructure reduces latency and egress cost.
This is exposed as a variable, so it can be overridden per environment without touching
the configuration.

## 4. Row-Level Security business rule

The brief asks for RLS policies but does not specify the access rule. I assumed a
realistic rule consistent with HabotConnect's stated business (matching parents with
Learning Support Assistants across regions): analysts can only see onboarding rows for
students in their assigned `lsa_region`. Admins/service accounts bypass this via a
separate IAM role. This is implemented as a BigQuery row access policy
(`CREATE ROW ACCESS POLICY`) rather than application-level filtering, so the
restriction holds even for ad hoc queries run directly in BigQuery.

## 5. Column-level security scope

PII fields (`parent_email`, `parent_phone`, `student_full_name`) are tagged for
column-level access control using BigQuery policy tags. Only a designated PII-reader
group can see these columns unmasked; all other viewers see them masked. Policy tags
require a Data Catalog taxonomy resource, which is provisioned in `main.tf`.

## 6. DCYN field selection

The sample payload (`sample_payload.json`) is a representative student onboarding form
I constructed based on the platform description (parents, children with learning
difficulties, LSAs). Fields converted to strict Yes/No via the DCYN library are the
ones that gate downstream logic: `consent_data_processing`, `diagnosed_learning_need`,
`requires_financial_assistance`, and `lsa_previously_assigned`. Free-text fields
(name, notes) are validated for presence/length but are not DCYN-converted, since
DCYN by definition applies to binary decision fields, not descriptive ones.

## 7. Secret management

The scenario describes unencrypted API credentials left in code. The fix assumed is
GCP Secret Manager, referenced by the application via IAM-scoped service account
access, with the CI/CD gate (Task 2) preventing any secret literal from being
committed in the first place. Provisioning the Secret Manager secret itself was judged
out of scope for `main.tf`, since the brief's IaC requirement is limited to the GCS
bucket and BigQuery dataset — the gate (Task 2) is the control that stops secrets from
being introduced at all.

## 8. CI/CD linter and scanner choices

`flake8` and `black` are used for Python because they are the most widely adopted,
zero-configuration-by-default tools for style and lint enforcement, keeping the
pipeline simple rather than introducing a heavier framework. `gitleaks` is used for
secret scanning because it runs as a single GitHub Action step with no external
service dependency, which keeps the fail-closed gate self-contained and auditable.
