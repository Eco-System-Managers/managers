# apps_work/empresa — CLAUDE.md

A **configuração do negócio**: identidade, nichos, endereço, logo e horários.

É o app que define como o produto se comporta para aquele tenant — inclusive
qual dos dois modos de agenda ele usa.

## Arquivos

| Arquivo | O que faz |
|---|---|
| `models.py` | `EmpresaConfig` (linha única por tenant) e `HorarioFuncionamento` (uma por dia da semana) |
| `services.py` | `ModoAgendaService` (nichos → modo de agenda e objeto, e as regras de quantos e quais nichos), `GeocodificacaoService` (endereço ↔ coordenada, via Nominatim) e `ArmazenamentoImagemService` (upload, conversão e URL das imagens no S3) |
| `serializers.py` | Validação; o modo de agenda ele pede ao `ModoAgendaService` |
| `validators.py` | CPF e CNPJ com dígitos verificadores |
| `views.py` | Config, upload de logo, horários e as duas views de geocodificação |
| `signals.py` | Declara `empresa_config_atualizada`, que a vitrine escuta para republicar o negócio |

## Tabelas

### `EmpresaConfig` — linha única por tenant

Quase todo campo é `blank=True`: a linha nasce no primeiro GET
(`ConfiguracaoEmpresaService.obter_ou_criar`) só com o `nome` dado no cadastro,
copiado do `Tenant`, e vai sendo preenchida pelo onboarding. Quem exige os
campos é o serializer, ao concluir — não o banco.

| Coluna | Tipo | O que é |
|---|---|---|
| `nome` | `CharField(255)` vazio | Nome do negócio, exibido na vitrine |
| `telefone` | `CharField(20)` vazio | |
| `documento` | `CharField(14)` vazio | **Só os dígitos.** A máscara fica na interface |
| `tipo_documento` | `CharField(4)` vazio | `cpf` ou `cnpj` |
| `nichos` | `ArrayField(CharField(50))` = `[]` | Slugs, de 1 a 4, da mesma área, na ordem do enum `Nicho` (a de exibição). Sem nicho principal. Vazio só antes de o onboarding escolher. Nos nichos conhecidos, definem `tipo_agenda` e `tipo_objeto`; `["outro"]` (sempre sozinho) deixa o dono escolher |
| `nicho_descricao` | `CharField(60)` vazio | O ramo por extenso. Obrigatório no `outro`, vazio nos demais |
| `latitude` | `Decimal(9,6)` nulo | Sem ela o negócio não entra na vitrine |
| `longitude` | `Decimal(9,6)` nulo | Idem |
| `logo_url` | `URLField` vazio | Pública no S3 |
| `cidade` · `endereco` | `CharField` vazios | |
| `numero` | `CharField(20)` vazio | Número do endereço. `endereco_completo` junta os dois para a geocodificação |
| `cep` | `CharField(8)` vazio | Só dígitos |
| `uf` | `CharField(2)` vazio | Alimenta a geocodificação — sem UF, "cidade + Brasil" precisa desambiguar sozinha, e existe mais de uma Araras no país |
| `localizacao_confirmada` | `Boolean` = `False` | `True` quando o dono apontou o pino no mapa. A partir daí o geocodificador **não sobrescreve mais** |
| `tipo_agenda` | `CharField(10)` = `horario` | `horario` ou `kanban`. Define qual dos dois modos o negócio usa |
| `tipo_objeto` | `CharField(10)` vazio | `veiculo` ou `pet` no kanban — o card do quadro é sempre um objeto. Vazio no horário. A vitrine publica daqui |
| `onboarding_concluido` | `Boolean` = `False` | Enquanto `False`, o frontend manda o usuário para o wizard |
| `atualizado_em` | `DateTime` `auto_now` | |

### `HorarioFuncionamento` — uma linha por dia

| Coluna | Tipo | O que é |
|---|---|---|
| `dia` | `IntegerField` **único** | **0 = Segunda … 6 = Domingo.** Não é a numeração do `getDay()` do JavaScript, que começa no domingo — os frontends convertem |
| `abertura` | `TimeField` nulo | |
| `fechamento` | `TimeField` nulo | |
| `ativo` | `Boolean` = `True` | Dia fechado é `ativo=False`, a linha continua existindo |
| `capacidade` | `PositiveInteger` nulo | O máximo de atendimentos no dia da esteira (com ou sem hora); nulo é sem máximo. `AjusteDoDia` (kanban) substitui numa data só |
| `vagas` | `PositiveInteger` = 1 | Quantos atendimentos da esteira andam ao mesmo tempo |

Ordenação por `dia`. O `unique` no dia é o que garante no máximo sete linhas.

## `EmpresaConfig` decide o comportamento do produto

| Campo | Consequência |
|---|---|
| `nichos` | Definem o modo (`ModoAgendaService`). Lava-rápido vira `kanban` com veículo; banho & tosa, `kanban` com pet; os demais nichos da lista, `horario`. Em `outro`, o dono descreve o ramo e escolhe o modo — no kanban, também se recebe veículo ou pet |
| `latitude` / `longitude` | Sem elas o negócio **não aparece** na vitrine |
| `onboarding_concluido` | Enquanto `False`, o frontend manda o usuário para o wizard |
| `logo_url` | Pública no S3; aparece no mapa e no agendamento do cliente |

Publicar na vitrine exige onboarding concluído, nome, ao menos um nicho e coordenadas — a
regra está em `SincronizarVitrineService._pode_publicar`, do lado do `apps_serv`.

## O modo de agenda trava no onboarding

Antes de concluir o onboarding, trocar de nichos troca o modo à vontade. Depois,
qualquer troca que mude `tipo_agenda` ou `tipo_objeto` é recusada
(`modo_agenda_bloqueado`): agenda e quadro guardam dados que não se convertem
de um para o outro. Trocar para um nicho do mesmo modo continua livre.

## Vários nichos: a área é o modo

O negócio atende **de 1 a 4 nichos da mesma área**. Área não é cadastro nem
tabela: é o modo completo que o nicho decide — horário (beleza e bem-estar),
kanban com veículo (automotivo) ou kanban com pet. Lava-rápido e banho e tosa
são áreas diferentes, porque o card do quadro é um veículo ou um pet. `outro`
não se combina com nada. As regras e os codes (`nichos_limite`,
`nichos_areas_diferentes`, `nicho_outro_exclusivo`; lista vazia é
`nichos_obrigatorios`, no serializer) estão no `ModoAgendaService`.

Cada serviço fica num dos nichos (`Servico.nicho`, a "pasta"). **Tirar um nicho
inativa os serviços dele** na mesma transação do salvamento
(`ConfiguracaoEmpresaService.inativar_servicos_de_nichos_removidos`, chamado
pela view): inativa e não apaga, porque os agendamentos guardam o serviço com
`PROTECT`. Recolocar o nicho não os reativa.

## Imagens

`ArmazenamentoImagemService` valida, normaliza para webp e grava no S3. Há dois
destinos com políticas diferentes:

- **logo do negócio** — pública, URL sem assinatura
- **foto de pessoa** — privada, URL assinada com validade de uma hora

A configuração dos dois está em `core/settings.py` (`STORAGES`), com os detalhes
de SigV4 documentados lá.

## O que é fácil errar aqui

- **Efeitos de salvar a configuração ficam em `ConfiguracaoEmpresaService`**
  (geocodificar, publicar na vitrine, criar o colaborador do dono e as etapas do
  kanban ao concluir o onboarding; e a troca da logo). Nenhum deles pode
  desfazer o salvamento: cada um roda em savepoint próprio e a falha vai para o
  log (`_sem_derrubar`) — antes eram `except Exception: pass` na view.

- **Salvar a config dispara republicação na vitrine.** É o sinal
  `empresa_config_atualizada`. Mudar por `.update()` no queryset pula o sinal e
  o negócio fica desatualizado no mapa.
- **Geocodificação depende de serviço externo** (Nominatim) e pode falhar ou
  devolver a rua com grafia diferente. Por isso a comparação de rua no frontend
  é aviso, nunca bloqueio.
- **`EmpresaConfig` é linha única** — `get_object` busca `pk=1`. Não existe
  listagem.
- **Escrita só do proprietário**, leitura liberada. `/api/v1/empresa/config/` é
  isento do bloqueio por assinatura, senão tenant bloqueado não conseguiria nem
  carregar a tela que resolve a pendência.
