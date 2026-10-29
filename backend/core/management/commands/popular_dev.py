from django.conf import settings
from django.contrib.auth.models import User
from django.core.management.base import BaseCommand, CommandError
from django_tenants.utils import schema_context


class Command(BaseCommand):
    help = (
        'Popula o banco local: plano padrão e uma empresa de exemplo com o dono e o '
        'onboarding concluído. Só roda com DEBUG=True. Idempotente.'
    )

    def add_arguments(self, parser):
        parser.add_argument('--empresa', default=None, help='Padrão: "Barbearia Demo" (ou o nome do nicho escolhido)')
        parser.add_argument('--nome', default='Dono Demo')
        parser.add_argument('--email', default=None, help='Padrão: dono@demo.com (ou dono.<nicho>@demo.com)')
        parser.add_argument('--senha', default='SenhaForte123!')
        parser.add_argument(
            '--nicho', default='barbearia', choices=sorted(self.DEMOS),
            help='Nicho da empresa de exemplo. lava_rapido e banho_tosa nascem no modo kanban, com as etapas padrão.',
        )

    # Um exemplo por modo de agenda: o painel e o app se testam nos dois.
    DEMOS = {
        'barbearia': ('Barbearia Demo', 'dono@demo.com'),
        'lava_rapido': ('Lava Rápido Demo', 'dono.lava@demo.com'),
        'banho_tosa': ('Banho e Tosa Demo', 'dono.pet@demo.com'),
    }

    def handle(self, *args, empresa, nome, email, senha, nicho, **options):
        if not settings.DEBUG:
            raise CommandError('popular_dev só roda com DEBUG=True: não existe dado de exemplo fora do ambiente local.')

        empresa_padrao, email_padrao = self.DEMOS[nicho]
        empresa = empresa or empresa_padrao
        email = email or email_padrao

        plano = self._garantir_plano()
        self.stdout.write(f'Plano padrão: {plano.nome} (R$ {plano.preco_mensal})')

        if User.objects.filter(username=email.lower()).exists():
            self.stdout.write(f'{email} já existe — nada a criar.')
            return

        tenant = self._criar_empresa(empresa, nome, email, senha)
        self._concluir_onboarding(tenant, empresa, email, nicho)

        self.stdout.write(self.style.SUCCESS(
            f'Empresa "{tenant.nome}" (schema {tenant.schema_name}) criada.\n'
            f'Login: {email} / {senha}'
        ))

    def _garantir_plano(self):
        from apps_work.billing.services import plano_padrao
        return plano_padrao()

    def _criar_empresa(self, empresa, nome, email, senha):
        # O mesmo caminho do cadastro pela API: valida o nome e gera o schema.
        from apps_work.autenticacao.serializers import CadastroSerializer

        serializer = CadastroSerializer(data={'nome_empresa': empresa, 'nome': nome, 'email': email, 'senha': senha})
        if not serializer.is_valid():
            raise CommandError(f'Dados inválidos: {serializer.errors}')
        _, tenant = serializer.save()
        return tenant

    def _concluir_onboarding(self, tenant, empresa, email, nicho):
        from apps_work.empresa.models import EmpresaConfig, TipoDocumento
        from apps_work.empresa.services import ConfiguracaoEmpresaService, ModoAgendaService

        user = User.objects.get(username=email.lower())
        with schema_context(tenant.schema_name):
            config, _ = EmpresaConfig.objects.get_or_create(pk=1)
            config.nome = empresa
            # O nicho decide o modo de agenda e o objeto, como no onboarding.
            modo = ModoAgendaService().resolver([nicho], '', '', '')
            config.nichos = modo.nichos
            config.tipo_agenda = modo.tipo_agenda
            config.tipo_objeto = modo.tipo_objeto
            config.documento = '52998224725'  # CPF de teste (dígitos válidos)
            config.tipo_documento = TipoDocumento.CPF
            config.cidade = 'São Paulo'
            config.uf = 'SP'
            config.onboarding_concluido = True
            config.save()
            # Os mesmos efeitos de concluir o onboarding pela API: colaborador
            # do dono e publicação na vitrine.
            ConfiguracaoEmpresaService().apos_salvar(config, user, (config.endereco, config.cidade, config.uf))
