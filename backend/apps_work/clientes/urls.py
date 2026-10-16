from rest_framework.routers import DefaultRouter
from .views import ClienteViewSet, VeiculoViewSet, PetViewSet

router = DefaultRouter()
router.register(r'clientes', ClienteViewSet, basename='cliente')
router.register(r'veiculos', VeiculoViewSet, basename='veiculo')
router.register(r'pets', PetViewSet, basename='pet')

urlpatterns = router.urls
