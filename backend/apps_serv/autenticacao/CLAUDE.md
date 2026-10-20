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

**Não tem `models.py`.** O `Consumidor`, o código de recuperação e o
`RefreshRevogadoConsumidor` moram em `consumidores/models.py` — este app cuida
do *fluxo*, não do dado.

## Tabelas

**Nenhuma.** Este app cuida do *fluxo* de entrada, não do dado. O `Consumidor` e
o `CodigoRecuperacaoConsumidor` estão documentados em
[`../consumidores/CLAUDE.md`](../consumidores/CLAUDE.md).

## Como o token funciona

Dois tokens, distinguidos por um campo `type`, assinados com a chave própria
do Service Manage (`SERVICEMANAGE_JWT['SIGNING_KEY']`, derivada da `SECRET_KEY`
ou definida em `JWT_SIGNING_KEY_B2C`) e com `aud`/`iss` `servicemanage`:

- `consumidor_access` — 60 minutos, vai no header `Authorization: Bearer`
- `consumidor_refresh` — 7 dias, trocado por um par novo

Chave, emissor e audiência diferentes são o que impede um token do B2B de
abrir porta no B2C e vice-versa. Todo token tem `jti`.

**Revogação.** Não dá para usar o blacklist do SimpleJWT aqui (ele é amarrado
ao `auth.User`), então o app tem a sua:

- cada refresh vale uma vez: `renovar_tokens` grava o `jti` usado em
  `RefreshRevogadoConsumidor` e emite um par novo. O `unique` do `jti` impede
  que duas renovações simultâneas do mesmo refresh passem
- logout grava o `jti` do refresh como revogado
- a troca de senha preenche `Consumidor.sessoes_validas_desde`; todo token com
  `iat` anterior é recusado, inclusive access

O refresh vai **ou** no cookie httpOnly (web) **ou** no corpo (mobile), nunca
nos dois. O app mobile se identifica com `X-Client-Platform: mobile` e manda o
refresh no corpo; sem o cabeçalho, o refresh só é lido do cookie
(`core/sessao.py`).

## Rate limiting

Escopos próprios, com prefixo `sm_` (`sm_auth_login`, `sm_auth_recovery`…):
o B2C não divide contador com o B2B. Como lá, o login conta falhas por e-mail
(`login_servicemanage` em `core/limites.py`, 10 em 15 min, zerado no acerto) e a
recuperação limita códigos por e-mail (`RecuperacaoConsumidorPorEmailThrottle`,
5/hora). O throttle padrão de usuário logado (`UsuarioRateThrottle`) leva o tipo
da conta na chave, para o `Consumidor` 5 não dividir contador com o `User` 5.

## O que é fácil errar aqui

- **`request.user` aqui é um `Consumidor`, não um `User`.** Ele implementa
  `is_authenticated` só para o `IsAuthenticated` do DRF funcionar. Qualquer
  permissão que acesse `.colaborador`, `.is_staff` ou similar quebra.
- **`authenticate_header` não é decorativo.** Sem ele o DRF responde 403 no
  lugar de 401 para requisição sem token, e o app não sabe que precisa renovar.
- **Rotas deste app estão isentas do controle de inatividade** (ver
  `core/middleware.py`) — senão renovar a sessão exigiria uma sessão válida.
