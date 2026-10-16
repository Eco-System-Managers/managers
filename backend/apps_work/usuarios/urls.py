from rest_framework.routers import DefaultRouter
from .views import ColaboradorViewSet, ConviteColaboradorViewSet

router = DefaultRouter()
router.register(r'colaboradores', ColaboradorViewSet, basename='colaborador')
router.register(r'convites', ConviteColaboradorViewSet, basename='convite')

urlpatterns = router.urls
