# adr_reports/urls.py

from django.urls import path
from .views import ADRReportView, MyADRReportsView

urlpatterns = [
    path('submit-adr/', ADRReportView.as_view(), name='submit-adr'),
    path("my-adr-reports/", MyADRReportsView.as_view(), name="my-adr-reports"),
]
