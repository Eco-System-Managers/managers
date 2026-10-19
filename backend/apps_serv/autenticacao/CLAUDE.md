# apps_serv/autenticacao — CLAUDE.md

Login e sessão do **cliente final** (app Service Manage).

Existe separado do `apps_work/autenticacao` porque são duas identidades
diferentes: lá o usuário é um `User` do Django dentro de um tenant; aqui é um
`Consumidor` no schema público, que não pertence a negócio nenhum.

## Arquivos

| Arquivo | O que faz |
|---|---|
| `authentication.py` | O coração. Gera e valida o JWT do consumidor, com PyJWT direto — não usa SimpleJWT. `ConsumidorJWTAuthentication` é a classe que o DRF chama para popular `request.user` com um `Consumidor` |
| `views.py` | Os sete endpoints do fluxo de conta: cadastro, login, refresh, logout e as três etapas de recuperação de senha. Views finas — a regra está em `consumidores/services.py` |
| `urls.py` | Rotas sob `/api/sm/auth/` |
| `apps.py` | Registro do app. Sem sinais |

**Não tem `models.py`.** O `Consumidor` e o código de recuperação moram em
`consumidores/models.py` — este app cuida do *fluxo*, não do dado.

## Tabelas

**Nenhuma.** Este app cuida do *fluxo* de entrada, não do dado. O `Consumidor` e
o `CodigoRecuperacaoConsumidor` estão documentados em
[`../consumidores/CLAUDE.md`](../consumidores/CLAUDE.md).

## Como o token funciona

Dois tokens, ambos assinados com a mesma `SECRET_KEY` do projeto, distinguidos
por um campo `type`:

- `consumidor_access` — 60 minutos, vai no header `Authorization: Bearer`
- `consumidor_refresh` — 7 dias, trocado por um access novo

O `type` é o que impede um token do B2B de abrir porta no B2C e vice-versa,
já que a chave de assinatura é a mesma.

O refresh sai **tanto em cookie httpOnly quanto no corpo da resposta**: o
navegador usa o cookie, e o app mobile usa o corpo, porque não gerencia cookie
como um browser.

## O que é fácil errar aqui

- **`request.user` aqui é um `Consumidor`, não um `User`.** Ele implementa
  `is_authenticated` só para o `IsAuthenticated` do DRF funcionar. Qualquer
  permissão que acesse `.colaborador`, `.is_staff` ou similar quebra.
- **`authenticate_header` não é decorativo.** Sem ele o DRF responde 403 no
  lugar de 401 para requisição sem token, e o app não sabe que precisa renovar.
- **Rotas deste app estão isentas do controle de inatividade** (ver
  `core/middleware.py`) — senão renovar a sessão exigiria uma sessão válida.
