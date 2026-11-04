from django.core.management.base import BaseCommand
from django.utils import timezone

from apps_work.uso.relatorio import montar


def _data(dia) -> str:
    return dia.strftime('%d/%m')


def _quando(momento) -> str:
    if momento is None:
        return 'nunca'
    local = timezone.localtime(momento)
    dias = (timezone.localdate() - local.date()).days
    if dias == 0:
        return f'hoje {local:%H:%M}'
    if dias == 1:
        return f'ontem {local:%H:%M}'
    return f'há {dias} dias ({local:%d/%m})'


class Command(BaseCommand):
    help = (
        'Mostra como os negócios estão usando o app: quem usou por dia, até onde '
        'cada negócio chegou, as ações mais usadas, os erros e as rotas mais lentas.'
    )

    def add_arguments(self, parser):
        parser.add_argument('--dias', type=int, default=7, help='Tamanho do período, contando hoje (padrão: 7).')
        parser.add_argument('--empresa', help='Só um negócio, pelo schema_name.')

    def handle(self, *args, dias, empresa, **options):
        r = montar(dias=max(dias, 1), schema_name=empresa)
        escrever = self.stdout.write
        titulo = lambda texto: escrever('\n' + self.style.MIGRATE_HEADING(texto))  # noqa: E731

        escrever(self.style.SUCCESS(f'Uso de {_data(r.inicio)} a {_data(r.fim)}'))

        titulo('Por dia')
        if not r.por_dia:
            escrever('  Nenhum uso no período.')
        for dia in r.por_dia:
            escrever(
                f"  {_data(dia['dia'])}  {dia['pessoas']} pessoa(s) · {dia['negocios']} negócio(s) · "
                f"{dia['acoes']} ações · {dia['erros']} erros"
            )

        titulo('Negócios')
        for n in r.negocios:
            desde = f' · desde {_data(n.desde)}' if n.desde else ''
            modo = f' · {n.funil.modo}' if n.funil and n.funil.modo else ''
            escrever(f'  {n.nome} ({n.schema_name}){modo}{desde}')
            escrever(
                f'    Último uso: {_quando(n.ultimo_uso)} · no período: {n.pessoas} pessoa(s), '
                f'{n.acoes} ações, {n.erros} erros'
            )
            f = n.funil
            if f is None:
                escrever('    Funil: não foi possível ler o negócio (o schema está sem as migrations?)')
                continue
            escrever(
                f"    Funil: onboarding {'✓' if f.onboarding else '✗'} · {f.servicos} serviços · "
                f'{f.clientes} clientes · {f.atendimentos} atendimentos · {f.cobrados} cobrados · '
                f'equipe {f.equipe} ({f.com_acesso} com acesso) · {f.contratos} contratos'
            )

        titulo('Ações mais usadas')
        if not r.acoes_mais_usadas:
            escrever('  Nenhuma.')
        for a in r.acoes_mais_usadas:
            escrever(f"  {a['total']:>5}  {a['evento']}  ({a['negocios']} negócio(s))")

        titulo('Erros de regra e validação (4xx)')
        if not r.erros_de_regra:
            escrever('  Nenhum.')
        for e in r.erros_de_regra:
            escrever(f"  {e['total']:>5}  {e['evento']} → {e['status']} {e['codigo'] or '—'}  ({e['negocios']} negócio(s))")

        titulo('Erros do servidor (5xx)')
        if not r.erros_do_servidor:
            escrever('  Nenhum.')
        for e in r.erros_do_servidor:
            escrever(self.style.ERROR(
                f'  {timezone.localtime(e.criado_em):%d/%m %H:%M}  {e.evento} → {e.status}  '
                f"{e.schema_name or '—'} · usuário {e.user_id or '—'}"
            ))
        if r.erros_do_servidor:
            escrever('  O traceback está no log do Railway: filtre por @status:500 na mesma hora.')

        titulo('Mais lentas (média)')
        if not r.mais_lentas:
            escrever('  Nenhuma.')
        for m in r.mais_lentas:
            escrever(f"  {round(m['media']):>5} ms  {m['evento']}  (máx. {m['maximo']} ms, {m['total']}x)")
