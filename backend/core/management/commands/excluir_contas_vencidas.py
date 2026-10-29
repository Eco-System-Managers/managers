from django.core.management.base import BaseCommand


class Command(BaseCommand):
    help = (
        'Apaga de vez as contas com a exclusão pedida há mais de 30 dias: o negócio '
        'inteiro, quando foi o dono, ou só o login, quando foi alguém da equipe. '
        'Rodar uma vez por dia (cron no Railway). Pode rodar de novo sem efeito.'
    )

    def handle(self, *args, **options):
        from apps_work.autenticacao.services import ExclusaoContaService

        feitas = ExclusaoContaService().excluir_vencidas()
        self.stdout.write(self.style.SUCCESS(f'{feitas} conta(s) excluída(s).'))
