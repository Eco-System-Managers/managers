// o que a versão trouxe, numa linha: a folha de novidades mostra uma vez,
// depois de atualizar. o ícone é da tela, escolhido pelo tipo
enum TipoDeNovidade { variosServicos, tema }

class Novidade {
  const Novidade({
    required this.tipo,
    required this.titulo,
    required this.texto,
    this.soNaAgenda = false,
  });

  final TipoDeNovidade tipo;
  final String titulo;
  final String texto;

  // o que só existe no modo horário não aparece para a esteira
  final bool soNaAgenda;

  bool valePara({required bool isKanban}) => !soNaAgenda || !isKanban;
}

// a versão destas novidades: muda a cada release que tiver o que contar,
// junto com a lista. quem já viu esta versão não vê de novo
const versaoDasNovidades = '1.0.0+2';

// a principal primeiro
const novidadesDaVersao = [
  Novidade(
    tipo: TipoDeNovidade.variosServicos,
    titulo: 'Vários serviços no mesmo agendamento',
    texto:
        'Corte e barba num horário só: o tempo e o valor somam sozinhos, '
        'e a agenda mostra os horários em que tudo cabe.',
    soNaAgenda: true,
  ),
  Novidade(
    tipo: TipoDeNovidade.tema,
    titulo: 'Tema claro ou escuro',
    texto: 'Escolha em Mais › Tema, ou deixe igual ao aparelho.',
  ),
];
