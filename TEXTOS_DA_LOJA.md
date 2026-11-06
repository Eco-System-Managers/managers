# Textos da loja — Work Manage (iPhone)

O que colar no App Store Connect: primeiro no TestFlight (revisão do beta) e
depois na versão da App Store, que reaproveita a conta do revisor, as notas e
o build testado. O roteiro dos passos está no `LANCAMENTO.md`.

**Usuário e senha da conta do revisor não ficam aqui** (o arquivo vai para o
git): só no App Store Connect e num gerenciador de senhas.

O app é só para iPhone (`TARGETED_DEVICE_FAMILY = 1`): a loja não pede
capturas de iPad, e o iPad instala no modo de compatibilidade.

---

## 1. TestFlight › Informações de teste

**Descrição do beta** (até 4.000 caracteres)

> O Work Manage é o app de gestão para negócios de atendimento: agenda ou
> quadro de atendimentos, clientes, serviços, cobrança e caixa, num lugar só.
>
> Esta é a versão de testes. Use no dia a dia do seu negócio e conte o que
> travou, o que ficou confuso e o que faltou.

**E-mail para feedback:** `contato@workmanage.com.br`

**URL de marketing:** deixar vazio.

**URL da política de privacidade:** `https://api.workmanage.com.br/privacidade`

### Informações para a revisão do beta

- **Contato:** Wilson Júnior · `contato@workmanage.com.br` · telefone com DDI
  (`+55 ...`).
- **Login obrigatório:** marcado, com o usuário e a senha da conta do revisor.
- **Notas** (em inglês, que é o que o revisor lê sempre):

> Work Manage is a management app for service businesses (barbershops,
> beauty salons, car washes, pet shops): appointments or a work board,
> clients, services, payments and the cash register.
>
> The app is in Brazilian Portuguese; screen names are quoted below as
> they appear.
>
> Please sign in with the account provided. It is the owner of a sample
> business already filled with services, clients and appointments, so every
> screen has content.
>
> Subscriptions: every new business starts with a 28-day free trial, with no
> purchase needed. The auto-renewable subscriptions (Pro, Business and
> Enterprise; monthly, six-month and annual) are in "Mais › Assinatura". The
> review account is in its free trial, so the plans are shown there and can
> be purchased in the sandbox. The same screen has "Restaurar compras"
> (restore purchases) and the links to the Terms of Use and the Privacy
> Policy.
>
> Account deletion is available in the app under "Mais › Excluir conta". To
> test it, please create a new account through "Criar conta" on the login
> screen (a confirmation code is sent by email), so the review account stays
> available.
>
> The camera and photo library are only used when the owner chooses the
> business logo ("Mais › Configurações › Dados do negócio").

Copiar daqui pelo terminal enche as linhas de espaços e estoura o limite do
campo: copie do arquivo, ou peça ao Claude para pôr na área de transferência
(`pbcopy`).

---

## 2. Grupo externo "Testadores" › O que testar

A cada build novo, este texto vai no build (até 4.000 caracteres).

> Obrigado por testar o Work Manage!
>
> O que testar:
> - Criar a conta, confirmar o código do e-mail e configurar o negócio
>   (dados, nichos e horários).
> - Cadastrar serviços e clientes.
> - Marcar, remarcar, confirmar e cancelar atendimentos.
> - Cobrar um atendimento e conferir o caixa.
> - Convidar alguém da equipe.
>
> Achou um problema? Mande um print e conte o que fez antes. No TestFlight,
> basta tirar o print com o app aberto para enviar direto para nós.

---

## 3. App Store › versão 1.0.0 (o lançamento)

Enviada para a revisão em 2026-11-05 (build `1.0.0+4`), junto com o grupo de
assinaturas e os 9 planos, com **"Liberar esta versão manualmente"** marcado.

A primeira assinatura só vai com uma versão nova, e o App Store Connect não
tem mais a seção de compras na página da versão: o **Add for Review** da
versão cria o rascunho, e o de cada plano e o do grupo os põem nele. Os dois
reclamam ("must be submitted with its subscription group" / "with an
auto-renewable subscription from within that group"), mas entram no rascunho
mesmo assim: é só adicionar todos e conferir em **App Review**.

### Informações do app

- **Nome** (até 30): o que já está registrado no App Store Connect.
- **Subtítulo** (até 30): `Agenda, clientes e caixa`
- **Categoria principal:** Negócios. **Secundária:** Produtividade.
- **Copyright:** `2026 Wilson Geraldo Donizeti Pereira Júnior`
- **Classificação etária:** "Nenhum" em todas as perguntas (sem conteúdo
  sensível, sem chat entre usuários, sem navegador aberto): 4+.
- **Direitos de conteúdo:** mostra conteúdo de terceiros (o mapa do
  OpenStreetMap), com os direitos necessários.

### Texto promocional (até 170; muda sem nova revisão)

> Agenda, clientes, cobrança e caixa do seu negócio de atendimento, direto
> no celular.

### Descrição (até 4.000)

A Apple exige, em app com assinatura, os links dos termos de uso e da
privacidade na descrição (o fim do texto). Pagamento fora do app não se cita.

> O Work Manage organiza o dia a dia do seu negócio de atendimento, do
> horário marcado ao dinheiro no caixa.
>
> AGENDA OU QUADRO, DO SEU JEITO
> Barbearias, salões e estéticas trabalham com horário marcado: a agenda
> mostra o dia em grade, com os atendimentos de cada profissional, e marca
> só nos horários livres. Lava-jatos e pet shops trabalham por chegada: o
> quadro mostra cada veículo ou pet passando pelas etapas, de recebido a
> pronto, com quanto ainda cabe no dia.
>
> CLIENTES
> A ficha de cada cliente com contato, endereço pelo CEP, veículos ou pets,
> o histórico de atendimentos, o saldo e os contratos.
>
> SERVIÇOS
> O catálogo com preço e duração, organizado pelos nichos do negócio.
>
> COBRANÇA E CAIXA
> Cobre com várias formas de pagamento, desconto, acréscimo e troco. O caixa
> mostra o recebido no período, as formas de pagamento e a parte de cada
> profissional parceiro.
>
> EQUIPE
> Convide a equipe para o app. Cada pessoa vê o que o papel dela permite.
>
> CONTRATOS
> Modelos com os dados do cliente preenchidos sozinhos, em PDF, para mandar
> pelo WhatsApp ou e-mail.
>
> AVISOS PELO WHATSAPP
> Avise o cliente do próximo horário ou de uma remarcação com um toque.
>
> ASSINATURA
> Comece com 28 dias grátis. Depois, escolha o plano Pro, Business ou
> Enterprise, com renovação automática pela App Store.
>
> Termos de uso: https://api.workmanage.com.br/termos
> Política de privacidade: https://api.workmanage.com.br/privacidade

### Palavras-chave (até 100, separadas por vírgula, sem espaço)

```
agenda,agendamento,barbearia,salão,estética,lava-jato,petshop,clientes,caixa,comissão,serviços
```

### URLs

- **Suporte (obrigatória):** `https://api.workmanage.com.br/suporte`
- **Marketing:** opcional.
- **Política de privacidade:** `https://api.workmanage.com.br/privacidade`

### Informações da revisão do app

As mesmas do beta: contato, login obrigatório com a conta do revisor e as
notas da seção 1. A conta precisa continuar valendo, com a senha sem trocar,
e o negócio dela fica em **Trial até 31/12/2027** no admin, **não
vitalício**: o vitalício esconde os planos, e o revisor precisa comprar um.

### Capturas de tela

De 3 a 10, sem cliente de verdade (a página é pública). O espaço obrigatório
é o **"iPhone with Dynamic Island"**, de tamanho médio: **1206 × 2622** (ou
1179 × 2556); o grande (1320 × 2868, 1290 × 2796) é opcional. Os da 1.0 são
prints do iPhone, mandados por AirDrop (o WhatsApp reduz a imagem) e
convertidos com o `sips` (aumentar pela altura e cortar a sobra da largura),
nesta ordem: o Início, a agenda do dia com um atendimento, a ficha do
cliente, a cobrança e o financeiro.

### Preço e disponibilidade

Preço de download **Grátis**, só no Brasil. Os planos são assinaturas
dentro do app, compradas pela App Store (o grupo "Work Manage", com os 9
planos).

### Privacidade do app

**Rastreamento:** não (nada é cruzado com dados de outras empresas para
publicidade). Todos os dados abaixo são **vinculados ao usuário**.

| Tipo de dado | Para quê |
|---|---|
| Informações de contato › Nome | Funcionalidade do app |
| Informações de contato › Endereço de e-mail | Funcionalidade do app |
| Informações de contato › Número de telefone | Funcionalidade do app |
| Informações de contato › Endereço físico | Funcionalidade do app |
| Informações financeiras › Outras informações financeiras (pagamentos e caixa) | Funcionalidade do app |
| Compras › Histórico de compras (a assinatura) | Funcionalidade do app |
| Fotos ou vídeos (a logo) | Funcionalidade do app |
| Identificadores › ID do usuário | Funcionalidade do app |
| Uso › Interação com o produto (os eventos de uso) | Análise; Funcionalidade do app |
| Outros tipos de dados (CPF ou CNPJ, nascimento, veículos e pets) | Funcionalidade do app |

Não coletados: localização do aparelho, contatos da agenda do celular,
histórico de navegação, dados de saúde, dados de falhas (não há
Crashlytics nem similar).

A URL da política fica nessa mesma seção (App Privacy), e as respostas só
valem depois do **Publish**, no alto da página.
