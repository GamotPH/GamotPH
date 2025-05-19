# backend/users/views.py

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.conf import settings
import requests

class TestAuthView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user_data = getattr(request.user, 'payload', None)

        if isinstance(user_data, dict):
            return Response({
                "message": "You are authenticated!",
                "user_data": user_data
            }, status=200)
        else:
            return Response({
                "message": "Invalid user data.",
                "raw_user": str(user_data)
            }, status=400)

class SupabaseLoginView(APIView):
    def post(self, request):
        email = request.data.get('email')
        password = request.data.get('password')

        if not email or not password:
            return Response({"error": "Email and password are required."}, status=400)

        url = f"{settings.SUPABASE_API_URL}/auth/v1/token?grant_type=password"
        headers = {
            "apikey": settings.SUPABASE_ANON_KEY,
            "Content-Type": "application/json"
        }
        payload = {
            "email": email,
            "password": password
        }

        supabase_response = requests.post(url, json=payload, headers=headers)

        if supabase_response.status_code == 200:
            return Response(supabase_response.json(), status=200)
        else:
            return Response(supabase_response.json(), status=supabase_response.status_code)
        
class ForgotPasswordView(APIView):
    def post(self, request):
        email = request.data.get("email")

        if not email:
            return Response({"error": "Email is required."}, status=400)

        url = f"{settings.SUPABASE_API_URL}/auth/v1/recover"
        headers = {
            "apikey": settings.SUPABASE_ANON_KEY,
            "Content-Type": "application/json"
        }
        payload = {
            "email": email
        }

        response = requests.post(url, headers=headers, json=payload)

        if response.status_code in [200, 204]:
            return Response({"message": "Password recovery email sent. Please check your email."}, status=200)
        else:
            return Response({
                "error": "Failed to send recovery email.",
                "supabase_error": response.json()
            }, status=response.status_code)

class ResetPasswordView(APIView):
    def post(self, request):
        access_token = request.data.get("access_token")  
        new_password = request.data.get("new_password")

        if not access_token or not new_password:
            return Response({"error": "Access token and new password are required."}, status=400)

        url = f"{settings.SUPABASE_API_URL}/auth/v1/user"
        headers = {
            "apikey": settings.SUPABASE_ANON_KEY,
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json"
        }
        payload = {
            "password": new_password
        }

        response = requests.put(url, headers=headers, json=payload)

        if response.status_code == 200:
            return Response({"message": "Password has been reset successfully."}, status=200)
        else:
            return Response({
                "error": "Failed to reset password.",
                "supabase_error": response.json()
            }, status=response.status_code)

class RegisterView(APIView):
    def post(self, request):
        email = request.data.get("email")
        password = request.data.get("password")

        if not email or not password:
            return Response({"error": "Email and password are required."}, status=400)

        url = f"{settings.SUPABASE_API_URL}/auth/v1/signup"
        headers = {
            "apikey": settings.SUPABASE_ANON_KEY,  
            "Content-Type": "application/json"
        }
        payload = {
            "email": email,
            "password": password
        }

        response = requests.post(url, json=payload, headers=headers)

        if response.status_code == 200:
            return Response({"message": "User registered successfully. Please check your email to confirm your account."}, status=201)
        else:
            return Response({
                "error": "Registration failed.",
                "supabase_error": response.json()
            }, status=response.status_code)
