# adr_reports/views.py

import requests
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.conf import settings
from .serializers import ADRReportSerializer
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity


class ADRReportView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = ADRReportSerializer(data=request.data)
        if not serializer.is_valid():
            return Response({"error": "Validation failed", "details": serializer.errors}, status=400)

        data = serializer.validated_data
        user_data = getattr(request.user, 'payload', None)

        if not user_data:
            return Response({"error": "User authentication failed"}, status=401)

        # Inject authenticated user's Supabase UUID
        data["userID"] = user_data.get("sub")

        # Step 1: Deduplication check
        description = data.get("reactionDescription")
        drug = data.get("drugName")
        user_id = data["userID"]

        fetch_url = (
            f"{settings.SUPABASE_API_URL}/rest/v1/ADR_Reports"
            f"?userID=eq.{user_id}&drugName=eq.{drug}&select=reactionDescription"
        )
        dedup_headers = {
            "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
            "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
            "Accept": "application/json"
        }

        recent_response = requests.get(fetch_url, headers=dedup_headers)
        recent_texts = []

        if recent_response.status_code == 200:
            reports = recent_response.json()
            recent_texts = [r["reactionDescription"] for r in reports if "reactionDescription" in r]

        if recent_texts:
            recent_texts.append(description)  # Append current one
            tfidf = TfidfVectorizer().fit_transform(recent_texts)
            similarities = cosine_similarity(tfidf[-1:], tfidf[:-1])
            max_sim = max(similarities[0])

            if max_sim > 0.9:
                return Response({
                    "error": "Duplicate report detected.",
                    "similarity_score": round(float(max_sim), 2)
                }, status=409)

        # Step 2: Prepare POST to Supabase
        allowed_severity = ["mild", "moderate", "severe"]
        if data.get("severity") not in allowed_severity:
            return Response({"error": "Invalid severity value"}, status=400)

        headers = {
            "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
            "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
            "Content-Type": "application/json",
            "Prefer": "return=minimal"
        }

        supabase_url = f"{settings.SUPABASE_API_URL}/rest/v1/ADR_Reports"
        response = requests.post(supabase_url, headers=headers, json=data)

        if response.status_code == 201:
            return Response({"message": "ADR Report submitted successfully"}, status=201)
        elif response.status_code == 400:
            return Response({
                "message": "Failed to submit ADR Report",
                "supabase_error": response.json()
            }, status=400)
        else:
            return Response({
                "error": "Unexpected error when submitting ADR report",
                "details": response.json()
            }, status=500)

class MyADRReportsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user_data = getattr(request.user, 'payload', None)
        if not user_data:
            return Response({"error": "Authentication failed"}, status=401)

        user_id = user_data.get("sub")
        if not user_id:
            return Response({"error": "User ID missing"}, status=400)

        supabase_url = f"{settings.SUPABASE_API_URL}/rest/v1/ADR_Reports?userID=eq.{user_id}&order=created_at.desc"
        headers = {
            "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
            "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
            "Accept": "application/json"
        }

        response = requests.get(supabase_url, headers=headers)
        if response.status_code == 200:
            return Response(response.json(), status=200)
        else:
            return Response({
                "error": "Failed to fetch ADR Reports",
                "details": response.text
            }, status=500)
