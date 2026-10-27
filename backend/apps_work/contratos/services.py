from django.utils import timezone

from .models import Contrato, ModeloContrato, StatusContrato
from core.email import enviar_email
from core.links import link_contrato
from core.excecoes import ErroDeNegocio


_VARIAVEIS = {
    '{{cliente_nome}}',
    '{{cliente_email}}',
    '{{cliente_cpf}}',
    '{{data}}',
    '{{negocio_nome}}',
}


class ContratoService:
    def _negocio_nome(self) -> str:
        try:
            from apps_work.empresa.models import EmpresaConfig
            config = EmpresaConfig.objects.first()
            return config.nome if config else ''
        except Exception:
            return ''

    def _substituir_variaveis(self, texto: str, cliente) -> str:
        hoje = timezone.localdate().strftime('%d/%m/%Y')
        return (
            texto
            .replace('{{cliente_nome}}', cliente.nome or '')
            .replace('{{cliente_email}}', cliente.email or '')
            .replace('{{cliente_cpf}}', cliente.cpf or '')
            .replace('{{data}}', hoje)
            .replace('{{negocio_nome}}', self._negocio_nome())
        )

    def gerar(self, modelo: ModeloContrato, cliente) -> Contrato:
        corpo = self._substituir_variaveis(modelo.corpo, cliente)
        return Contrato.objects.create(
            modelo=modelo,
            cliente=cliente,
            titulo=modelo.titulo,
            corpo=corpo,
        )

    def enviar(self, contrato: Contrato, schema_name: str) -> None:
        if not contrato.cliente.email:
            raise ErroDeNegocio('O cliente não possui e-mail cadastrado.', 'cliente_sem_email')
        if contrato.status == StatusContrato.ASSINADO:
            raise ErroDeNegocio('Este contrato já foi assinado.', 'contrato_ja_assinado')

        link = link_contrato(schema_name, contrato.token)

        corpo_email = (
            f'Olá, {contrato.cliente.nome}!\n\n'
            f'Você recebeu um contrato para assinar: **{contrato.titulo}**\n\n'
            f'Acesse o link abaixo para ler e assinar:\n{link}\n\n'
            f'Este link é exclusivo e intransferível.'
        )
        corpo_html = f"""
        <p>Olá, <strong>{contrato.cliente.nome}</strong>!</p>
        <p>Você recebeu um contrato para assinar: <strong>{contrato.titulo}</strong></p>
        <p>
            <a href="{link}" style="
                display:inline-block;
                padding:12px 24px;
                background:#1a1a1a;
                color:#fff;
                text-decoration:none;
                border-radius:8px;
                font-weight:600;
            ">
                Ler e Assinar Contrato
            </a>
        </p>
        <p style="color:#888;font-size:12px;">
            Este link é exclusivo e intransferível.
        </p>
        """

        enviar_email.enqueue(
            assunto=f'[Contrato] {contrato.titulo}',
            mensagem=corpo_email,
            destinatario=contrato.cliente.email,
            html=corpo_html,
        )

        contrato.status = StatusContrato.ENVIADO
        contrato.save(update_fields=['status', 'atualizado_em'])

    def assinar(self, contrato: Contrato, nome_assinante: str, ip: str) -> Contrato:
        if contrato.status == StatusContrato.ASSINADO:
            raise ErroDeNegocio('Contrato já foi assinado.', 'contrato_ja_assinado')
        if contrato.status == StatusContrato.RECUSADO:
            raise ErroDeNegocio('Contrato foi recusado e não pode ser assinado.', 'contrato_recusado')

        contrato.status = StatusContrato.ASSINADO
        contrato.nome_assinante = nome_assinante
        contrato.ip_assinante = ip
        contrato.assinado_em = timezone.now()
        contrato.save(update_fields=[
            'status', 'nome_assinante', 'ip_assinante', 'assinado_em', 'atualizado_em',
        ])
        return contrato

    def marcar(self, contrato: Contrato, novo_status: str, nome_assinante: str = '') -> Contrato:
        """O dono registra o que aconteceu fora do sistema.

        O app gera o PDF e manda pelo WhatsApp (enviado), o cliente devolve
        assinado (assinado) ou diz que não assina (recusado). Finalizado não
        volta: o que foi assinado ou recusado fica como está.
        """
        if contrato.status in (StatusContrato.ASSINADO, StatusContrato.RECUSADO):
            raise ErroDeNegocio('Este contrato já está finalizado.', 'contrato_finalizado')
        if novo_status == StatusContrato.ENVIADO:
            if contrato.status != StatusContrato.PENDENTE:
                raise ErroDeNegocio('Este contrato já foi enviado.', 'contrato_ja_enviado')
            contrato.status = StatusContrato.ENVIADO
            contrato.save(update_fields=['status', 'atualizado_em'])
            return contrato
        if novo_status == StatusContrato.ASSINADO:
            # sem IP: a assinatura veio no papel ou no PDF, não pelo link
            return self.assinar(contrato, nome_assinante or contrato.cliente.nome, ip=None)
        if novo_status == StatusContrato.RECUSADO:
            return self.recusar(contrato)
        raise ErroDeNegocio('Status inválido.', 'status_invalido')

    def remover(self, contrato: Contrato) -> None:
        if contrato.status == StatusContrato.ASSINADO:
            raise ErroDeNegocio('Contrato assinado não pode ser apagado.', 'contrato_assinado')
        contrato.delete()

    def recusar(self, contrato: Contrato) -> Contrato:
        if contrato.status in (StatusContrato.ASSINADO, StatusContrato.RECUSADO):
            raise ErroDeNegocio('Contrato já está finalizado.', 'contrato_finalizado')
        contrato.status = StatusContrato.RECUSADO
        contrato.save(update_fields=['status', 'atualizado_em'])
        return contrato


def contrato_publico(schema_name: str, token) -> Contrato | None:
    """O contrato aberto pelo link do e-mail, ou None se o link não leva a um.

    Usado pela API pública e pela página de assinatura (apps_work/paginas). O
    schema vem da URL: sem checar, schema inexistente dava 500 e o público era
    alcançável.
    """
    from django_tenants.utils import schema_context
    from core.schemas import schema_valido
    from tenants.models import Tenant

    if not schema_valido(schema_name) or not Tenant.objects.filter(schema_name=schema_name).exists():
        return None
    with schema_context(schema_name):
        return Contrato.objects.select_related('cliente').filter(token=token).first()
