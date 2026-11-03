"""A esteira é de operação compartilhada: um quadro por negócio, sem recorte
por pessoa, e o vínculo diz o que cada um pode — o parceiro toca o negócio
com o dono (menos a estrutura), o colaborador comum só move os cards. O modo
horário continua como era."""
from datetime import time, timedelta
from decimal import Decimal
from unittest.mock import patch

import pytest
from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework.test import APIClient

from django.utils import timezone as tz

from apps_work.agenda.models import Bloqueio
from apps_work.clientes.models import Cliente, Veiculo
from apps_work.empresa.models import EmpresaConfig, HorarioFuncionamento
from apps_work.kanban.models import AtendimentoKanban, EtapaKanban
from apps_work.kanban.services import AtendimentoKanbanService, EtapaService
from apps_work.servicos.models import Servico
from apps_work.usuarios.models import Colaborador, ConviteColaborador
from apps_work.usuarios.services import AceitarConviteService
from tenants.models import Membro

URL = '/api/v1/kanban/atendimentos/'
HOJE = timezone.localdate()
# Uma semana à frente, para o bloqueio e o ajuste do dia não esbarrarem em hoje.
DIA = HOJE + timedelta(days=7)
COBRANCA = {'desconto': '0.00', 'pagamentos': [{'forma': 'pix', 'valor': '40.00'}]}


def _client(user):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=user)
    return client


def _membro(tenant, email, tipo, **extra):
    user = User.objects.create_user(username=email, email=email, password='SenhaForte123!')
    Membro.objects.create(user=user, tenant=tenant, papel='colaborador')
    return Colaborador.objects.create(user=user, nome=email.split('@')[0].title(), tipo=tipo, **extra)


def _payload_negocio(**extra):
    return {'data_inicio': DIA.isoformat(), 'data_fim': DIA.isoformat(), 'hora_inicio': '12:00', 'hora_fim': '13:00', **extra}


@pytest.fixture
def esteira(patch_tenant_middleware):
    """Um lava-rápido: a config na esteira, o expediente e as etapas padrão."""
    EmpresaConfig.objects.create(
        pk=1, nichos=['lava_rapido'], tipo_agenda='kanban', tipo_objeto='veiculo', onboarding_concluido=True,
    )
    for dia in range(7):
        HorarioFuncionamento.objects.update_or_create(
            dia=dia, defaults={'abertura': time(9, 0), 'fechamento': time(18, 0), 'ativo': True, 'vagas': 1},
        )
    return EtapaService().criar_etapas_padrao()


@pytest.fixture
def dono(patch_tenant_middleware, proprietario):
    Colaborador.objects.create(user=proprietario, nome='Dono')
    return proprietario


@pytest.fixture
def leo(patch_tenant_middleware, tenant):
    # parceiro com comissão cadastrada de propósito: na esteira ela não pesa
    return _membro(tenant, 'leo@x.com', 'parceiro', comissao_percentual=Decimal('30'))


@pytest.fixture
def joao(patch_tenant_middleware, tenant):
    # colaborador comum com `pode_cobrar` ligado (o padrão): na esteira não pesa
    return _membro(tenant, 'joao@x.com', 'colaborador')


@pytest.fixture
def lavagem(patch_tenant_middleware):
    return Servico.objects.create(nome='Lavagem', nicho='lava_rapido', duracao=40, preco='40.00')


@pytest.fixture
def carro(patch_tenant_middleware):
    cliente = Cliente.objects.create(nome='Ana', telefone='11999990000')
    return Veiculo.objects.create(
        cliente=cliente, tipo='veiculo', placa='ABC1D23', marca='VW', modelo='Gol', cor='Branco', porte='carro',
    )


def _receber(etapas, carro, lavagem, **extra) -> AtendimentoKanban:
    return AtendimentoKanbanService().criar(
        etapa=etapas[0], objeto_id=carro.pk, servico_id=lavagem.pk, data=HOJE, **extra,
    )


@pytest.mark.django_db
class TestAgendaUnica:
    @patch('core.email.send_mail')
    def test_convidar_e_aceitar_nao_cria_etapas_e_todos_leem_o_mesmo_quadro(
        self, mock_mail, esteira, dono, tenant, carro, lavagem,
    ):
        api = _client(dono)
        for nome, tipo, email in (('Léo', 'parceiro', 'leo@x.com'), ('João', 'colaborador', 'joao@x.com')):
            pessoa = api.post('/api/v1/colaboradores/', {'nome': nome, 'tipo': tipo}, format='json').json()
            convite = api.post(
                f"/api/v1/colaboradores/{pessoa['id']}/convidar/", {'email': email}, format='json',
            ).json()
            AceitarConviteService().aceitar(ConviteColaborador.objects.get(pk=convite['id']).token, 'SenhaForte123!')

        # ninguém ganhou quadro nem etapas próprios
        assert EtapaKanban.objects.count() == 3

        card = _receber(esteira, carro, lavagem)
        ids_das_etapas = [e.id for e in esteira]
        for user in User.objects.filter(email__in=['leo@x.com', 'joao@x.com']):
            quem = _client(user)
            etapas = quem.get('/api/v1/kanban/etapas/').json()['results']
            assert [e['id'] for e in etapas] == ids_das_etapas
            quadro = quem.get(URL, {'data': HOJE.isoformat()}).json()['results']
            assert [a['id'] for a in quadro] == [card.id]


@pytest.mark.django_db
class TestSemRecortePorPessoa:
    def test_o_card_nao_tem_profissional(self, esteira, dono, leo, carro, lavagem):
        api = _client(dono)
        criado = api.post(
            URL, {'etapa': esteira[0].id, 'objeto': carro.pk, 'servico': lavagem.id, 'colaborador': leo.id},
            format='json',
        )
        assert criado.status_code == 201
        assert 'colaborador' not in criado.json()
        assert 'colaborador_nome' not in criado.json()
        assert AtendimentoKanban.objects.get().colaborador_id is None

        # nem por PATCH
        assert api.patch(f"{URL}{criado.json()['id']}/", {'colaborador': leo.id}, format='json').status_code == 200
        assert AtendimentoKanban.objects.get().colaborador_id is None

    def test_o_filtro_por_colaborador_nao_recorta_quadro_painel_nem_caixa(self, esteira, dono, leo, carro, lavagem):
        api = _client(dono)
        card = _receber(esteira, carro, lavagem)
        assert api.post(f'{URL}{card.id}/cobrar/', COBRANCA, format='json').status_code == 200

        quadro = api.get(URL, {'data': HOJE.isoformat(), 'colaborador': leo.id}).json()['results']
        assert [a['id'] for a in quadro] == [card.id]
        resumo = api.get(f'/api/v1/dashboard/resumo/?colaborador={leo.id}').json()
        assert resumo['colaborador'] is None
        assert resumo['kpis']['faturamento'] == '40.00'
        caixa = api.get(f'/api/v1/financeiro/caixa/?colaborador={leo.id}').json()
        assert caixa['kpis']['total'] == '40.00'

    def test_parceiro_ve_a_esteira_inteira_com_a_casa(self, esteira, dono, leo, carro, lavagem):
        card = _receber(esteira, carro, lavagem)
        _client(dono).post(f'{URL}{card.id}/cobrar/', COBRANCA, format='json')

        api = _client(leo.user)
        caixa = api.get('/api/v1/financeiro/caixa/').json()
        assert caixa['kpis'] == {
            'total': '40.00', 'ticket_medio': '40.00', 'atendimentos': 1, 'repasse': '0.00', 'casa': '40.00',
        }
        assert caixa['pagamentos'][0]['colaborador_nome'] == ''
        resumo = api.get('/api/v1/dashboard/resumo/').json()
        assert resumo['colaborador'] is None
        assert resumo['kpis']['faturamento'] == '40.00'
        assert resumo['kpis']['repasse'] == '0.00'

    def test_cobrar_nao_gera_repasse_mesmo_com_comissao_cadastrada(self, esteira, dono, leo, carro, lavagem):
        card = _receber(esteira, carro, lavagem)
        assert _client(leo.user).post(f'{URL}{card.id}/cobrar/', COBRANCA, format='json').status_code == 200
        pagamento = card.pagamentos.get()
        assert pagamento.repasse == Decimal('0.00')
        assert pagamento.comissao_percentual is None

    def test_o_card_de_hoje_no_painel_vem_sem_profissional(self, esteira, dono, carro, lavagem):
        card = _receber(esteira, carro, lavagem, horario_entrada=time(17, 0))
        hoje = _client(dono).get('/api/v1/dashboard/resumo/').json()['agendamentos_hoje']
        assert [(a['id'], a['colaborador_nome']) for a in hoje] == [(card.id, '')]

    def test_bloqueio_por_profissional_e_recusado(self, esteira, dono, leo):
        response = _client(dono).post('/api/v1/agenda/bloqueios/', _payload_negocio(colaborador=leo.id), format='json')
        assert response.status_code == 400
        assert response.json()['code'] == 'bloqueio_individual_na_esteira'
        assert not Bloqueio.objects.exists()

    def test_a_vitrine_nao_lista_a_equipe(self, esteira, dono, leo, tenant):
        from apps_serv.vitrine.services import CrossTenantQueryService
        assert CrossTenantQueryService().listar_colaboradores(tenant.schema_name) == []


@pytest.mark.django_db
class TestParceiroDaEsteira:
    @pytest.fixture
    def api(self, esteira, leo):
        return _client(leo.user)

    def test_escreve_servicos_e_modelos_de_contrato(self, api):
        servico = api.post('/api/v1/servicos/', {'nome': 'Cera', 'duracao': 30, 'preco': '30.00'}, format='json')
        assert servico.status_code == 201
        assert api.patch(f"/api/v1/servicos/{servico.json()['id']}/", {'ativo': False}, format='json').status_code == 200

        modelo = api.post(
            '/api/v1/contratos/modelos/', {'titulo': 'Padrão', 'corpo': 'Eu, {{cliente_nome}}, concordo.'}, format='json',
        )
        assert modelo.status_code == 201
        assert api.patch(f"/api/v1/contratos/modelos/{modelo.json()['id']}/", {'ativo': False}, format='json').status_code == 200

    def test_ajusta_o_dia_e_fecha_horario(self, api):
        ajuste = api.put(f'/api/v1/kanban/capacidade/?data={DIA.isoformat()}', {'capacidade': 5, 'vagas': 2}, format='json')
        assert ajuste.status_code == 200
        assert ajuste.json()['ajustado'] is True
        assert api.delete(f'/api/v1/kanban/capacidade/?data={DIA.isoformat()}').status_code == 200

        fechado = api.post('/api/v1/agenda/bloqueios/', _payload_negocio(motivo='Almoço'), format='json')
        assert fechado.status_code == 201
        assert fechado.json()['colaborador'] is None
        assert api.delete(f"/api/v1/agenda/bloqueios/{fechado.json()['id']}/").status_code == 204

    def test_recebe_cobra_e_exclui_como_o_dono(self, api, esteira, carro, lavagem):
        criado = api.post(URL, {'etapa': esteira[0].id, 'objeto': carro.pk, 'servico': lavagem.id}, format='json')
        assert criado.status_code == 201
        card = criado.json()['id']
        # a ficha inteira: telefone e valores
        ficha = api.get(f'{URL}{card}/').json()
        assert ficha['cliente_telefone'] == '11999990000'
        assert ficha['servico_preco'] == '40.00'
        assert api.post(f'{URL}{card}/mover/', {'etapa_id': esteira[1].id}, format='json').status_code == 200
        assert api.patch(f'{URL}{card}/', {'data': DIA.isoformat(), 'horario_entrada': '10:00'}, format='json').status_code == 200
        assert api.post(f'{URL}{card}/marcar_falta/').status_code == 200
        assert api.post(f'{URL}{card}/desfazer_falta/').status_code == 200
        assert api.post(f'{URL}{card}/cobrar/', COBRANCA, format='json').status_code == 200
        assert api.post(f'{URL}{card}/desfazer_cobranca/').status_code == 200
        assert api.delete(f'{URL}{card}/').status_code == 204

    @pytest.mark.parametrize('url', [
        '/api/v1/clientes/', '/api/v1/contratos/', '/api/v1/financeiro/caixa/', '/api/v1/dashboard/resumo/',
        '/api/v1/agenda/pendencias/',
    ])
    def test_le_o_que_o_dono_le(self, api, url):
        assert api.get(url).status_code == 200

    @pytest.mark.parametrize('metodo, url, corpo', [
        ('post', '/api/v1/kanban/etapas/', {'nome': 'Secagem'}),
        ('post', '/api/v1/empresa/horarios/', {'dia': 1, 'abertura': '09:00', 'fechamento': '18:00', 'ativo': True}),
        ('patch', '/api/v1/empresa/config/', {'nome': 'Outro nome'}),
        ('post', '/api/v1/colaboradores/', {'nome': 'Alguém'}),
        ('get', '/api/v1/colaboradores/', {}),
        ('post', '/api/v1/convites/', {'email': 'alguem@x.com'}),
        ('get', '/api/v1/convites/', {}),
        ('post', '/api/v1/billing/assinatura/cancelar/', {}),
        ('post', '/api/v1/financeiro/despesas/', {}),
    ])
    def test_nao_mexe_na_estrutura(self, api, metodo, url, corpo):
        # etapas, horários, dados do negócio, equipe, convites, assinatura e
        # despesas (fora do MVP) continuam só do dono (ler a assinatura é de
        # todos: o app precisa saber se a venda está aberta)
        response = getattr(api, metodo)(url, corpo, format='json')
        assert response.status_code == 403

    def test_le_o_proprio_perfil(self, api, leo):
        assert api.get('/api/v1/colaboradores/me/').json()['id'] == leo.id


@pytest.mark.django_db
class TestColaboradorDaEsteira:
    @pytest.fixture
    def api(self, esteira, joao):
        return _client(joao.user)

    @pytest.fixture
    def card(self, esteira, carro, lavagem):
        return _receber(esteira, carro, lavagem, horario_entrada=time(10, 0))

    def test_le_o_quadro_sem_telefone_nem_valores(self, api, card):
        quadro = api.get(URL, {'data': HOJE.isoformat()}).json()['results']
        assert [a['id'] for a in quadro] == [card.id]
        assert quadro[0]['servico_preco'] is None

        ficha = api.get(f'{URL}{card.id}/').json()
        assert ficha['cliente_nome'] == 'Ana'
        assert ficha['servico_nome'] == 'Lavagem'
        assert ficha['cliente_telefone'] is None
        assert ficha['servico_preco'] is None
        assert ficha['desconto'] is None
        assert ficha['acrescimo'] is None
        assert ficha['acrescimo_motivo'] is None
        assert ficha['pagamentos'] == []

        # o resto do quadro continua aberto: etapas, capacidade e os
        # horários fechados do negócio
        assert api.get('/api/v1/kanban/etapas/').status_code == 200
        assert api.get(f'/api/v1/kanban/capacidade/?data={HOJE.isoformat()}').status_code == 200
        assert api.get(f'/api/v1/agenda/bloqueios/?data={HOJE.isoformat()}').status_code == 200

    def test_move_e_ajusta_o_tempo(self, api, card, esteira):
        movido = api.post(f'{URL}{card.id}/mover/', {'etapa_id': esteira[1].id}, format='json')
        assert movido.status_code == 200
        assert movido.json()['etapa'] == esteira[1].id
        assert movido.json()['servico_preco'] is None

        ajustado = api.patch(f'{URL}{card.id}/', {'minutos_extras': 30}, format='json')
        assert ajustado.status_code == 200
        assert ajustado.json()['minutos_extras'] == 30
        assert ajustado.json()['cliente_telefone'] is None

    @pytest.mark.parametrize('corpo', [
        {'minutos_extras': 30, 'observacao': 'x'},
        {'data': DIA.isoformat()},
        {'horario_entrada': '11:00'},
        {'observacao': 'x'},
    ])
    def test_no_patch_so_o_tempo(self, api, card, corpo):
        response = api.patch(f'{URL}{card.id}/', corpo, format='json')
        assert response.status_code == 403
        assert response.json()['code'] == 'sem_permissao'
        card.refresh_from_db()
        assert card.observacao == '' and card.data == HOJE and card.horario_entrada == time(10, 0)

    def test_nao_recebe_cobra_exclui_nem_marca_falta(self, api, card, esteira, carro, lavagem, joao):
        # pode_cobrar está ligado e não pesa: na esteira cobrar é do dono e do parceiro
        assert joao.pode_cobrar is True
        novo = {'etapa': esteira[0].id, 'objeto': carro.pk, 'servico': lavagem.id}
        for metodo, url, corpo in (
            ('post', URL, novo),
            ('put', f'{URL}{card.id}/', novo),
            ('post', f'{URL}{card.id}/cobrar/', COBRANCA),
            ('post', f'{URL}{card.id}/desfazer_cobranca/', None),
            ('post', f'{URL}{card.id}/marcar_falta/', None),
            ('post', f'{URL}{card.id}/desfazer_falta/', None),
            ('delete', f'{URL}{card.id}/', None),
        ):
            response = getattr(api, metodo)(url, corpo, format='json')
            assert response.status_code == 403, (metodo, url)
            assert response.json()['code'] == 'sem_permissao'
        assert AtendimentoKanban.objects.count() == 1
        assert not AtendimentoKanban.objects.get().pago

    def test_nao_ajusta_o_dia_nem_fecha_horario(self, api):
        ajuste = api.put(f'/api/v1/kanban/capacidade/?data={DIA.isoformat()}', {'capacidade': 5, 'vagas': 2}, format='json')
        assert ajuste.status_code == 403
        assert api.delete(f'/api/v1/kanban/capacidade/?data={DIA.isoformat()}').status_code == 403
        fechado = api.post('/api/v1/agenda/bloqueios/', _payload_negocio(), format='json')
        assert fechado.status_code == 403
        assert fechado.json()['code'] == 'sem_permissao'

    @pytest.mark.parametrize('url', [
        '/api/v1/clientes/', '/api/v1/veiculos/', '/api/v1/pets/', '/api/v1/servicos/',
        '/api/v1/contratos/', '/api/v1/contratos/modelos/', '/api/v1/dashboard/resumo/',
        '/api/v1/financeiro/caixa/', '/api/v1/agenda/pendencias/', '/api/v1/colaboradores/',
        '/api/v1/convites/', '/api/v1/agendamentos/',
        f'/api/v1/agenda/slots/?data={HOJE.isoformat()}&servico=1&colaborador=1',
        f'/api/v1/agenda/dias-com-registro/?ano={HOJE.year}&mes={HOJE.month}',
    ])
    def test_o_resto_e_403(self, api, url):
        response = api.get(url)
        assert response.status_code == 403
        assert response.json()['code'] in ('sem_permissao', 'sem_acesso_a_valores')

    def test_a_agenda_por_horario_nao_e_porta_lateral(self, api, carro, lavagem):
        # receber, ver telefone e valores e cobrar por agendamentos/ seria
        # contornar a esteira: a agenda inteira é 403 para ele
        marcado = api.post('/api/v1/agendamentos/', {
            'cliente': carro.cliente_id, 'servico_id': lavagem.id, 'data_hora': f'{DIA.isoformat()}T10:00:00-03:00',
        }, format='json')
        assert marcado.status_code == 403
        assert api.post('/api/v1/agendamentos/1/cobrar/', COBRANCA, format='json').status_code == 403

    def test_nao_exclui_o_horario_fechado(self, api):
        fechado = Bloqueio.objects.create(
            colaborador=None, data_inicio=DIA, data_fim=DIA, hora_inicio=time(12, 0), hora_fim=time(13, 0),
        )
        response = api.delete(f'/api/v1/agenda/bloqueios/{fechado.pk}/')
        assert response.status_code == 403
        assert Bloqueio.objects.filter(pk=fechado.pk).exists()

    def test_o_credito_do_cliente_e_403(self, api, carro):
        response = api.get(f'/api/v1/financeiro/clientes/{carro.cliente_id}/saldo/')
        assert response.status_code == 403
        assert response.json()['code'] == 'sem_permissao'

    def test_nao_cadastra_veiculo_nem_cliente(self, api, carro):
        assert api.post('/api/v1/clientes/', {'nome': 'Bia'}, format='json').status_code == 403
        veiculo = {'cliente': carro.cliente_id, 'placa': 'XYZ1A23', 'marca': 'Fiat', 'modelo': 'Uno', 'cor': 'Prata', 'porte': 'carro'}
        assert api.post('/api/v1/veiculos/', veiculo, format='json').status_code == 403


@pytest.mark.django_db
class TestModoHorarioContinua:
    """A barbearia não muda: o parceiro não escreve serviço nem fecha o
    negócio, o painel dele é só o dele, e o colaborador comum lê clientes,
    serviços e contratos como hoje."""

    @pytest.fixture
    def barbearia(self, patch_tenant_middleware):
        return EmpresaConfig.objects.create(pk=1, nichos=['barbearia'], tipo_agenda='horario', onboarding_concluido=True)

    def test_parceiro_nao_escreve_servico_nem_fecha_o_negocio(self, barbearia, dono, leo):
        api = _client(leo.user)
        assert api.post('/api/v1/servicos/', {'nome': 'Barba', 'duracao': 20, 'preco': '25.00'}, format='json').status_code == 403
        assert api.post('/api/v1/contratos/modelos/', {'titulo': 'Padrão', 'corpo': 'x'}, format='json').status_code == 403
        fechado = api.post('/api/v1/agenda/bloqueios/', _payload_negocio(), format='json')
        assert fechado.status_code == 403
        assert fechado.json()['code'] == 'sem_permissao'

        resumo = api.get('/api/v1/dashboard/resumo/').json()
        assert resumo['colaborador'] == leo.id
        assert api.get('/api/v1/financeiro/caixa/').json()['kpis']['casa'] is None

    def test_colaborador_comum_le_clientes_servicos_e_pendencias(self, barbearia, dono, joao):
        api = _client(joao.user)
        for url in (
            '/api/v1/clientes/', '/api/v1/servicos/', '/api/v1/contratos/', '/api/v1/agenda/pendencias/',
            '/api/v1/agendamentos/', '/api/v1/colaboradores/', '/api/v1/convites/',
        ):
            assert api.get(url).status_code == 200, url
        resumo = api.get('/api/v1/dashboard/resumo/').json()
        assert resumo['colaborador'] == joao.id
        assert resumo['kpis']['faturamento'] is None

    def test_convite_so_o_dono_escreve_em_qualquer_modo(self, barbearia, dono, leo):
        convite = ConviteColaborador.objects.create(
            nome='Bia', email='bia@x.com', expira_em=tz.now() + timedelta(days=7),
        )
        response = _client(leo.user).patch(f'/api/v1/convites/{convite.pk}/', {'email': 'outra@x.com'}, format='json')
        assert response.status_code == 403
        convite.refresh_from_db()
        assert convite.email == 'bia@x.com'
