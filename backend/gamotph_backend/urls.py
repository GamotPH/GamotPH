from django.contrib import admin
from django.urls import path, include
from django.http import HttpResponse

def confirm_success(request):
    return HttpResponse("🎉 Your email was successfully confirmed. You may now log in.")

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/", include("users.urls")),
    path("api/adr/", include("adr_reports.urls")),   # ✅ Required!
    path("confirm-success/", confirm_success),        # ✅ Retain this
]
