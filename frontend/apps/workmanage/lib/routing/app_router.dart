import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/session/sessao_provider.dart';
import 'package:managers/features/agenda/presentation/pages/agendamento_form_page.dart';
import 'package:managers/features/agenda/presentation/pages/agendamento_page.dart';
import 'package:managers/features/agenda/presentation/pages/historico_cliente_page.dart';
import 'package:managers/features/agenda/presentation/pages/pendencias_page.dart';
import 'package:managers/features/assinatura/presentation/pages/assinatura_page.dart';
import 'package:managers/features/auth/presentation/pages/login_page.dart';
import 'package:managers/features/auth/presentation/pages/recovery_page.dart';
import 'package:managers/features/clientes/presentation/pages/cliente_form_page.dart';
import 'package:managers/features/clientes/presentation/pages/cliente_page.dart';
import 'package:managers/features/clientes/presentation/pages/clientes_page.dart';
import 'package:managers/features/empresa/presentation/pages/configuracoes_page.dart';
import 'package:managers/features/empresa/presentation/pages/dados_negocio_page.dart';
import 'package:managers/features/empresa/presentation/pages/horarios_page.dart';
import 'package:managers/features/financeiro/presentation/pages/caixa_page.dart';
import 'package:managers/features/home/presentation/pages/home_shell_page.dart';
import 'package:managers/features/home/presentation/pages/mais_page.dart';
import 'package:managers/features/home/presentation/pages/primeira_aba_page.dart';
import 'package:managers/features/kanban/presentation/pages/atendimento_kanban_form_page.dart';
import 'package:managers/features/kanban/presentation/pages/atendimento_kanban_page.dart';
import 'package:managers/features/kanban/presentation/pages/etapas_page.dart';
import 'package:managers/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:managers/features/register/presentation/pages/register_page.dart';
import 'package:managers/features/register/presentation/pages/verify_email_page.dart';
import 'package:managers/features/servicos/presentation/pages/servico_form_page.dart';
import 'package:managers/features/servicos/presentation/pages/servicos_page.dart';
import 'package:managers/features/splash/presentation/pages/splash_page.dart';
import 'package:managers/features/usuarios/presentation/pages/aceitar_convite_page.dart';
import 'package:managers/features/usuarios/presentation/pages/colaborador_page.dart';
import 'package:managers/features/usuarios/presentation/pages/convite_form_page.dart';
import 'package:managers/features/usuarios/presentation/pages/equipe_page.dart';

// as telas que abrem por cima da navegação inferior (formulários e
// configurações) usam o navegador raiz, não o da aba
final _rootNavigatorKey = GlobalKey<NavigatorState>();

// o router é um provider para enxergar a sessão (ref)
final routerProvider = Provider<GoRouter>((ref) {
  final sessao = ref.watch(sessaoControllerProvider);
  final bloqueio = ref.watch(bloqueioAssinaturaProvider);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    // o app sempre abre pela splash, que decide para onde ir
    initialLocation: '/splash',
    // quando a sessão muda (login, logout, 401 definitivo no interceptor),
    // o router reavalia o redirect: tela privada sem sessão volta ao login
    refreshListenable: Listenable.merge([sessao, bloqueio]),
    redirect: (context, state) {
      // antes de a splash carregar a sessão guardada, não há o que decidir
      if (!sessao.carregada) return null;
      final destino = state.matchedLocation;
      if (!sessao.autenticado && !_publica(destino)) return '/login';
      // 402 em qualquer requisição: só a tela de assinatura resolve
      if (sessao.autenticado &&
          bloqueio.bloqueada &&
          !_publica(destino) &&
          destino != '/mais/assinatura') {
        return '/mais/assinatura';
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/splash',
        builder: (BuildContext context, GoRouterState state) {
          return const SplashPage();
        },
      ),
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) {
          return const LoginPage();
        },
      ),
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) {
          return const LoginPage();
        },
      ),
      GoRoute(
        path: '/recovery',
        pageBuilder: (BuildContext context, GoRouterState state) {
          return _authPanelPage(state, const RecoveryPage());
        },
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (BuildContext context, GoRouterState state) {
          return _authPanelPage(state, const RegisterPage());
        },
      ),
      // o e-mail vai na URL: a tela precisa dele para confirmar e reenviar
      GoRoute(
        path: '/register/verificar',
        pageBuilder: (BuildContext context, GoRouterState state) {
          return _authPanelPage(
            state,
            VerifyEmailPage(email: state.uri.queryParameters['email'] ?? ''),
          );
        },
      ),
      // página normal: o onboarding tem Scaffold e AppBar próprios, não usa
      // o painel animado das telas de auth
      GoRoute(
        path: '/onboarding',
        builder: (BuildContext context, GoRouterState state) {
          return const OnboardingPage();
        },
      ),
      // o link do convite da equipe: pública, quem abre ainda não tem conta
      GoRoute(
        path: '/convite/:token',
        builder: (_, state) =>
            AceitarConvitePage(token: state.pathParameters['token']!),
      ),
      // o quadro da esteira: as telas abrem por cima da primeira aba
      GoRoute(
        path: '/quadro/novo',
        builder: (_, state) {
          final data = state.uri.queryParameters['data'];
          return AtendimentoKanbanFormPage(
            dataInicial: data == null ? null : DateTime.tryParse(data),
          );
        },
      ),
      GoRoute(
        path: '/quadro/:id',
        builder: (_, state) =>
            AtendimentoKanbanPage(id: int.parse(state.pathParameters['id']!)),
      ),
      // a home é a casca com as abas; /home abre na primeira
      GoRoute(path: '/home', redirect: (_, _) => '/agenda'),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomeShellPage(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/agenda',
                // agenda por horário ou quadro da esteira, pelo modo do negócio
                builder: (_, _) => const PrimeiraAbaPage(),
                routes: [
                  // o dia aberto na agenda vai na URL (?data=2026-10-25)
                  GoRoute(
                    path: 'novo',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, state) {
                      final data = state.uri.queryParameters['data'];
                      return AgendamentoFormPage(
                        dataInicial: data == null
                            ? null
                            : DateTime.tryParse(data),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'pendencias',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, _) => const PendenciasPage(),
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, state) => AgendamentoPage(
                      id: int.parse(state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/clientes',
                builder: (_, _) => const ClientesPage(),
                routes: [
                  GoRoute(
                    path: 'novo',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, _) => const ClienteFormPage(),
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, state) =>
                        ClientePage(id: int.parse(state.pathParameters['id']!)),
                    routes: [
                      GoRoute(
                        path: 'editar',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (_, state) => ClienteFormPage(
                          id: int.parse(state.pathParameters['id']!),
                        ),
                      ),
                      // o histórico é da agenda, mas mora embaixo do cliente
                      GoRoute(
                        path: 'atendimentos',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (_, state) => HistoricoClientePage(
                          clienteId: int.parse(state.pathParameters['id']!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/servicos',
                builder: (_, _) => const ServicosPage(),
                routes: [
                  GoRoute(
                    path: 'novo',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, _) => const ServicoFormPage(),
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, state) => ServicoFormPage(
                      id: int.tryParse(state.pathParameters['id'] ?? ''),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/caixa', builder: (_, _) => const CaixaPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/mais',
                builder: (_, _) => const MaisPage(),
                routes: [
                  GoRoute(
                    path: 'configuracoes',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, _) => const ConfiguracoesPage(),
                    routes: [
                      GoRoute(
                        path: 'negocio',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (_, _) => const DadosNegocioPage(),
                      ),
                      GoRoute(
                        path: 'horarios',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (_, _) => const HorariosPage(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'equipe',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, _) => const EquipePage(),
                    routes: [
                      GoRoute(
                        path: 'convidar',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (_, _) => const ConviteFormPage(),
                      ),
                      GoRoute(
                        path: ':id',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (_, state) => ColaboradorPage(
                          id: int.parse(state.pathParameters['id']!),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'assinatura',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, _) => const AssinaturaPage(),
                  ),
                  GoRoute(
                    path: 'etapas',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, _) => const EtapasPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

// as telas que abrem sem sessão: splash, login, recuperação e cadastro
bool _publica(String rota) {
  return rota == '/splash' ||
      rota == '/' ||
      rota == '/login' ||
      rota == '/recovery' ||
      rota.startsWith('/register') ||
      rota.startsWith('/convite/');
}

// transição das telas de auth abertas a partir do login (cadastro e
// recuperação). o fundo delas é igual ao do login: o fade da página é só um
// instante no começo (ida) / no fim (volta), para trocar o conteúdo.
// o efeito principal é o painel crescendo/encolhendo (ver AuthPanel)
CustomTransitionPage<void> _authPanelPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 450),
    reverseTransitionDuration: const Duration(milliseconds: 450),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation.drive(
          CurveTween(curve: const Interval(0, 0.25, curve: Curves.easeOut)),
        ),
        child: child,
      );
    },
  );
}
