from django.core.mail import send_mail
from django.tasks import task


@task
def enviar_email(assunto: str, mensagem: str, destinatario: str, html: str | None = None) -> None:
    """E-mail enviado fora da requisição (ver TASKS em settings).

    Fora da requisição, nem o tempo do SMTP nem um erro dele aparecem na
    resposta — é o que impede a recuperação de senha de revelar quais e-mails
    estão cadastrados. Convites e contratos também saem por aqui: uma falha
    de SMTP não pode desfazer nem travar a operação de quem enviou.
    """
    send_mail(
        subject=assunto, message=mensagem, from_email=None, recipient_list=[destinatario], html_message=html,
    )
