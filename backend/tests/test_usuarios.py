import pytest
from django.utils import timezone
from datetime import timedelta
from apps_work.usuarios.models import Colaborador, ConviteColaborador


@pytest.mark.django_db
class TestColaboradorModel:
    def test_criar_colaborador(self, tenant, usuario):
        colaborador = Colaborador.objects.create(
            user=usuario,
            funcao='Cabeleireiro',
        )
        assert colaborador.id is not None
        assert colaborador.user == usuario

    def test_str_colaborador(self, tenant, usuario):
        colaborador = Colaborador.objects.create(user=usuario)
        assert str(colaborador) == usuario.get_full_name()


@pytest.mark.django_db
class TestConviteColaboradorModel:
    def test_criar_convite(self, tenant):
        convite = ConviteColaborador.objects.create(
            email='novo@email.com',
            expira_em=timezone.now() + timedelta(days=7),
        )
        assert convite.id is not None
        assert convite.aceito is False

    def test_str_convite(self):
        convite = ConviteColaborador(email='novo@email.com')
        assert str(convite) == 'Convite →  <novo@email.com>'
