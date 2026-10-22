# Contrato da API

Dois produtos, dois schemas OpenAPI, dois clients:

| Produto | Prefixo | Schema | Swagger UI (só com `DEBUG=True`) |
|---|---|---|---|
| Work Manage (painel do negócio, B2B) | `/api/v1/` | [`workmanage.yaml`](workmanage.yaml) | `/api/v1/schema/docs/` |
| Service Manage (app do cliente, B2C) | `/api/sm/v1/` | [`servicemanage.yaml`](servicemanage.yaml) | `/api/sm/v1/schema/docs/` |

Os arquivos são gerados a partir do código: **não edite à mão.** Depois de mudar
uma view ou um serializer, rode no `backend/`:

```
.venv/bin/python manage.py gerar_openapi
```

e versione os `.yaml`. O teste `tests/test_openapi.py` falha se eles estiverem
desatualizados — é deles que o front gera os clients Dart.

## Autenticação

- `Authorization: Bearer <access>` em toda rota autenticada.
- Login, cadastro (o direto e o `/cadastro/confirmar/`) e renovação devolvem a sessão. O **web** recebe o refresh só
  no cookie httpOnly. O **app mobile** manda `X-Client-Platform: mobile` e
  recebe/envia o refresh no corpo (`refresh`).
- Cada refresh vale uma vez: a renovação devolve um novo e revoga o anterior.

## Paginação

Toda coleção de recurso vem paginada:

```json
{"count": 42, "next": "http://.../?page=2", "previous": null, "results": [...]}
```

`?page=` escolhe a página e `?page_size=` o tamanho (padrão 20, máximo 100).
Telas que precisam do conjunto inteiro (a agenda e o kanban do dia) pedem
`page_size=100` e **seguem o `next`** se ele vier.

Listas calculadas ou de tamanho fixo (slots, horários da semana, cidades,
nichos, dias com registro) são arrays simples — o schema diz qual é qual.

## Erros

Todo 4xx/5xx gerado pela API tem o mesmo corpo (schema `Erro`):

```json
{"detail": "Este e-mail já está vinculado a uma conta.", "code": "email_ja_cadastrado"}
{"detail": "Dados inválidos.", "code": "invalido", "fields": {"email": ["Informe um endereço de email válido."]}}
```

- `detail`: mensagem pronta para mostrar ao usuário.
- `code`: identificador estável. Decida o fluxo pelo `code`, nunca pelo texto.
- `fields`: só em erro de validação, `{campo: [mensagens]}`.

Códigos genéricos por status: `invalido` (400), `nao_autenticado` (401),
`pagamento_necessario` (402), `sem_permissao` (403), `nao_encontrado` (404),
`muitas_requisicoes` (429). Os de regra de negócio são específicos
(`proprietario_protegido`, `convite_expirado`, `muitas_tentativas`,
`assinatura_bloqueada`, `inactivity_timeout`…).

## Formatos

- **Dinheiro:** string com duas casas, `"45.50"`. Converta para um tipo decimal
  no app; nunca para `double`.
- **Data:** `"2026-10-19"`. **Data e hora:** ISO 8601 com fuso,
  `"2026-10-19T10:30:00-03:00"`. **Hora:** `"10:30"` ou `"10:30:00"`, conforme o
  campo no schema.
- **Ids:** inteiros. As rotas públicas usam `schema_name` + token (UUID), nunca
  id sequencial.
