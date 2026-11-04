# Publicação no iPhone — TestFlight e App Store

O passo a passo do Work Manage no iPhone: dos testadores internos à loja.
Os textos de cada campo estão em `TEXTOS_DA_LOJA.md`.

## Decisões

1. **Só iPhone.** Já está no projeto (`TARGETED_DEVICE_FAMILY = 1`).
2. **Assinatura no iPhone: nada muda.** O app já está dentro das regras da
   Apple (não vende nem mostra preço no iPhone). Não trava o beta nem a loja.
3. **Um build só para tudo:** a versão `1.0.0` passa pelos internos, pelos
   externos e vai para a loja. Só o `+N` sobe a cada envio.
4. **Loja com liberação manual:** a Apple aprova, você escolhe o dia de
   publicar.

## Interno x externo

- **Interno:** só quem está cadastrado em *Usuários e Acesso* no App Store
  Connect (até 100). **Sem revisão da Apple.** Serve para você conferir o
  build primeiro.
- **Externo:** qualquer pessoa, por link (até 10 mil). **O primeiro build
  passa pela revisão do beta** (horas a 1 dia). Serve para os testadores.

---

## Etapa 1 — Enviar o build (no Mac)

1. Testar no iPhone pelo cabo: `flutter run --release`.
2. Gerar: `flutter build ipa --release`.
3. Abrir o app **Transporter**, arrastar o `.ipa` de `build/ios/ipa/` e
   clicar em **Entregar**.
4. Em 10 a 30 min o build aparece em App Store Connect › seu app › aba
   **TestFlight**.

## Etapa 2 — Teste interno (sem revisão)

1. Aba TestFlight › no menu da esquerda, **+** ao lado de **Teste interno**
   › criar um grupo.
2. Adicionar você ao grupo e adicionar o build.
3. No iPhone, instalar pelo app **TestFlight** e usar: entrar com a conta do
   revisor, abrir as abas, marcar um atendimento.

## Etapa 3 — Teste externo (com revisão do beta)

**Antes:** no admin do backend, deixar a conta do revisor como
**vitalícia**, para ela nunca cair no bloqueio.

### 3.1 Preencher uma vez

Aba TestFlight › menu da esquerda › **Informações de teste**. Os textos estão
em `TEXTOS_DA_LOJA.md`, seção 1.

| Campo | O que colocar |
|---|---|
| Descrição do beta | texto da seção 1 |
| E-mail para feedback | `contato@workmanage.com.br` |
| URL da política de privacidade | `https://api.workmanage.com.br/privacidade` |
| Informações para revisão: contato | seu nome, telefone e e-mail |
| Login obrigatório | marcado, com o usuário e a senha da conta do revisor |
| **Notas** | as notas em inglês da seção 1 |

### 3.2 Criar o grupo e enviar

1. **+** ao lado de **Teste externo** › nome "Testadores".
2. Dentro do grupo, em **Builds**, **+** › escolher o build.
3. No campo **"O que testar"**, colar o texto da seção 2 › **Enviar para
   revisão**.

### 3.3 Depois de aprovado

No grupo, ativar o **link público** e mandar aos testadores. Eles instalam o
app TestFlight e abrem o link.

## Etapa 4 — A loja (quando os testes acabarem)

Aba **Distribuição** do app no App Store Connect. Os textos estão em
`TEXTOS_DA_LOJA.md`, seção 3.

1. **Informações do app:** subtítulo, categoria (Negócios) e classificação
   etária.
2. **Privacidade do app:** a URL da política e o questionário (respostas na
   tabela da seção 3).
3. **Preço e disponibilidade:** preço de download **Grátis** (o campo é só o
   valor para baixar na loja; a assinatura do negócio é cobrada por fora da
   Apple, como já está decidido) e disponível só no Brasil.
4. **Página da versão** (menu da esquerda, "1.0 Preparar para envio"):
   - trocar o número da versão para **1.0.0**;
   - capturas de tela, texto promocional, descrição, palavras-chave, URL de
     suporte e copyright;
   - **Build:** o mesmo que os testadores usaram;
   - **Informações da revisão do app:** a mesma conta do revisor e as
     **mesmas notas** do beta;
   - **Liberação da versão:** **Liberar esta versão manualmente**.
5. **Adicionar para revisão** › **Enviar**. Aprovado, você publica no dia que
   quiser.

---

## Pendências

- [ ] Commits: `chore(ios): deixa o app só para iPhone` e
  `docs: adiciona os textos da App Store e do TestFlight`.
- [ ] Etapas 1, 2 e 3 (você).
- [ ] Página `/suporte` no backend: a **URL de suporte** é obrigatória na
  loja. Fazer antes da etapa 4.
