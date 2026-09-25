# Arquitetura

lib/
├── main.dart                     # Ponto de entrada. Só chama runApp com o App.
├── app/                          # A "casca" do app: configuração global e visível.
│   ├── app.dart                  # Widget raiz (MaterialApp): nome do app, tema e rotas.
│   ├── routes/                   # Navegação: nomes das rotas (/login, /cadastro) e qual tela abre em cada uma.
│   └── theme/                    # Identidade visual: cores, fontes, espaçamentos e o estilo padrão dos componentes.
├── features/                     # O produto em si. Uma pasta por área do app.
│   └── auth/                     # Tudo relacionado a entrar e criar conta.
│       ├── screens/              # Telas inteiras (login_screen, register_screen).
│       └── widgets/              # Pedaços de tela usados só em auth (cabeçalho com logo, link "Não tem conta?").
└── shared/                       # O que é usado por mais de uma área.
    └── widgets/                  # Componentes padrão do app: botões, campos, mensagens de erro. Começam com app_.