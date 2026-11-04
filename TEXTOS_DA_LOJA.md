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
> Account deletion is available in the app under "Mais › Excluir conta". To
> test it, please create a new account through "Criar conta" on the login
> screen (a confirmation code is sent by email), so the review account stays
> available.
>
> The camera and photo library are only used when the owner chooses the
> business logo ("Mais › Configurações › Dados do negócio").
>
> The app has no in-app purchases and no links to external purchases.

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

Pode ir preenchendo durante os testes; só se envia quando os testes acabarem,
com **"Liberar esta versão manualmente"** marcado.

### Informações do app

- **Nome** (até 30): o que já está registrado no App Store Connect.
- **Subtítulo** (até 30): `Agenda, clientes e caixa`
- **Categoria principal:** Negócios. **Secundária:** Produtividade.
- **Copyright:** `2026 Wilson Geraldo Donizeti Pereira Júnior`
- **Classificação etária:** "Nenhum" em todas as perguntas (sem conteúdo
  sensível, sem chat entre usuários, sem navegador aberto).

### Texto promocional (até 170; muda sem nova revisão)

> Agenda, clientes, cobrança e caixa do seu negócio de atendimento, direto
> no celular.

### Descrição (até 4.000)

Sem citar preço, assinatura nem pagamento fora do app: o iPhone não pode.

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

### Palavras-chave (até 100, separadas por vírgula, sem espaço)

```
agenda,agendamento,barbearia,salão,estética,lava-jato,petshop,clientes,caixa,comissão,serviços
```

### URLs

- **Suporte (obrigatória):** ainda não existe. Uma página simples no
  backend (`/suporte`, com o e-mail de contato) resolve.
- **Marketing:** opcional.
- **Política de privacidade:** `https://api.workmanage.com.br/privacidade`

### Informações da revisão do app

As mesmas do beta: contato, login obrigatório com a conta do revisor e as
notas da seção 1. A conta precisa continuar valendo (vitalícia no admin, a
senha sem trocar).

### Capturas de tela

iPhone 6,9" (1320 × 2868), de 3 a 10, tiradas no simulador do maior iPhone
com a conta preenchida. Sugestão de ordem: a agenda do dia, o quadro, a
ficha do cliente, a cobrança, o caixa e o Início.

### Preço e disponibilidade

Preço de download **Grátis**, só no Brasil, sem compras no app. O campo é
só o valor para baixar na loja: a assinatura do negócio é cobrada por fora
da Apple (pelo Mercado Pago), e o app no iPhone não fala dela.

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
| Fotos ou vídeos (a logo) | Funcionalidade do app |
| Identificadores › ID do usuário | Funcionalidade do app |
| Uso › Interação com o produto (os eventos de uso) | Análise; Funcionalidade do app |
| Outros tipos de dados (CPF ou CNPJ, nascimento, veículos e pets) | Funcionalidade do app |

Não coletados: localização do aparelho, contatos da agenda do celular,
histórico de navegação, dados de saúde, dados de falhas (não há
Crashlytics nem similar).
