from django.conf import settings
from django.core.mail import send_mail
from django.utils import timezone

from .models import Contrato, ModeloContrato


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
            raise ValueError('O cliente não possui e-mail cadastrado.')
        if contrato.status == Contrato.STATUS_ASSINADO:
            raise ValueError('Este contrato já foi assinado.')

        frontend_url = getattr(settings, 'FRONTEND_URL', 'http://localhost:5173')
        link = f'{frontend_url}/contratos/{schema_name}/{contrato.token}'

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

        send_mail(
            subject=f'[Contrato] {contrato.titulo}',
            message=corpo_email,
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[contrato.cliente.email],
            html_message=corpo_html,
            fail_silently=False,
        )

        contrato.status = Contrato.STATUS_ENVIADO
        contrato.save(update_fields=['status', 'atualizado_em'])

    def assinar(self, contrato: Contrato, nome_assinante: str, ip: str) -> Contrato:
        if contrato.status == Contrato.STATUS_ASSINADO:
            raise ValueError('Contrato já foi assinado.')
        if contrato.status == Contrato.STATUS_RECUSADO:
            raise ValueError('Contrato foi recusado e não pode ser assinado.')

        contrato.status = Contrato.STATUS_ASSINADO
        contrato.nome_assinante = nome_assinante
        contrato.ip_assinante = ip
        contrato.assinado_em = timezone.now()
        contrato.save(update_fields=[
            'status', 'nome_assinante', 'ip_assinante', 'assinado_em', 'atualizado_em',
        ])
        return contrato

    def recusar(self, contrato: Contrato) -> Contrato:
        if contrato.status in (Contrato.STATUS_ASSINADO, Contrato.STATUS_RECUSADO):
            raise ValueError('Contrato já está finalizado.')
        contrato.status = Contrato.STATUS_RECUSADO
        contrato.save(update_fields=['status', 'atualizado_em'])
        return contrato
