"""
Django REST Framework serializer for student onboarding payloads.
Candidate: Raja Saini | rajasaini092004@gmail.com

Validation boundary — records are forced through these limits before they
ever reach Pub/Sub or BigQuery.
"""

from __future__ import annotations

from django.core.validators import RegexValidator
from rest_framework import serializers

from .dcyn_library import DCYNValidationError, deconstruct_payload
from .models import DCYNChoice, LSARegion, StudentOnboarding

# E.164 format: optional leading +, 8-15 digits. Not country-specific since
# HabotConnect's families aren't limited to one country.
_PHONE_VALIDATOR = RegexValidator(
    regex=r"^\+?[1-9]\d{7,14}$",
    message="Phone number must be in E.164 format, for example +919812345678.",
)


class StudentOnboardingSerializer(serializers.ModelSerializer):
    """Validates and deserializes a raw student onboarding JSON payload.

    DCYN fields arrive in their raw shape (boolean, "yes"/"no", 0/1) and get
    converted to strict "YES"/"NO" in to_internal_value before any field
    validator runs, keeping that conversion logic in dcyn_library.py only.
    """

    student_full_name = serializers.CharField(
        max_length=120,
        min_length=2,
        trim_whitespace=True,
        error_messages={
            "max_length": "Student full name must not exceed 120 characters.",
            "min_length": "Student full name must be at least 2 characters.",
        },
    )
    parent_email = serializers.EmailField(
        max_length=254,
        error_messages={"invalid": "Enter a valid parent email address."},
    )
    parent_phone = serializers.CharField(
        max_length=20,
        validators=[_PHONE_VALIDATOR],
    )
    date_of_birth = serializers.DateField(
        input_formats=["%Y-%m-%d"],
        error_messages={"invalid": "Date of birth must be in YYYY-MM-DD format."},
    )
    lsa_region = serializers.ChoiceField(
        choices=LSARegion.choices,
        error_messages={
            "invalid_choice": "lsa_region must be one of: north, south, east, west."
        },
    )
    onboarding_date = serializers.DateField(
        input_formats=["%Y-%m-%d"],
    )
    consent_data_processing = serializers.ChoiceField(choices=DCYNChoice.choices)
    diagnosed_learning_need = serializers.ChoiceField(choices=DCYNChoice.choices)
    requires_financial_assistance = serializers.ChoiceField(choices=DCYNChoice.choices)
    lsa_previously_assigned = serializers.ChoiceField(choices=DCYNChoice.choices)
    additional_notes = serializers.CharField(
        max_length=1000,
        required=False,
        allow_blank=True,
        default="",
    )

    class Meta:
        model = StudentOnboarding
        fields = [
            "student_full_name",
            "parent_email",
            "parent_phone",
            "date_of_birth",
            "lsa_region",
            "onboarding_date",
            "consent_data_processing",
            "diagnosed_learning_need",
            "requires_financial_assistance",
            "lsa_previously_assigned",
            "additional_notes",
        ]

    def to_internal_value(self, data):
        """Run DCYN conversion before DRF's field validation, so ChoiceField
        sees the strict "YES"/"NO" string, not a raw boolean. A
        DCYNValidationError becomes a normal 400 with a field-specific
        message instead of an unhandled exception.
        """
        try:
            data = deconstruct_payload(data)
        except DCYNValidationError as exc:
            raise serializers.ValidationError({exc.field_name: str(exc)})

        return super().to_internal_value(data)

    def validate(self, attrs):
        """Cross-field check: date_of_birth must be earlier than
        onboarding_date. Needs both fields at once, so it belongs here
        rather than on a single field's validator.
        """
        dob = attrs.get("date_of_birth")
        onboarding_date = attrs.get("onboarding_date")

        if dob and onboarding_date and dob >= onboarding_date:
            raise serializers.ValidationError(
                {
                    "date_of_birth": "Date of birth must be earlier than the onboarding date."
                }
            )

        return attrs
