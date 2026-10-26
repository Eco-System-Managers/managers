# apps_work/usuarios — CLAUDE.md

Quem trabalha no negócio: **colaboradores e convites**.

Duas coisas que andam separadas: **quem trabalha** (o `Colaborador`, que o dono
cadastra na hora, sem e-mail) e **quem entra no app** (o `User`, que só existe
depois de um convite aceito). O mesmo registro pode começar sem login e ganhar
um depois, pelo `POST colaboradores/{id}/convidar/`.

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
| `user` | `OneToOne → auth.User` `CASCADE`, **nulo** | O login, quando tem. `tem_acesso` no serializer |
| `nome` | `CharField(150)` vazio | O nome exibido (`nome_exibido` cai no `User` quando vazio: registros antigos) |
| `funcao` | `CharField(100)` vazio | Cargo exibido (ex.: "Cabeleireiro") |
| `tipo` | `CharField(20)` = `parceiro` | `parceiro` (agenda e faturamento próprios) ou `colaborador` (executa, não vê valores) |
| `comissao_percentual` | `Decimal(5,2)` nulo | Só parceiro: a parte dele sobre cada pagamento. Congela em `PagamentoAgendamento`/`PagamentoAtendimento` na cobrança |
| `pode_cobrar` | `Boolean` = `True` | Só pesa para o colaborador comum; parceiro e dono cobram sempre |
| `ativo` | `Boolean` = `True` | Mantido em sincronia com `User.is_active` pelo `ColaboradorService` |
| `criado_em` | `DateTime` `auto_now_add` | |

### `ConviteColaborador` — o convite pendente

| Coluna | Tipo | O que é |
|---|---|---|
| `nome` | `CharField(150)` vazio | |
| `email` | `EmailField` | Para onde o link é enviado |
| `token` | `UUIDField` único | A credencial do convite. Vive também no `ConviteIndex` do schema público, que mapeia token → schema |
| `colaborador` | `FK → Colaborador` nulo | Convite para quem já está na equipe sem login: ao aceitar, o `user` entra neste registro |
| `aceito` | `Boolean` = `False` | |
| `criado_em` | `DateTime` `auto_now_add` | |
| `expira_em` | `DateTimeField` | |

O serializer do convite expõe `link` (o mesmo `link_convite(token)` do e-mail):
o dono manda por WhatsApp quando o e-mail não chega. Só o proprietário lista e
cria convites, então o token não vaza; `info`/`aceitar` usam outro serializer.

## Vínculo: parceiro e colaborador

O `tipo` decide o que a pessoa **vê**; o papel do `Membro` decide o que ela
**administra**. `core/permissions.py` concentra a leitura:

| | Proprietário | Parceiro | Colaborador |
|---|---|---|---|
| Caixa e valores do painel | Tudo, com repasse e casa | Só o próprio; `casa` vem nulo | 403 `sem_acesso_a_valores`; painel com valores nulos |
| Cobrar | Sempre | Sempre | Só com `pode_cobrar` (403 `sem_permissao_cobrar`) |
| Equipe | Cadastra, convida, edita | Vê | Vê |

`vinculo_do_usuario`, `ve_valores`, `exigir_ver_valores` e
`exigir_poder_cobrar` são os pontos de entrada. Sem perfil de colaborador, o
usuário é tratado como colaborador comum: o menor acesso.

## Papéis

A fonte do papel é o **`Membro.papel`**, no schema público. É o que a
permissão `IsProprietario` (em `core/permissions.py`) consulta para liberar
escrita em serviços, etapas do kanban, configuração da empresa, billing e na
gestão da equipe.

O `Membro` existe desde o cadastro, então o dono já é dono durante o
onboarding, antes de o `Colaborador` dele ser criado. Sem `Membro` no tenant
atual, a permissão nega — e a `TenantJWTAuthentication` nem deixa a requisição
chegar até ela.

## O convite

Fluxo em duas pontas, porque quem aceita ainda não tem acesso ao tenant:

1. O proprietário cria o convite; um `ConviteIndex` no schema público mapeia
   token → schema, para o link funcionar sem o convidado saber de tenant
2. O convidado abre o link, define senha, e `AceitarConviteService` cria o
   `User` e o `Membro`; cria o `Colaborador` ou, se o convite veio de
   `colaboradores/{id}/convidar/`, liga o `User` ao registro que já existia

O `ConviteColaboradorViewSet` troca de autenticação e de throttle conforme a
ação — aceitar convite é público por natureza, criar convite não. O token é um
UUID: `ConviteService.localizar` recusa qualquer outra coisa com 404
`convite_nao_encontrado` antes de consultar o banco (um token digitado errado
não pode virar 500). O aceite é
**só por token** (`/convites/aceitar/<token>/`): aceitar por `pk` permitia a um
anônimo testar IDs sequenciais. O service trava o convite com
`select_for_update`, para dois aceites simultâneos não criarem o mesmo `User`.

## Ativar e desativar

`ColaboradorService` mantém `Colaborador.ativo` e `User.is_active` em sincronia.
São dois campos porque o primeiro é do domínio e o segundo é do Django, mas eles
nunca devem divergir: é o `is_active` que o SimpleJWT consulta para barrar o
token em toda requisição.

Ativar e desativar são actions do proprietário (`POST /colaboradores/<id>/ativar/`
e `/desativar/`; o `DELETE` também desativa). `ativo` é somente leitura no serializer, e o
`papel` exposto vem do `Membro` (anotado na consulta) — o PATCH comum só altera
a `funcao`.

O proprietário não pode ser desativado nem removido — nem por ele mesmo —, senão
o tenant fica sem ninguém capaz de reativá-lo. O service recusa com
`ValueError`.

Remover verifica antes se há agendamentos pendentes — tirar alguém da equipe não
pode deixar horário órfão.

## O que é fácil errar aqui

- **`user` pode ser nulo.** Nome, papel, `is_active` e sessões só existem
  para quem tem login; o `ColaboradorService` tolera o nulo, e código novo
  também precisa (`nome_exibido`, nunca `colaborador.user.get_full_name()`).
- **`ativo` não muda pelo serializer.** Só pelas actions, que chamam o
  service; alterar o campo por outro caminho quebra o par com `is_active`.
- **A sincronia entre `ativo` e `is_active` é por convenção**, não estrutural.
  Um caminho novo que esqueça de chamar o service cria a divergência.
