from django.urls import path
from .views import DashboardResumoView

urlpatterns = [
    path('dashboard/resumo/', DashboardResumoView.as_view(), name='dashboard-resumo'),
]
