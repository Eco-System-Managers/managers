"""Equipe sem login, vínculo parceiro/colaborador, comissão congelada e as travas."""
from datetime import datetime, time
from decimal import Decimal
from unittest.mock import patch

import pytest
from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework.test import APIClient

from apps_work.agenda.models import Agendamento, AgendamentoServico
from apps_work.clientes.models import Cliente, ObjetoCliente, Veiculo
from apps_work.kanban.models import AtendimentoKanban, EtapaKanban
from apps_work.servicos.models import Servico
from apps_work.usuarios.models import Colaborador, ConviteColaborador
from apps_work.usuarios.services import AceitarConviteService
from tenants.models import Membro


def _client(user):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=user)
    return client


def _membro(tenant, email):
    user = User.objects.create_user(username=email, email=email, password='SenhaForte123!')
    Membro.objects.create(user=user, tenant=tenant, papel='colaborador')
    return user


@pytest.fixture
def dono(patch_tenant_middleware, proprietario):
    Colaborador.objects.create(user=proprietario, nome='Dono')
    return _client(proprietario)


@pytest.fixture
def corte(patch_tenant_middleware):
    return Servico.objects.create(nome='Corte', duracao=30, preco='100.00')


@pytest.fixture
def ana(patch_tenant_middleware):
    return Cliente.objects.create(nome='Ana', telefone='11999990000')


def _agendamento(cliente, servico, colaborador):
    quando = timezone.make_aware(datetime.combine(timezone.localdate(), time(10, 0)))
    ag = Agendamento.objects.create(cliente=cliente, colaborador=colaborador, data_hora=quando, status='confirmado')
    AgendamentoServico.objects.create(agendamento=ag, servico=servico, preco_cobrado=servico.preco)
    return ag


COBRANCA = {'desconto': '0.00', 'pagamentos': [{'forma': 'pix', 'valor': '100.00'}]}


@pytest.mark.django_db
class TestEquipeSemLogin:
    URL = '/api/v1/colaboradores/'

    def test_dono_cadastra_quem_trabalha_sem_convite(self, dono):
        response = dono.post(self.URL, {'nome': 'João', 'funcao': 'Lavador', 'tipo': 'colaborador'}, format='json')
        assert response.status_code == 201
        corpo = response.json()
        assert corpo['nome'] == 'João'
        assert corpo['tem_acesso'] is False
        assert corpo['papel'] is None
        assert corpo['email'] == ''
        assert corpo['pode_cobrar'] is True

    def test_sem_nome_e_erro_de_campo(self, dono):
        response = dono.post(self.URL, {'funcao': 'Lavador'}, format='json')
        assert response.status_code == 400
        assert 'nome' in response.json()['fields']

    def test_colaborador_comum_nao_cadastra(self, patch_tenant_middleware, tenant):
        bia = _membro(tenant, 'bia@x.com')
        Colaborador.objects.create(user=bia, nome='Bia')
        assert _client(bia).post(self.URL, {'nome': 'João'}, format='json').status_code == 403

    def test_comissao_so_para_parceiro(self, dono):
        parceiro = dono.post(self.URL, {'nome': 'Léo', 'tipo': 'parceiro', 'comissao_percentual': '40.00'}, format='json')
        assert parceiro.json()['comissao_percentual'] == '40.00'
        comum = dono.post(self.URL, {'nome': 'João', 'tipo': 'colaborador', 'comissao_percentual': '40.00'}, format='json')
        assert comum.json()['comissao_percentual'] is None
        fora = dono.post(self.URL, {'nome': 'X', 'comissao_percentual': '120'}, format='json')
        assert fora.status_code == 400

    def test_busca_acha_pelo_nome_proprio(self, dono):
        Colaborador.objects.create(nome='João Lavador')
        nomes = [c['nome'] for c in dono.get(f'{self.URL}?search=lavador').json()['results']]
        assert nomes == ['João Lavador']

    def test_nome_de_quem_tem_login_cai_no_cadastro(self, patch_tenant_middleware, proprietario):
        # registros de antes do campo `nome`: o nome vem do User
        proprietario.first_name = 'Wilson'
        proprietario.save()
        Colaborador.objects.create(user=proprietario)
        corpo = _client(proprietario).get(f'{self.URL}me/').json()
        assert corpo['nome'] == 'Wilson Silva'
        assert corpo['tem_acesso'] is True


@pytest.mark.django_db
class TestConvidarQuemJaEstaNaEquipe:
    @patch('core.email.send_mail')
    def test_convite_liga_o_login_ao_mesmo_registro(self, mock_mail, dono, tenant):
        joao = Colaborador.objects.create(nome='João', funcao='Lavador', tipo='colaborador')
        response = dono.post(f'/api/v1/colaboradores/{joao.id}/convidar/', {'email': 'joao@x.com'}, format='json')
        assert response.status_code == 201
        assert response.json()['colaborador'] == joao.id
        convite = ConviteColaborador.objects.get(pk=response.json()['id'])

        AceitarConviteService().aceitar(convite.token, 'SenhaForte123!')

        joao.refresh_from_db()
        assert joao.user.email == 'joao@x.com'
        assert joao.tipo == 'colaborador'
        assert Colaborador.objects.count() == 2  # dono e João: nada duplicado

    @patch('core.email.send_mail')
    def test_quem_ja_tem_acesso_nao_e_convidado(self, mock_mail, dono, proprietario):
        colaborador = Colaborador.objects.get(user=proprietario)
        response = dono.post(f'/api/v1/colaboradores/{colaborador.id}/convidar/', {'email': 'outro@x.com'}, format='json')
        assert response.status_code == 400
        assert response.json()['code'] == 'colaborador_com_acesso'

    def test_remover_quem_nao_tem_login_solta_os_atendimentos(self, dono, ana, corte):
        joao = Colaborador.objects.create(nome='João')
        ag = _agendamento(ana, corte, joao)
        assert dono.delete(f'/api/v1/colaboradores/{joao.id}/remover/').status_code == 204
        ag.refresh_from_db()
        assert ag.colaborador is None


@pytest.mark.django_db
class TestComissaoCongelada:
    def test_cobrar_guarda_a_comissao_do_parceiro(self, dono, ana, corte):
        leo = Colaborador.objects.create(nome='Léo', tipo='parceiro', comissao_percentual=Decimal('40'))
        ag = _agendamento(ana, corte, leo)

        assert dono.post(f'/api/v1/agendamentos/{ag.id}/cobrar/', COBRANCA, format='json').status_code == 200

        pagamento = ag.pagamentos.get()
        assert pagamento.comissao_percentual == Decimal('40.00')
        assert pagamento.repasse == Decimal('40.00')

        # o acordo muda depois: o que foi cobrado não muda
        leo.comissao_percentual = Decimal('50')
        leo.save()
        hoje = timezone.localdate().isoformat()
        caixa = dono.get(f'/api/v1/financeiro/caixa/?data_inicio={hoje}&data_fim={hoje}').json()
        assert caixa['kpis'] == {'total': '100.00', 'ticket_medio': '100.00', 'atendimentos': 1, 'repasse': '40.00', 'casa': '60.00'}
        assert caixa['pagamentos'][0]['repasse'] == '40.00'

    def test_colaborador_comum_nao_gera_repasse(self, dono, ana, corte):
        joao = Colaborador.objects.create(nome='João', tipo='colaborador')
        ag = _agendamento(ana, corte, joao)
        dono.post(f'/api/v1/agendamentos/{ag.id}/cobrar/', COBRANCA, format='json')
        pagamento = ag.pagamentos.get()
        assert pagamento.comissao_percentual is None
        assert pagamento.repasse == Decimal('0.00')

    def test_parceiro_ve_so_a_parte_dele(self, dono, tenant, ana, corte):
        user = _membro(tenant, 'leo@x.com')
        leo = Colaborador.objects.create(user=user, nome='Léo', tipo='parceiro', comissao_percentual=Decimal('40'))
        ag = _agendamento(ana, corte, leo)
        dono.post(f'/api/v1/agendamentos/{ag.id}/cobrar/', COBRANCA, format='json')

        hoje = timezone.localdate().isoformat()
        caixa = _client(user).get(f'/api/v1/financeiro/caixa/?data_inicio={hoje}&data_fim={hoje}').json()
        assert caixa['kpis']['total'] == '100.00'
        assert caixa['kpis']['repasse'] == '40.00'
        assert caixa['kpis']['casa'] is None

        resumo = _client(user).get('/api/v1/dashboard/resumo/').json()
        assert resumo['colaborador'] == leo.id
        assert resumo['kpis']['faturamento'] == '100.00'
        assert resumo['kpis']['repasse'] == '40.00'


@pytest.mark.django_db
class TestTravasDoColaboradorComum:
    @pytest.fixture
    def joao(self, patch_tenant_middleware, tenant):
        user = _membro(tenant, 'joao@x.com')
        return Colaborador.objects.create(user=user, nome='João', tipo='colaborador')

    def test_nao_ve_o_caixa(self, joao):
        response = _client(joao.user).get('/api/v1/financeiro/caixa/')
        assert response.status_code == 403
        assert response.json()['code'] == 'sem_acesso_a_valores'

    def test_painel_vem_sem_valores(self, joao, ana, corte):
        ag = _agendamento(ana, corte, joao)
        resumo = _client(joao.user).get('/api/v1/dashboard/resumo/').json()
        assert resumo['colaborador'] == joao.id
        assert resumo['kpis']['faturamento'] is None
        assert resumo['kpis']['ticket_medio'] is None
        assert resumo['kpis']['repasse'] is None
        assert [a['id'] for a in resumo['agendamentos_hoje']] == [ag.id]

    def test_cobra_por_padrao_e_a_flag_bloqueia(self, joao, ana, corte):
        ag = _agendamento(ana, corte, joao)
        api = _client(joao.user)
        assert api.post(f'/api/v1/agendamentos/{ag.id}/cobrar/', COBRANCA, format='json').status_code == 200

        Colaborador.objects.filter(pk=joao.pk).update(pode_cobrar=False)
        outro = _agendamento(ana, corte, joao)
        response = api.post(f'/api/v1/agendamentos/{outro.id}/cobrar/', COBRANCA, format='json')
        assert response.status_code == 403
        assert response.json()['code'] == 'sem_permissao_cobrar'

    def test_parceiro_cobra_mesmo_com_a_flag_desligada(self, tenant, ana, corte):
        user = _membro(tenant, 'leo@x.com')
        leo = Colaborador.objects.create(user=user, nome='Léo', tipo='parceiro', pode_cobrar=False)
        ag = _agendamento(ana, corte, leo)
        assert _client(user).post(f'/api/v1/agendamentos/{ag.id}/cobrar/', COBRANCA, format='json').status_code == 200


@pytest.mark.django_db
class TestProfissionalNaEsteira:
    @pytest.fixture
    def esteira(self, patch_tenant_middleware, ana, corte):
        etapa = EtapaKanban.objects.create(nome='Aguardando', ordem=0)
        veiculo = Veiculo.objects.create(cliente=ana, modelo='Uno', placa='ABC1D23')
        objeto = ObjetoCliente.objects.get(veiculo=veiculo)
        return {'etapa': etapa, 'objeto': objeto}

    def test_card_com_profissional_filtra_e_entra_no_caixa_dele(self, dono, esteira, corte):
        joao = Colaborador.objects.create(nome='João', tipo='parceiro', comissao_percentual=Decimal('30'))
        criado = dono.post('/api/v1/kanban/atendimentos/', {
            'etapa': esteira['etapa'].id, 'objeto': esteira['objeto'].id, 'servico': corte.id, 'colaborador': joao.id,
        }, format='json')
        assert criado.status_code == 201
        assert criado.json()['colaborador_nome'] == 'João'
        sem_dono = dono.post('/api/v1/kanban/atendimentos/', {
            'etapa': esteira['etapa'].id, 'objeto': esteira['objeto'].id, 'servico': corte.id,
        }, format='json')
        assert sem_dono.status_code == 201

        quadro = dono.get(f'/api/v1/kanban/atendimentos/?colaborador={joao.id}').json()
        assert [a['id'] for a in quadro['results']] == [criado.json()['id']]

        dono.post(f"/api/v1/kanban/atendimentos/{criado.json()['id']}/cobrar/", COBRANCA, format='json')
        hoje = timezone.localdate().isoformat()
        caixa = dono.get(f'/api/v1/financeiro/caixa/?data_inicio={hoje}&data_fim={hoje}&colaborador={joao.id}').json()
        assert caixa['kpis']['total'] == '100.00'
        assert caixa['kpis']['repasse'] == '30.00'
        assert caixa['pagamentos'][0]['colaborador_nome'] == 'João'
