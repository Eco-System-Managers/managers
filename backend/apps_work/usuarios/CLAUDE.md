# apps_work/usuarios — CLAUDE.md

Quem trabalha no negócio: **colaboradores e convites**.

## Arquivos

| Arquivo | O que faz |
|---|---|
| `models.py` | `Colaborador` (o perfil profissional ligado 1:1 ao `User`) e `ConviteColaborador` |
| `services.py` | Ativar/desativar, remover com checagem de agenda, e o fluxo de convite por e-mail |
| `views.py` | ViewSets de colaborador e convite. Inclui `/me/`, que o frontend usa para saber quem está logado |
| `serializers.py` | Representação |

## Tabelas

### `Colaborador` — o perfil profissional

| Coluna | Tipo | O que é |
|---|---|---|
| `user` | `OneToOne → auth.User` `CASCADE` | O login em si é do Django; este modelo é o lado do domínio |
| `funcao` | `CharField(100)` vazio | Cargo exibido (ex.: "Cabeleireiro") |
| `role` | `CharField(20)` = `colaborador` | `proprietario` ou `colaborador`. É o que `IsProprietario` consulta |
| `ativo` | `Boolean` = `True` | Mantido em sincronia com `User.is_active` pelo `ColaboradorService` |
| `criado_em` | `DateTime` `auto_now_add` | |

### `ConviteColaborador` — o convite pendente

| Coluna | Tipo | O que é |
|---|---|---|
| `nome` | `CharField(150)` vazio | |
| `email` | `EmailField` | Para onde o link é enviado |
| `token` | `UUIDField` único | A credencial do convite. Vive também no `ConviteIndex` do schema público, que mapeia token → schema |
| `aceito` | `Boolean` = `False` | |
| `criado_em` | `DateTime` `auto_now_add` | |
| `expira_em` | `DateTimeField` | |

## Papéis

`Colaborador.role` é `proprietario` ou `colaborador`. É o que a permissão
`IsProprietario` (em `core/permissions.py`) consulta para liberar escrita em
serviços, etapas do kanban, configuração da empresa e billing.

Usuário sem `Colaborador` ainda — durante o onboarding — é tratado como dono da
conta, senão ninguém conseguiria configurar a empresa recém-criada.

## O convite

Fluxo em duas pontas, porque quem aceita ainda não tem acesso ao tenant:

1. O proprietário cria o convite; um `ConviteIndex` no schema público mapeia
   token → schema, para o link funcionar sem o convidado saber de tenant
2. O convidado abre o link, define senha, e `AceitarConviteService` cria o
   `User`, o `UserTenant` e o `Colaborador`

O `ConviteColaboradorViewSet` troca de autenticação e de throttle conforme a
ação — aceitar convite é público por natureza, criar convite não.

## Ativar e desativar

`ColaboradorService` mantém `Colaborador.ativo` e `User.is_active` em sincronia.
São dois campos porque o primeiro é do domínio e o segundo é do Django, mas eles
nunca devem divergir: é o `is_active` que o SimpleJWT consulta para barrar o
token em toda requisição.

Remover verifica antes se há agendamentos pendentes — tirar alguém da equipe não
pode deixar horário órfão.

## O que é fácil errar aqui

- **Desativar pelo serializer também sincroniza.** `perform_update` chama o
  service quando `ativo` muda; alterar o campo por outro caminho quebra o par.
- **A sincronia entre `ativo` e `is_active` é por convenção**, não estrutural.
  Um caminho novo que esqueça de chamar o service cria a divergência.
