# backend/adr_reports/serializers.py

from rest_framework import serializers

class ADRReportSerializer(serializers.Serializer):
    reported_for = serializers.ChoiceField(choices=["myself", "someone_else"])
    patientAge = serializers.IntegerField(min_value=0, max_value=120)
    patientGender = serializers.ChoiceField(choices=["Male", "Female", "Other"])
    drugName = serializers.CharField(max_length=255, trim_whitespace=True)
    reactionDescription = serializers.CharField(trim_whitespace=True)
    severity = serializers.ChoiceField(choices=["mild", "moderate", "severe"])
    geoLocation = serializers.CharField(trim_whitespace=True)
    latitude = serializers.FloatField(required=False)
    longitude = serializers.FloatField(required=False)
    aiAssistance = serializers.BooleanField()
    aiAssistanceResponse = serializers.CharField(required=False, allow_blank=True)
    patientWeight = serializers.FloatField(min_value=0, max_value=500)
    casePriorityScore = serializers.FloatField(min_value=0.0, max_value=10.0)

    def validate_drugName(self, value):
        if not value.strip():
            raise serializers.ValidationError("Drug name must not be blank.")
        return value

    def validate_reactionDescription(self, value):
        if len(value) < 10:
            raise serializers.ValidationError("Please provide more details about the reaction.")
        return value
