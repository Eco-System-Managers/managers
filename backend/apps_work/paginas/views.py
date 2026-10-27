"""Páginas que a pessoa abre no navegador, fora do app.

Três links saem por e-mail ou redirect e, sem deep link no app, não teriam
onde abrir: o convite da equipe, o contrato do cliente e a volta do checkout.
As regras são as mesmas da API — estas views só recebem, delegam aos services
e mostram o resultado.
"""
from django.shortcuts import redirect, render
from django.views import View
from django_tenants.utils import schema_context
from rest_framework.throttling import BaseThrottle

from apps_work.contratos.models import StatusContrato
from apps_work.contratos.serializers import AssinarContratoSerializer, ContratoPublicoSerializer
from apps_work.contratos.services import ContratoService, contrato_publico
from apps_work.usuarios.services import AceitarConviteService, ConviteService
from core.excecoes import ErroDeNegocio


def _erro(request, mensagem: str, status: int):
    return render(request, 'paginas/erro.html', {'mensagem': mensagem}, status=status)


class ConviteView(View):
    def get(self, request, token):
        return self._formulario(request, token)

    def post(self, request, token):
        senha = request.POST.get('senha', '')
        if senha != request.POST.get('confirmacao', ''):
            return self._formulario(request, token, erro='As senhas não conferem.')
        try:
            email = ConviteService().info(token)['email']
            # O aceite devolve uma sessão, que aqui fica sem uso: quem entra
            # depois é o app, com o e-mail e a senha recém-criada.
            AceitarConviteService().aceitar(token, senha)
        except ErroDeNegocio as e:
            return self._formulario(request, token, erro=e.detail)
        return render(request, 'paginas/convite_aceito.html', {'email': email})

    def _formulario(self, request, token, erro: str = ''):
        try:
            dados = ConviteService().info(token)
            tenant, _ = ConviteService().localizar(token)
        except ErroDeNegocio as e:
            return _erro(request, e.detail, e.status_code)
        contexto = {**dados, 'empresa': tenant.nome, 'erro': erro}
        return render(request, 'paginas/convite.html', contexto, status=400 if erro else 200)


class ContratoView(View):
    def get(self, request, schema_name, token):
        return self._pagina(request, schema_name, token)

    def post(self, request, schema_name, token):
        contrato = contrato_publico(schema_name, token)
        if contrato is None:
            return _erro(request, 'Contrato não encontrado.', 404)

        acao = request.POST.get('acao')
        service = ContratoService()
        with schema_context(schema_name):
            try:
                if acao == 'assinar':
                    serializer = AssinarContratoSerializer(data=request.POST)
                    if not serializer.is_valid():
                        return self._pagina(request, schema_name, token, erro='Digite seu nome completo para assinar.')
                    # Mesma identificação da API pública (NUM_PROXIES): o
                    # X-Forwarded-For cru forjaria o IP registrado.
                    service.assinar(
                        contrato,
                        nome_assinante=serializer.validated_data['nome_assinante'],
                        ip=BaseThrottle().get_ident(request),
                    )
                elif acao == 'recusar':
                    service.recusar(contrato)
                else:
                    return _erro(request, 'Ação inválida.', 400)
            except ErroDeNegocio as e:
                return self._pagina(request, schema_name, token, erro=e.detail)

        # De volta ao GET: recarregar a página não reenvia o formulário.
        return redirect(request.path)

    def _pagina(self, request, schema_name, token, erro: str = ''):
        contrato = contrato_publico(schema_name, token)
        if contrato is None:
            return _erro(request, 'Contrato não encontrado.', 404)
        with schema_context(schema_name):
            dados = ContratoPublicoSerializer(contrato).data
        contexto = {
            **dados,
            'contrato': contrato,
            'aberto': contrato.status in (StatusContrato.PENDENTE, StatusContrato.ENVIADO),
            'erro': erro,
        }
        return render(request, 'paginas/contrato.html', contexto, status=400 if erro else 200)


class RetornoPagamentoView(View):
    """Onde o checkout do Mercado Pago devolve a pessoa (via billing/retorno/).

    Quem libera o acesso é o webhook; a página só orienta a voltar ao app e
    mostra o id da assinatura, que o app aceita para vincular à mão se o
    webhook não achar o negócio pelo e-mail de quem pagou.
    """

    def get(self, request):
        return render(request, 'paginas/pagamento.html', {'preapproval_id': request.GET.get('preapproval_id', '')})
