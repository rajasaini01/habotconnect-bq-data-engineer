"""
Django model backing the student onboarding serializer.
Candidate: Raja Saini | rajasaini092004@gmail.com

Kept in sync with the BigQuery student_onboarding schema in
terraform/main.tf — a change to one should be mirrored in the other.
"""

from django.db import models


class LSARegion(models.TextChoices):
    """Regions HabotConnect currently matches LSAs in. Closed choice set so
    the row access policy in terraform/main.tf has predictable values to
    filter on.
    """

    NORTH = "north", "North"
    SOUTH = "south", "South"
    EAST = "east", "East"
    WEST = "west", "West"


class DCYNChoice(models.TextChoices):
    """Strict binary choice used by every DCYN-derived field."""

    YES = "YES", "Yes"
    NO = "NO", "No"


class StudentOnboarding(models.Model):
    """One row per onboarding submission. Maps onto the BigQuery
    student_onboarding table from Task 1.
    """

    student_full_name = models.CharField(
        max_length=120,
        help_text="Full legal name of the student, as provided by the parent.",
    )
    parent_email = models.EmailField(
        max_length=254,
        help_text="Primary contact email for the parent or guardian.",
    )
    parent_phone = models.CharField(
        max_length=20,
        help_text="Contact phone number in E.164 format, for example +919812345678.",
    )
    date_of_birth = models.DateField(
        help_text="Student's date of birth.",
    )
    lsa_region = models.CharField(
        max_length=10,
        choices=LSARegion.choices,
        help_text="Region used to match the student with a Learning Support Assistant.",
    )
    onboarding_date = models.DateField(
        help_text="Date this onboarding record was submitted.",
    )
    consent_data_processing = models.CharField(
        max_length=3,
        choices=DCYNChoice.choices,
        help_text="DCYN field: parental consent to process the child's data.",
    )
    diagnosed_learning_need = models.CharField(
        max_length=3,
        choices=DCYNChoice.choices,
        help_text="DCYN field: whether the student has a diagnosed learning need.",
    )
    requires_financial_assistance = models.CharField(
        max_length=3,
        choices=DCYNChoice.choices,
        help_text="DCYN field: whether the family is requesting financial assistance.",
    )
    lsa_previously_assigned = models.CharField(
        max_length=3,
        choices=DCYNChoice.choices,
        help_text="DCYN field: whether an LSA has previously been assigned to this student.",
    )
    additional_notes = models.TextField(
        max_length=1000,
        blank=True,
        default="",
        help_text="Optional free-text notes. Not a DCYN field — descriptive, not a decision gate.",
    )

    class Meta:
        db_table = "student_onboarding"
        ordering = ["-onboarding_date"]

    def __str__(self) -> str:
        return f"{self.student_full_name} ({self.onboarding_date})"
