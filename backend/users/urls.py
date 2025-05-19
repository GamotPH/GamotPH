# backend/users/urls.py

from django.urls import path
from .views import TestAuthView, SupabaseLoginView, ForgotPasswordView, RegisterView, ResetPasswordView

urlpatterns = [
    path('test-auth/', TestAuthView.as_view(), name='test-auth'),
    path('login/', SupabaseLoginView.as_view(), name='supabase-login'),
    path('forgot-password/', ForgotPasswordView.as_view(), name='forgot-password'),
    path('reset-password/', ResetPasswordView.as_view(), name='reset-password'),
    path('register/', RegisterView.as_view(), name='register'),
]
