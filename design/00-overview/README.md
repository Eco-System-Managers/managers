# Work Manage · Service Manage

Uma marca, dois produtos. **Work Manage** (símbolo W) e **Service Manage** (símbolo S) dividem a mesma paleta, a mesma wordmark em MuseoModerno e a mesma construção geométrica: traços inclinados em azul-marinho e uma peça menor em azul. Tudo flat — sem gradiente, sem sombra, sem contorno.

## Essência

**Agenda cheia, negócio leve.** A Work Manage é o app de gestão e agendamento para negócios de serviço: barbearias, salões, clínicas, lava-rápidos e pet shops. A Service Manage leva a mesma lógica para o lado de quem agenda: o cliente encontra esses negócios perto dele e marca um horário livre pelo app. Nos símbolos, os traços inclinados são a rotina que segue; a peça azul (a gota do W, o triângulo do S) é o cliente que chega para o próximo horário.

## Dois produtos

| Produto | Verbo | Para quem |
|---|---|---|
| **Work Manage** (o W) | Organizar | Agenda, equipe, clientes e faturamento em um só lugar. O dono sabe o que acontece no negócio a qualquer hora. |
| **Service Manage** (o S) | Agendar | Encontre barbearias, salões, lava-rápidos e pet shops perto de você e marque um horário em poucos toques. Uma conta só para todos os negócios, com a sua agenda, os seus pets e os seus veículos. |

## Tom de voz

Profissional e acolhedor: falamos como um bom gerente de recepção. **Claro** (frases curtas, uma informação por vez; data, hora e nome sempre visíveis), **acolhedor** (tratamos por “você”, sem exagero de exclamações), **profissional** (linguagem de negócio, sem gírias nem jargão de software) e **prático** (toda mensagem diz o que aconteceu e o que fazer em seguida). Assim: “Horário confirmado: Ana, sexta às 14h. Enviamos um lembrete 1 hora antes.” Não assim: “Agendamento efetuado com sucesso!!! Obrigado por utilizar nossa plataforma.”

## Princípios

1. **Mesma família, dois nomes.** Os dois símbolos têm exatamente a mesma altura e a mesma linguagem (traço inclinado + peça azul). Lado a lado, parecem irmãos; sozinhos, cada um identifica o seu produto.
2. **Duas cores, uma pequena.** `navy` carrega a forma; `blue` marca uma única peça. Nunca inverta a proporção nem pinte o símbolo inteiro de azul fora da versão 1 cor.
3. **Geometria, não desenho.** Vieram de um vetor único (`Logotipos-geométricos-em-azul-e-marinho.svg`), separados e coloridos sem alterar nenhum ponto. Para mudar o desenho, mude o vetor de origem e gere de novo.
4. **Voz direta.** Texto curto, verbo na frente, sem jargão. A marca promete agendamento e gestão sem complicação, e a interface precisa parecer isso.

## Logos

Arquivos em `assets/Logos/`, todos SVG com a wordmark já convertida em curvas (não dependem da fonte instalada).

| Uso | Work Manage | Service Manage |
|---|---|---|
| Logo horizontal, colorido | `w-logo.svg` | `s-logo.svg` |
| Logo empilhado, colorido | `w-logo-stacked.svg` | `s-logo-stacked.svg` |
| Símbolo sozinho, colorido | `w-mark.svg` | `s-mark.svg` |
| 1 cor: navy / branco / azul | `*-navy.svg`, `*-white.svg`, `*-blue.svg` | idem |

**Construção.** Os dois símbolos ocupam uma caixa de 120 de altura com 10 de margem: altura útil 100. O S foi reduzido para 81,5 % do tamanho original para ficar com a mesma altura do W; as proporções internas não mudaram. No logo horizontal, a wordmark tem altura de capitais igual a 80 % da altura do símbolo, centrada verticalmente, com vão de 32 % da altura entre símbolo e texto. No empilhado, a wordmark mede 1,7× a altura do símbolo e fica centrada abaixo dele.

**Wordmark.** MuseoModerno 600, `letter-spacing: -0.01em`, em `ink` (ou `on-brand` sobre fundos escuros). Só o nome do produto, com inicial maiúscula nas duas palavras. Nunca reescreva a wordmark com outra fonte; use os SVGs.

### Regras de uso

- **Área de respiro:** no mínimo 1/4 da altura do símbolo em todos os lados (a 96 px, `space-5`).
- **Tamanho mínimo:** logo horizontal 24 px de altura; símbolo sozinho 16 px; impressão 8 mm. Abaixo disso, só o símbolo.
- **Fundos:** colorido sobre `bg` ou `bg-2`. Sobre `navy`, `blue` ou foto: `*-white.svg`. Sobre fundos claros fora da paleta: `*-navy.svg`. `*-blue.svg` é para peças onde só o azul está disponível (carimbo, bordado).
- **Ícone do app:** `w-mark-white.svg` ou `s-mark-white.svg` centralizado num quadrado `navy` com `radius-icon`, ocupando 68 % da largura. Variante clara: símbolo colorido sobre `bg` com borda `border`.
- **Não faça:** rotacionar, espelhar, esticar, mudar o ângulo, trocar qual peça é azul, aplicar gradiente, sombra ou contorno, colocar a wordmark acima do símbolo, separar as cores de forma diferente da original.

## Cores

| Token | Claro | Escuro | Para quê |
|---|---|---|---|
| `navy` | #0B1C35 | #0B1C35 | Marca: símbolos, wordmark, fundo de ícone |
| `blue` | #1B6AF3 | #5A93FF | Marca: peça azul, botão primário, link |
| `blue-soft` | #E8F0FE | #15284D | Fundo de destaque ligado ao azul |
| `bg` / `bg-2` | #FFFFFF / #F3F6FD | #0B1C35 / #13254A | Fundos |
| `ink` / `ink-muted` | #0B1C35 / #5A6A84 | #F2F6FC / #9FB2CC | Texto |
| `success` / `warning` / `danger` | #1A7F4B / #9A5A00 / #B3261E | #4FC47F / #F0B14A / #FF7B72 | Só status |

Regra: as cores da marca são `navy` e `blue`; o resto é interface. Texto sempre com 4.5:1 sobre o fundo (todas as combinações acima passam nos dois temas; `blue` sobre branco dá 4.8:1, então botões azuis levam texto branco, não o contrário em tamanho pequeno).

## Tipografia

- **MuseoModerno** (Google Fonts, variável 100–900, arquivo em `fonts/`): a wordmark (600) e títulos de capa (`display`, 700). Nunca em texto corrido.
- **Inter** (Google Fonts): títulos e texto da interface. `h1` 700, `h2`/`h3` 600, `body` 400, `label` 500. Carregue por `https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=MuseoModerno:wght@600;700&display=swap`.

## Espaço, raio e sombra

Escala de 4 px (`space-1` 4 → `space-7` 64). Raios: `radius-sm` 6 (campos), `radius-md` 12 (botões, cartões), `radius-lg` 20 (painéis), `radius-icon` 22 % (ícone do app). Uma sombra só, `shadow-card`, para o que flutua; o resto usa `border`.

## Iconografia

Ícones de linha, 1.5 px a 20 px (2 px a 24 px), cantos arredondados, cor `ink` ou `ink-muted`; `blue` só no ícone ativo. O símbolo da marca nunca vira ícone de interface.
