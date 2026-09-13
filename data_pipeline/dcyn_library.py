"""
DCYN Library — Deconstructed Yes/No Validation
Candidate: Raja Saini | rajasaini092004@gmail.com

Deconstructs incoming binary fields (consent, diagnosed need, etc.) into a
strict "YES"/"NO" — no third state. Ambiguous or missing values (null,
"maybe", empty string) raise DCYNValidationError instead of defaulting to
NO, since silently guessing on an unanswered consent question would hide a
data quality problem instead of surfacing it. The caller (DRF serializer)
turns that into a visible 400 response.
"""

from __future__ import annotations

from typing import Any


class DCYNValidationError(ValueError):
    """Raised when a field cannot be resolved to a strict YES/NO value."""

    def __init__(self, field_name: str, raw_value: Any):
        self.field_name = field_name
        self.raw_value = raw_value
        super().__init__(
            f"Field '{field_name}' could not be resolved to YES/NO. "
            f"Received: {raw_value!r}"
        )


# Explicit list (not inferred from types) so adding a new binary field is a
# deliberate, reviewable change.
DCYN_FIELDS: tuple[str, ...] = (
    "consent_data_processing",
    "diagnosed_learning_need",
    "requires_financial_assistance",
    "lsa_previously_assigned",
)

# Narrow on purpose — only the shapes our own onboarding form can realistically
# send (Python bool, JS boolean, a small set of expected strings), not
# arbitrary free text.
_TRUE_VALUES = {True, "true", "True", "TRUE", "yes", "Yes", "YES", 1}
_FALSE_VALUES = {False, "false", "False", "FALSE", "no", "No", "NO", 0}


def to_dcyn(field_name: str, raw_value: Any) -> str:
    """Resolve a single raw value to the strict string "YES" or "NO".

    Raises DCYNValidationError for None, empty string, or anything outside
    the recognized truthy/falsy sets, rather than guessing.
    """
    if raw_value is None or raw_value == "":
        raise DCYNValidationError(field_name, raw_value)

    if raw_value in _TRUE_VALUES:
        return "YES"

    if raw_value in _FALSE_VALUES:
        return "NO"

    raise DCYNValidationError(field_name, raw_value)


def deconstruct_payload(payload: dict) -> dict:
    """Return a copy of payload with every DCYN_FIELDS entry resolved to
    "YES"/"NO". Other fields pass through unchanged.

    Raises DCYNValidationError on the first unresolvable field — fails fast
    rather than collecting every error, so an ambiguous record never reaches
    serialization at all.
    """
    result = dict(payload)
    for field_name in DCYN_FIELDS:
        result[field_name] = to_dcyn(field_name, payload.get(field_name))
    return result
