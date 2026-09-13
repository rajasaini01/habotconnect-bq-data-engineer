# Fail-Closed Gate Demonstration

**Candidate:** Raja Saini | rajasaini092004@gmail.com

This walks through what happens when a non-compliant commit is pushed, proving the
CI/CD gate in `.github/workflows/ci-poka-yoke.yml` fails closed instead of just
logging a warning.

## Scenario: reproducing the original incident

The brief describes a junior developer committing unencrypted API credentials
directly in application code. Below is the kind of change that would trigger it,
and how the pipeline responds.

While testing this, an actual credential-shaped string I used for the demo below
tripped GitHub's own push protection on the real push to this repo (separate from
the Gitleaks job in the workflow) — see the note under the diff for what happened.

### Broken commit (do not merge — illustrative only)

```diff
--- a/data_pipeline/serializers.py
+++ b/data_pipeline/serializers.py
@@ -1,5 +1,8 @@
 from rest_framework import serializers
 from .models import StudentOnboarding

+# BAD: hardcoded credential, exactly the class of leak described in the brief
+THIRD_PARTY_API_KEY = "REDACTED-EXAMPLE-DO-NOT-USE-THIS-STRING-1234567890"
+
+
 class StudentOnboardingSerializer(serializers.ModelSerializer):
     class Meta:
```

Note: the string shown above is inert and clearly marked as an example — it's not a
working credential and isn't present anywhere in the actual `serializers.py` in this
repo. My first attempt at this demo used a string shaped like a real Stripe key, and
GitHub's own push protection (a separate, server-side check from the Gitleaks job
below) rejected the push outright before it even reached a branch. I replaced it with
the clearly-redacted string above to get the push through — which is itself a working
example of a fail-closed control, just enforced one layer earlier than expected.

### What the pipeline does

1. `terraform-checks` — not affected by this change, passes.
2. `python-lint-and-format` — `black --check` can still pass if the added lines are
   correctly formatted, so formatting alone doesn't catch this class of issue. That's
   why a dedicated secret-scanning job exists instead of relying on the linter.
3. `secret-scan` — Gitleaks matches the hardcoded string against its default ruleset,
   reports the finding with file and line number, and `gitleaks-action` exits non-zero.
4. Because `secret-scan` failed, `build-gate-passed` (which needs all three checks)
   never runs, so its status never turns green.
5. With branch protection on `main` requiring the `Build Gate Passed` status check,
   GitHub blocks the merge until the offending commit is removed or amended.

## Second example: formatting violation

```diff
--- a/data_pipeline/dcyn_library.py
+++ b/data_pipeline/dcyn_library.py
@@ -10,7 +10,7 @@ def to_dcyn(value):
-    return "YES" if value else "NO"
+    return "YES" if value else   "NO"
```

`black --check` fails on the inconsistent spacing — `black` enforces one canonical
style, so any deviation fails rather than warns — which independently fails
`python-lint-and-format` and blocks the merge through the same dependency chain.

## Why this is fail-closed, not fail-open

A fail-open pipeline would run these same checks but treat a failure as informational
— posting a comment, say, while still allowing the merge. This one never does that:
there's no `continue-on-error: true` anywhere in the workflow, and `build-gate-passed`
only runs, and only succeeds, if every upstream job succeeded first. That missing
merge path around the dependency chain is what actually enforces fail-closed — it's
a property of the workflow graph, not just a written policy.
