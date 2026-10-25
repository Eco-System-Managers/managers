import re

from rest_framework import serializers
from .models import EmpresaConfig, HorarioFuncionamento, TipoAgenda
from .services import ModoAgendaService
from .validators import validar_documento


class EmpresaConfigSerializer(serializers.ModelSerializer):
    # A interface manda o documento com máscara (00.000.000/0000-00, 18 chars),
    # mais largo que o max_length=14 do model, que guarda só os dígitos. Sem
    # declarar aqui, o campo era recusado antes de chegar na normalização.
    documento = serializers.CharField(max_length=18, required=False, allow_blank=True)
    # Mesma história do documento: a interface manda 00000-000 (9 chars), o
    # model guarda só os 8 dígitos.
    cep = serializers.CharField(max_length=9, required=False, allow_blank=True)

    class Meta:
        model = EmpresaConfig
        fields = ['id', 'nome', 'telefone', 'documento', 'tipo_documento', 'nicho', 'nicho_descricao', 'cidade', 'endereco', 'numero', 'cep', 'uf', 'latitude', 'longitude', 'localizacao_confirmada', 'logo_url', 'tipo_agenda', 'tipo_objeto', 'onboarding_concluido', 'atualizado_em']
        # `localizacao_confirmada` não é escrito pela interface: ele é deduzido
        # do envio da coordenada, em update(). Deixá-lo gravável permitiria
        # travar o geocodificador sem nunca ter apontado um ponto no mapa.
        # `tipo_agenda` e `tipo_objeto` são graváveis, mas só valem no nicho
        # OUTRO — nos demais, ModoAgendaService os deduz do nicho.
        read_only_fields = ['id', 'localizacao_confirmada', 'atualizado_em']
        extra_kwargs = {
            'tipo_agenda': {'help_text': 'Escolhido pelo dono só no nicho `outro`; nos demais, deduzido do nicho.'},
            'tipo_objeto': {'help_text': 'O que o negócio recebe no kanban. Escolhido só no nicho `outro`; vazio no modo horário.'},
            'nicho_descricao': {'help_text': 'O ramo por extenso. Obrigatório no nicho `outro`; vazio nos demais.'},
        }

    def validate(self, attrs):
        """Documento e tipo andam sempre juntos, e são obrigatórios para um
        negócio com onboarding concluído — CPF para pessoa física, CNPJ para
        jurídica, nunca nenhum dos dois. A única escrita isenta é o ajuste da
        coordenada no mapa."""
        instance = self.instance
        documento = attrs.get('documento', instance.documento if instance else '')
        tipo = attrs.get('tipo_documento', instance.tipo_documento if instance else '')

        if bool(documento) != bool(tipo):
            raise serializers.ValidationError({
                'detail': 'Informe o tipo do documento (CPF ou CNPJ) junto com o número.',
                'code': 'documento_incompleto',
            })

        if documento:
            attrs['documento'] = validar_documento(documento, tipo)
            attrs['tipo_documento'] = tipo

        concluido = attrs.get(
            'onboarding_concluido',
            instance.onboarding_concluido if instance else False,
        )
        # Ajustar o pino no mapa é a única escrita liberada para quem concluiu o
        # onboarding antes da regra do documento existir. A cobrança do CPF/CNPJ
        # segue valendo para todo o resto do cadastro — o que não pode é uma
        # coordenada errada ficar presa no ar por causa dela, já que ela é o que
        # o cliente final usa para chegar até o negócio.
        so_localizacao = bool(attrs) and set(attrs).issubset({'latitude', 'longitude'})

        if concluido and not documento and not so_localizacao:
            raise serializers.ValidationError({
                'detail': 'Informe o CPF ou o CNPJ do negócio.',
                'code': 'documento_obrigatorio',
            })

        if 'cep' in attrs:
            attrs['cep'] = re.sub(r'\D', '', attrs['cep'])[:8]
        if 'uf' in attrs:
            attrs['uf'] = attrs['uf'].strip().upper()[:2]

        self._resolver_modo(attrs, instance)

        return attrs

    def _resolver_modo(self, attrs, instance):
        def valor(campo, padrao=''):
            return attrs.get(campo, getattr(instance, campo) if instance else padrao)

        modo = ModoAgendaService().resolver(
            nicho=valor('nicho'),
            nicho_descricao=valor('nicho_descricao'),
            tipo_agenda=valor('tipo_agenda', TipoAgenda.HORARIO),
            tipo_objeto=valor('tipo_objeto'),
            config=instance,
        )
        attrs['nicho_descricao'] = modo.nicho_descricao
        attrs['tipo_agenda'] = modo.tipo_agenda
        attrs['tipo_objeto'] = modo.tipo_objeto

    def update(self, instance, validated_data):
        # Coordenada enviada pela interface significa que o dono apontou o ponto
        # no mapa. É o único gesto que confirma a localização — e ele desliga o
        # geocodificador automático para esse negócio, em views.perform_update.
        if validated_data.get('latitude') is not None and validated_data.get('longitude') is not None:
            validated_data['localizacao_confirmada'] = True

        return super().update(instance, validated_data)


class HorarioFuncionamentoSerializer(serializers.ModelSerializer):
    dia_label = serializers.CharField(source='get_dia_display', read_only=True)

    class Meta:
        model = HorarioFuncionamento
        fields = ['id', 'dia', 'dia_label', 'abertura', 'fechamento', 'ativo', 'capacidade']

    def validate_capacidade(self, value):
        if value is not None and value < 1:
            raise serializers.ValidationError('A capacidade deve ser de pelo menos 1 atendimento por dia.')
        return value


# ---------------------------------------------------------------------------
# Formatos de entrada e saída (documentação OpenAPI das APIViews)
# ---------------------------------------------------------------------------

class CoordenadaSerializer(serializers.Serializer):
    # Mesmo formato do EmpresaConfig (decimal com 6 casas, como string): o
    # palpite vai direto para o PATCH da config, sem conversão no app.
    latitude = serializers.DecimalField(
        max_digits=9, decimal_places=6, allow_null=True, help_text='null quando não foi possível geocodificar.',
    )
    longitude = serializers.DecimalField(max_digits=9, decimal_places=6, allow_null=True)


class RuaNoPontoSerializer(serializers.Serializer):
    rua = serializers.CharField(allow_null=True, help_text='null quando a via não foi identificada.')


class UploadLogoSerializer(serializers.Serializer):
    logo = serializers.ImageField()


class LogoSerializer(serializers.Serializer):
    logo_url = serializers.URLField()

