"""A capacidade da esteira: o máximo no dia, as vagas ao mesmo tempo, o ajuste
de uma data, a etapa de pronto e a grade pela duração do serviço."""
from datetime import date, datetime, time, timedelta

import pytest
from django.utils import timezone
from rest_framework.exceptions import ValidationError
from rest_framework.test import APIClient

from apps_work.clientes.models import Cliente, Veiculo
from apps_work.empresa.models import HorarioFuncionamento
from apps_work.kanban.models import AjusteDoDia, AtendimentoKanban, EtapaKanban
from apps_work.kanban.services import AtendimentoKanbanService, CapacidadeService, EtapaService, StatusClienteService
from apps_work.servicos.models import Servico
from core.excecoes import ErroDeNegocio
from core.grade import cabe, inicios_livres, proxima_marca

SEGUNDA = date(2026, 6, 15)  # uma segunda-feira, no futuro dos testes


def _dt(h, m=0):
    return datetime.combine(SEGUNDA, time(h, m))


class TestGrade:
    """core/grade.py, sem banco."""

    def test_cabe_um_por_vez(self):
        ocupados = [(_dt(9), _dt(9, 40))]

        assert cabe(_dt(9, 40), _dt(10, 20), ocupados)
        assert cabe(_dt(8), _dt(9), ocupados)
        assert not cabe(_dt(9, 15), _dt(9, 55), ocupados)

    def test_cabe_com_duas_vagas(self):
        ocupados = [(_dt(9), _dt(9, 40)), (_dt(9, 20), _dt(10))]

        # das 9:20 às 9:40 as duas vagas estão tomadas
        assert not cabe(_dt(9, 30), _dt(10, 10), ocupados, vagas=2)
        # das 9:40 em diante só uma
        assert cabe(_dt(9, 40), _dt(10, 20), ocupados, vagas=2)
        assert cabe(_dt(9, 30), _dt(10, 10), ocupados, vagas=3)

    def test_inicios_livres_andam_de_15_em_15_e_oferecem_o_fim_de_cada_ocupacao(self):
        livres = inicios_livres(_dt(8), _dt(10), timedelta(minutes=30), [(_dt(8), _dt(8, 50))])

        assert [h.strftime('%H:%M') for h in livres] == ['08:50', '09:00', '09:15', '09:30']

    def test_inicios_livres_respeita_a_antecedencia(self):
        livres = inicios_livres(_dt(8), _dt(9), timedelta(minutes=30), [], nao_antes_de=_dt(8, 20))

        assert [h.strftime('%H:%M') for h in livres] == ['08:30']

    def test_proxima_marca_arredonda_para_cima_ate_a_grade(self):
        assert proxima_marca(_dt(10, 37).replace(second=12)) == _dt(10, 45)
        assert proxima_marca(_dt(10, 45)) == _dt(10, 45)
        assert proxima_marca(_dt(10, 45).replace(second=1)) == _dt(11)


@pytest.fixture
def api(patch_tenant_middleware, proprietario):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=proprietario)
    return client


@pytest.fixture
def colaborador(patch_tenant_middleware, tenant):
    """Um usuário da equipe, sem ser dono."""
    from django.contrib.auth.models import User
    from tenants.models import Membro

    user = User.objects.create_user(username='colab@email.com', email='colab@email.com', password='senha123')
    Membro.objects.create(user=user, tenant=tenant, papel='colaborador')
    return user


@pytest.fixture
def expediente(patch_tenant_middleware):
    """Segunda das 8h às 11h, 1 por vez, até 3 no dia."""
    return HorarioFuncionamento.objects.create(
        dia=0, abertura=time(8), fechamento=time(11), ativo=True, capacidade=3, vagas=1,
    )


@pytest.fixture
def etapas(patch_tenant_middleware):
    return EtapaService().criar_etapas_padrao()


@pytest.fixture
def lavagem(patch_tenant_middleware):
    return Servico.objects.create(nome='Lavagem', nicho='lava_rapido', duracao=40, preco='40.00')


@pytest.fixture
def carro(patch_tenant_middleware):
    cliente = Cliente.objects.create(nome='Ana', telefone='11999990000')
    return Veiculo.objects.create(cliente=cliente, tipo='veiculo', placa='ABC1D23', marca='VW', modelo='Gol', porte='carro')


def _receber(etapas, carro, lavagem, hora=None, data=SEGUNDA, **extra):
    return AtendimentoKanbanService().criar(
        etapa=etapas[0], objeto_id=carro.pk, servico_id=lavagem.pk, horario_entrada=hora, data=data, **extra,
    )


@pytest.mark.django_db
class TestLimitesDoDia:
    def test_vem_do_horario_da_semana(self, expediente):
        assert CapacidadeService().limites(SEGUNDA) == {'capacidade': 3, 'vagas': 1, 'ajustado': False}

    def test_dia_sem_horario_cabe_um_por_vez_sem_maximo(self, patch_tenant_middleware):
        assert CapacidadeService().limites(SEGUNDA) == {'capacidade': None, 'vagas': 1, 'ajustado': False}

    def test_o_ajuste_da_data_vale_so_nela(self, expediente):
        CapacidadeService().ajustar(SEGUNDA, capacidade=6, vagas=2)

        assert CapacidadeService().limites(SEGUNDA) == {'capacidade': 6, 'vagas': 2, 'ajustado': True}
        # a segunda seguinte continua no padrão
        assert CapacidadeService().limites(SEGUNDA + timedelta(days=7))['capacidade'] == 3

    def test_desfazer_o_ajuste_volta_ao_padrao(self, expediente):
        CapacidadeService().ajustar(SEGUNDA, capacidade=6, vagas=2)

        info = CapacidadeService().desfazer_ajuste(SEGUNDA)

        assert info['ajustado'] is False
        assert info['capacidade'] == 3
        assert not AjusteDoDia.objects.exists()

    def test_ocupados_conta_os_sem_hora_e_nao_conta_quem_faltou(self, expediente, etapas, carro, lavagem):
        _receber(etapas, carro, lavagem)
        _receber(etapas, carro, lavagem, time(9))
        faltou = _receber(etapas, carro, lavagem, time(10))
        AtendimentoKanbanService().marcar_falta(faltou)

        assert CapacidadeService().do_dia(SEGUNDA)['ocupados'] == 2


@pytest.mark.django_db
class TestMaximoNoDia:
    def test_dia_lotado_e_parede_na_grade_e_aviso_para_o_dono(self, expediente, etapas, carro, lavagem):
        for _ in range(3):
            _receber(etapas, carro, lavagem)

        assert CapacidadeService().livres(SEGUNDA, 40) == []
        with pytest.raises(ErroDeNegocio) as erro:
            _receber(etapas, carro, lavagem, time(9))
        assert erro.value.code == 'dia_lotado'

        # o dono recebe mesmo assim
        assert _receber(etapas, carro, lavagem, time(9), ignorar_limite=True).pk

    def test_sem_maximo_o_dia_nao_lota(self, patch_tenant_middleware, etapas, carro, lavagem):
        HorarioFuncionamento.objects.create(dia=0, abertura=time(8), fechamento=time(11), ativo=True, capacidade=None)
        for _ in range(5):
            _receber(etapas, carro, lavagem)

        assert not CapacidadeService().lotado(SEGUNDA)


@pytest.mark.django_db
class TestVagasAoMesmoTempo:
    def test_a_grade_segue_a_duracao_do_servico(self, expediente, lavagem):
        livres = [h.strftime('%H:%M') for h in CapacidadeService().livres(SEGUNDA, 40)]

        assert livres[:3] == ['08:00', '08:15', '08:30']
        # 10:20 + 40 min = 11:00, o fechamento; 10:30 não cabe mais
        assert livres[-1] == '10:20' or livres[-1] == '10:15'
        assert '10:30' not in livres

    def test_com_uma_vaga_o_atendimento_tira_a_hora_dele_da_grade(self, expediente, etapas, carro, lavagem):
        _receber(etapas, carro, lavagem, time(9))

        livres = [h.strftime('%H:%M') for h in CapacidadeService().livres(SEGUNDA, 40)]

        # 8:15 + 40 = 8:55 ainda cabe; de 8:30 a 9:30 não; o fim do ocupado
        # (9:40) é oferecido mesmo fora da grade de 15 em 15
        assert livres == ['08:00', '08:15', '09:40', '09:45', '10:00', '10:15']

    def test_com_duas_vagas_cabem_dois_na_mesma_hora(self, expediente, etapas, carro, lavagem):
        CapacidadeService().ajustar(SEGUNDA, capacidade=None, vagas=2)
        _receber(etapas, carro, lavagem, time(9))

        assert '09:00' in [h.strftime('%H:%M') for h in CapacidadeService().livres(SEGUNDA, 40)]
        _receber(etapas, carro, lavagem, time(9))
        assert '09:00' not in [h.strftime('%H:%M') for h in CapacidadeService().livres(SEGUNDA, 40)]

    def test_hora_sem_vaga_e_horario_ocupado_para_o_dono(self, expediente, etapas, carro, lavagem):
        _receber(etapas, carro, lavagem, time(9))

        with pytest.raises(ValidationError) as erro:
            _receber(etapas, carro, lavagem, time(9, 15))
        assert erro.value.detail['code'] == 'horario_ocupado'

        assert _receber(etapas, carro, lavagem, time(9, 15), ignorar_limite=True).pk

    def test_o_tempo_a_mais_previsto_estende_a_ocupacao(self, expediente, etapas, carro, lavagem):
        atendimento = _receber(etapas, carro, lavagem, time(8))
        assert '08:40' in [h.strftime('%H:%M') for h in CapacidadeService().livres(SEGUNDA, 40)]

        atendimento.minutos_extras = 60
        atendimento.save()

        assert '08:40' not in [h.strftime('%H:%M') for h in CapacidadeService().livres(SEGUNDA, 40)]
        assert '09:40' in [h.strftime('%H:%M') for h in CapacidadeService().livres(SEGUNDA, 40)]


@pytest.mark.django_db
class TestOCardSeguraAVaga:
    """O pátio manda: passado o previsto, o card que não chegou em pronto
    continua ocupando; chegando, libera na hora em que chegou."""

    @pytest.fixture
    def hoje(self):
        return timezone.localdate()

    @pytest.fixture
    def expediente_hoje(self, patch_tenant_middleware, hoje):
        return HorarioFuncionamento.objects.create(
            dia=hoje.weekday(), abertura=time(0), fechamento=time(23, 59), ativo=True, vagas=1,
        )

    def test_atrasado_continua_ocupando_ate_agora(self, expediente_hoje, hoje, etapas, carro, lavagem):
        agora = timezone.localtime().replace(tzinfo=None, second=0, microsecond=0)
        entrada = (agora - timedelta(hours=2)).time()
        _receber(etapas, carro, lavagem, entrada, data=hoje)

        inicio, fim = CapacidadeService().ocupacoes(hoje)[0]

        assert inicio.time() == entrada.replace(second=0, microsecond=0)
        assert fim >= agora

    def test_pronto_libera_na_hora_em_que_chegou(self, expediente_hoje, hoje, etapas, carro, lavagem):
        agora = timezone.localtime().replace(tzinfo=None, second=0, microsecond=0)
        atendimento = _receber(etapas, carro, lavagem, (agora - timedelta(hours=2)).time(), data=hoje)

        AtendimentoKanbanService().mover(atendimento, etapas[2])

        assert atendimento.pronto_em is not None
        _, fim = CapacidadeService().ocupacoes(hoje)[0]
        assert fim <= agora + timedelta(minutes=1)

    def test_voltar_para_antes_de_pronto_desfaz(self, expediente_hoje, hoje, etapas, carro, lavagem):
        atendimento = _receber(etapas, carro, lavagem, time(8), data=hoje)
        AtendimentoKanbanService().mover(atendimento, etapas[2])

        AtendimentoKanbanService().mover(atendimento, etapas[1])

        assert atendimento.pronto_em is None

    def test_sem_hora_ocupa_desde_que_foi_lancado(self, expediente_hoje, hoje, etapas, carro, lavagem):
        _receber(etapas, carro, lavagem, data=hoje)

        inicio, fim = CapacidadeService().ocupacoes(hoje)[0]
        agora = timezone.localtime().replace(tzinfo=None, second=0, microsecond=0)

        assert inicio <= agora
        assert fim >= inicio + timedelta(minutes=40)


@pytest.mark.django_db
class TestAgoraNaGrade:
    """O "agora" que estende o card atrasado entra arredondado para a marca
    de 15 min: a grade nunca oferece 10:37:12."""

    def test_o_atrasado_libera_na_proxima_marca_e_a_grade_so_tem_marcas(self, etapas, carro, lavagem):
        hoje = timezone.localdate()
        HorarioFuncionamento.objects.create(
            dia=hoje.weekday(), abertura=time(0), fechamento=time(23, 59), ativo=True, vagas=1,
        )
        agora = timezone.localtime().replace(tzinfo=None)
        _receber(etapas, carro, lavagem, (agora - timedelta(hours=2)).time(), data=hoje)

        _, fim = CapacidadeService().ocupacoes(hoje)[0]
        livres = CapacidadeService().livres(hoje, 40)

        assert fim >= proxima_marca(agora)
        assert fim.second == 0 and fim.minute % 15 == 0
        assert all(h.second == 0 and h.minute % 15 == 0 for h in livres)


@pytest.mark.django_db
class TestEtapaPronto:
    def test_o_quadro_padrao_nasce_com_concluido_marcado(self, etapas):
        assert [e.pronto for e in etapas] == [False, False, True]
        assert EtapaService().etapa_pronto() == etapas[2]

    def test_sem_marcacao_vale_a_ultima(self, patch_tenant_middleware):
        a = EtapaKanban.objects.create(nome='A', ordem=0)
        b = EtapaKanban.objects.create(nome='B', ordem=1)

        assert EtapaService().etapa_pronto() == b
        assert EtapaService().ids_prontos() == {b.pk}
        assert a.pronto is False

    def test_marcar_outra_desmarca_a_anterior_e_as_depois_contam(self, etapas):
        entregue = EtapaKanban.objects.create(nome='Entregue', ordem=3)

        EtapaService().marcar_pronto(etapas[1])

        assert EtapaKanban.objects.filter(pronto=True).count() == 1
        assert EtapaService().ids_prontos() == {etapas[1].pk, etapas[2].pk, entregue.pk}

    def test_status_do_cliente_segue_a_marcacao(self, etapas):
        entregue = EtapaKanban.objects.create(nome='Entregue', ordem=3)
        EtapaService().marcar_pronto(etapas[2])

        mapa = StatusClienteService().mapa_por_etapa()

        assert mapa[etapas[0].pk] == 'aguardando'
        assert mapa[etapas[1].pk] == 'em_atendimento'
        assert mapa[etapas[2].pk] == 'concluido'
        assert mapa[entregue.pk] == 'concluido'

    def test_nao_remove_a_etapa_de_pronto_com_outras_no_quadro(self, etapas):
        with pytest.raises(ErroDeNegocio) as erro:
            EtapaService().remover(etapas[2])

        assert erro.value.code == 'etapa_pronto'

    def test_api_marca_a_etapa_e_recusa_remover(self, api, etapas):
        resposta = api.post(f'/api/v1/kanban/etapas/{etapas[1].pk}/pronto/')

        assert resposta.status_code == 200
        assert resposta.data['pronto'] is True
        assert api.delete(f'/api/v1/kanban/etapas/{etapas[1].pk}/').status_code == 400

    def test_a_primeira_etapa_e_a_espera_e_nao_vira_pronto(self, api, etapas):
        with pytest.raises(ErroDeNegocio) as erro:
            EtapaService().marcar_pronto(etapas[0])
        assert erro.value.code == 'etapa_pronto_invalida'

        resposta = api.post(f'/api/v1/kanban/etapas/{etapas[0].pk}/pronto/')
        assert resposta.status_code == 400
        assert resposta.data['code'] == 'etapa_pronto_invalida'

    def test_com_uma_etapa_so_nada_conta_como_pronto(self, patch_tenant_middleware, carro, lavagem):
        """Uma coluna só não tem fim: o card segura a vaga até sair do quadro,
        e a única etapa é a espera (não dá para marcá-la como pronto)."""
        unica = EtapaKanban.objects.create(nome='Única')

        assert EtapaService().ids_prontos() == set()
        assert _receber([unica], carro, lavagem).pronto_em is None
        with pytest.raises(ErroDeNegocio):
            EtapaService().marcar_pronto(unica)

    def test_empate_de_ordem_desempata_pelo_id(self, patch_tenant_middleware):
        EtapaKanban.objects.create(nome='A')
        EtapaKanban.objects.create(nome='B')
        c = EtapaKanban.objects.create(nome='C')

        assert EtapaService().etapa_pronto() == c
        assert EtapaService().ids_prontos() == {c.pk}

    def test_reordenar_nao_poe_a_etapa_de_pronto_na_primeira_posicao(self, api, etapas):
        with pytest.raises(ErroDeNegocio) as erro:
            EtapaService().reordenar([etapas[2].pk, etapas[0].pk, etapas[1].pk])

        assert erro.value.code == 'etapa_pronto_invalida'
        # a reordenação foi desfeita inteira
        assert list(EtapaKanban.objects.order_by('ordem').values_list('id', flat=True)) == [e.pk for e in etapas]

        resposta = api.post('/api/v1/kanban/etapas/reordenar/', {'ordem': [etapas[2].pk, etapas[0].pk, etapas[1].pk]}, format='json')
        assert resposta.status_code == 400
        assert resposta.data['code'] == 'etapa_pronto_invalida'

    def test_remover_a_ultima_sem_marcacao_recalcula_o_pronto(self, carro, lavagem):
        a = EtapaKanban.objects.create(nome='A', ordem=0)
        b = EtapaKanban.objects.create(nome='B', ordem=1)
        c = EtapaKanban.objects.create(nome='C', ordem=2)
        hoje = timezone.localdate()
        em_b = _receber([a], carro, lavagem, data=hoje)
        AtendimentoKanbanService().mover(em_b, b)
        assert em_b.pronto_em is None

        EtapaService().remover(c)

        em_b.refresh_from_db()
        assert EtapaService().ids_prontos() == {b.pk}
        assert em_b.pronto_em is not None

    def test_marcar_pronto_acerta_a_hora_dos_cards_de_hoje_em_diante(self, etapas, carro, lavagem):
        hoje = timezone.localdate()
        em_atendimento = _receber(etapas, carro, lavagem, data=hoje)
        AtendimentoKanbanService().mover(em_atendimento, etapas[1])
        concluido = _receber(etapas, carro, lavagem, data=hoje)
        AtendimentoKanbanService().mover(concluido, etapas[2])
        antigo = _receber(etapas, carro, lavagem, data=date(2020, 1, 6))
        AtendimentoKanbanService().mover(antigo, etapas[1])

        EtapaService().marcar_pronto(etapas[1])

        em_atendimento.refresh_from_db()
        concluido.refresh_from_db()
        antigo.refresh_from_db()
        assert em_atendimento.pronto_em is not None
        assert concluido.pronto_em is not None
        assert antigo.pronto_em is None, 'o passado é história'

        EtapaService().marcar_pronto(etapas[2])

        em_atendimento.refresh_from_db()
        assert em_atendimento.pronto_em is None

    def test_criado_direto_na_etapa_de_pronto_nasce_com_a_hora(self, etapas, carro, lavagem):
        atendimento = AtendimentoKanbanService().criar(
            etapa=etapas[2], objeto_id=carro.pk, servico_id=lavagem.pk, data=SEGUNDA,
        )

        assert atendimento.pronto_em is not None

    def test_pronto_nao_muda_por_patch_da_etapa(self, api, etapas):
        resposta = api.patch(f'/api/v1/kanban/etapas/{etapas[1].pk}/', {'pronto': True}, format='json')

        assert resposta.status_code == 200
        assert resposta.data['pronto'] is False
        assert EtapaService().etapa_pronto() == etapas[2]

    def test_colaborador_nao_marca_pronto(self, patch_tenant_middleware, colaborador, etapas):
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        client.force_authenticate(user=colaborador)

        assert client.post(f'/api/v1/kanban/etapas/{etapas[1].pk}/pronto/').status_code == 403


@pytest.mark.django_db
class TestCapacidadeAPI:
    URL = '/api/v1/kanban/capacidade/'

    def test_le_o_dia(self, api, expediente, etapas, carro, lavagem):
        _receber(etapas, carro, lavagem)

        resposta = api.get(self.URL, {'data': '2026-06-15'})

        assert resposta.status_code == 200
        assert resposta.data == {'data': '2026-06-15', 'capacidade': 3, 'vagas': 1, 'ajustado': False, 'ocupados': 1}

    def test_ajusta_e_desfaz(self, api, expediente):
        resposta = api.put(f'{self.URL}?data=2026-06-15', {'capacidade': 14, 'vagas': 2}, format='json')
        assert resposta.status_code == 200
        assert resposta.data['ajustado'] is True
        assert resposta.data['capacidade'] == 14

        resposta = api.put(f'{self.URL}?data=2026-06-15', {'capacidade': None, 'vagas': 1}, format='json')
        assert resposta.data['capacidade'] is None

        resposta = api.delete(f'{self.URL}?data=2026-06-15')
        assert resposta.status_code == 200
        assert resposta.data['ajustado'] is False

    def test_data_invalida(self, api):
        assert api.get(self.URL, {'data': 'ontem'}).status_code == 400

    def test_colaborador_le_mas_nao_ajusta(self, patch_tenant_middleware, colaborador, expediente):
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        client.force_authenticate(user=colaborador)

        assert client.get(self.URL, {'data': '2026-06-15'}).status_code == 200
        assert client.put(f'{self.URL}?data=2026-06-15', {'vagas': 2}, format='json').status_code == 403
        assert client.delete(f'{self.URL}?data=2026-06-15').status_code == 403

    def test_ajuste_sem_o_maximo_e_recusado(self, api, expediente):
        """Omitir e mandar null seriam a mesma coisa: só o null explícito é
        "sem máximo"."""
        resposta = api.put(f'{self.URL}?data=2026-06-15', {'vagas': 2}, format='json')

        assert resposta.status_code == 400
        assert 'capacidade' in resposta.data['fields']
        assert not AjusteDoDia.objects.exists()


@pytest.mark.django_db
class TestAtendimentoAPI:
    def _payload(self, etapas, carro, lavagem, **extra):
        return {'etapa': etapas[0].pk, 'objeto': carro.pk, 'servico': lavagem.pk, 'data': '2026-06-15', **extra}

    def test_dia_lotado_e_ignorar_limite(self, api, expediente, etapas, carro, lavagem):
        for _ in range(3):
            _receber(etapas, carro, lavagem)

        resposta = api.post('/api/v1/kanban/atendimentos/', self._payload(etapas, carro, lavagem))
        assert resposta.status_code == 400
        assert resposta.data['code'] == 'dia_lotado'

        resposta = api.post(
            '/api/v1/kanban/atendimentos/', self._payload(etapas, carro, lavagem, ignorar_limite=True), format='json',
        )
        assert resposta.status_code == 201
        assert 'ignorar_limite' not in resposta.data

    def test_grade_com_o_servico(self, api, expediente, lavagem):
        resposta = api.get('/api/v1/kanban/slots/', {'data': '2026-06-15', 'servico': lavagem.pk})

        assert resposta.status_code == 200
        assert resposta.data[0] == {'horario': '08:00', 'disponivel': True}
        assert all(s['disponivel'] for s in resposta.data)
        assert '10:30' not in [s['horario'] for s in resposta.data]

    def test_remarcar_confere_o_dia_de_destino(self, api, expediente, etapas, carro, lavagem):
        atendimento = _receber(etapas, carro, lavagem, time(9), data=date(2026, 6, 16))
        _receber(etapas, carro, lavagem, time(9))

        resposta = api.patch(
            f'/api/v1/kanban/atendimentos/{atendimento.pk}/', {'data': '2026-06-15', 'horario_entrada': '09:15'},
            format='json',
        )
        assert resposta.status_code == 400
        assert resposta.data['code'] == 'horario_ocupado'

        resposta = api.patch(
            f'/api/v1/kanban/atendimentos/{atendimento.pk}/', {'data': '2026-06-15', 'horario_entrada': '09:40'},
            format='json',
        )
        assert resposta.status_code == 200
        assert resposta.data['data'] == '2026-06-15'

    def test_remarcar_na_mesma_hora_nao_bate_consigo_mesmo(self, api, expediente, etapas, carro, lavagem):
        atendimento = _receber(etapas, carro, lavagem, time(9))

        resposta = api.patch(
            f'/api/v1/kanban/atendimentos/{atendimento.pk}/', {'observacao': 'barro', 'horario_entrada': '09:00'},
            format='json',
        )

        assert resposta.status_code == 200

    def test_ajustar_o_tempo_nao_e_barrado_e_sai_na_duracao_prevista(self, api, expediente, etapas, carro, lavagem):
        for _ in range(3):
            _receber(etapas, carro, lavagem)
        atendimento = AtendimentoKanban.objects.first()

        resposta = api.patch(f'/api/v1/kanban/atendimentos/{atendimento.pk}/', {'minutos_extras': 80}, format='json')

        assert resposta.status_code == 200
        assert resposta.data['duracao_prevista'] == 120
        assert resposta.data['pronto_em'] is None

    def test_mover_para_pronto_sai_com_a_hora(self, api, etapas, carro, lavagem):
        atendimento = _receber(etapas, carro, lavagem)

        resposta = api.post(f'/api/v1/kanban/atendimentos/{atendimento.pk}/mover/', {'etapa_id': etapas[2].pk})

        assert resposta.status_code == 200
        assert resposta.data['pronto_em'] is not None

    def test_patch_de_etapa_segue_a_regra_do_pronto(self, api, etapas, carro, lavagem):
        atendimento = _receber(etapas, carro, lavagem)
        url = f'/api/v1/kanban/atendimentos/{atendimento.pk}/'

        resposta = api.patch(url, {'etapa': etapas[2].pk}, format='json')
        assert resposta.status_code == 200
        assert resposta.data['pronto_em'] is not None

        resposta = api.patch(url, {'etapa': etapas[1].pk}, format='json')
        assert resposta.data['pronto_em'] is None

    def test_receber_com_tempo_a_mais_ja_ocupa_o_tempo_todo(self, api, expediente, etapas, carro, lavagem):
        resposta = api.post(
            '/api/v1/kanban/atendimentos/',
            self._payload(etapas, carro, lavagem, horario_entrada='09:00', minutos_extras=60), format='json',
        )

        assert resposta.status_code == 201
        assert resposta.data['minutos_extras'] == 60
        assert resposta.data['duracao_prevista'] == 100
        # o carro fica até 10:40: o 09:40 não é mais oferecido
        grade = api.get('/api/v1/kanban/slots/', {'data': '2026-06-15', 'servico': lavagem.pk}).data
        assert '09:40' not in [s['horario'] for s in grade]
        assert '08:00' in [s['horario'] for s in grade]

    def test_remarcar_para_dia_lotado_e_ignorar_limite(self, api, expediente, etapas, carro, lavagem):
        for _ in range(3):
            _receber(etapas, carro, lavagem)
        terca = _receber(etapas, carro, lavagem, data=date(2026, 6, 16))
        url = f'/api/v1/kanban/atendimentos/{terca.pk}/'

        resposta = api.patch(url, {'data': '2026-06-15'}, format='json')
        assert resposta.status_code == 400
        assert resposta.data['code'] == 'dia_lotado'

        resposta = api.patch(url, {'data': '2026-06-15', 'ignorar_limite': True}, format='json')
        assert resposta.status_code == 200
        assert resposta.data['data'] == '2026-06-15'

    def test_no_mesmo_dia_lotado_a_hora_muda_e_so_ela_e_conferida(self, api, expediente, etapas, carro, lavagem):
        """O card já tem a vaga dele no dia: mudar a hora não bate no máximo."""
        primeiro = _receber(etapas, carro, lavagem, time(8))
        for _ in range(2):
            _receber(etapas, carro, lavagem)
        url = f'/api/v1/kanban/atendimentos/{primeiro.pk}/'

        resposta = api.patch(url, {'horario_entrada': '09:00'}, format='json')
        assert resposta.status_code == 200
        assert resposta.data['horario_entrada'] == '09:00:00'

        resposta = api.patch(url, {'observacao': 'barro', 'pago': True}, format='json')
        assert resposta.status_code == 200

    def test_trocar_para_um_servico_que_nao_cabe_e_horario_ocupado(self, api, expediente, etapas, carro, lavagem):
        polimento = Servico.objects.create(nome='Polimento', nicho='lava_rapido', duracao=90, preco='150.00')
        primeiro = _receber(etapas, carro, lavagem, time(8))
        _receber(etapas, carro, lavagem, time(9))
        url = f'/api/v1/kanban/atendimentos/{primeiro.pk}/'

        resposta = api.patch(url, {'servico': polimento.pk}, format='json')
        assert resposta.status_code == 400
        assert resposta.data['code'] == 'horario_ocupado'

        assert api.patch(url, {'servico': polimento.pk, 'ignorar_limite': True}, format='json').status_code == 200

    def test_a_grade_nao_conta_o_card_que_esta_sendo_remarcado(self, api, expediente, etapas, carro, lavagem):
        atendimento = _receber(etapas, carro, lavagem, time(9))
        for _ in range(2):
            _receber(etapas, carro, lavagem)
        consulta = {'data': '2026-06-15', 'servico': lavagem.pk}

        sem = api.get('/api/v1/kanban/slots/', consulta).data
        com = api.get('/api/v1/kanban/slots/', {**consulta, 'excluir': atendimento.pk}).data

        # com os 3 o dia está lotado: sem o excluir a grade vem vazia
        assert sem == []
        assert '09:00' in [s['horario'] for s in com]

    def test_grade_com_servico_inexistente_e_404(self, api, expediente):
        resposta = api.get('/api/v1/kanban/slots/', {'data': '2026-06-15', 'servico': 9999})

        assert resposta.status_code == 404
        assert resposta.data['code'] == 'nao_encontrado'
        assert api.get('/api/v1/kanban/slots/', {'data': '2026-06-15', 'servico': 'x'}).status_code == 400
