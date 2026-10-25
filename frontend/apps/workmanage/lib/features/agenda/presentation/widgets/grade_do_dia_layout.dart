import 'package:managers/features/empresa/domain/entities/horario_funcionamento.dart';

import '../../domain/entities/agendamento.dart';

// as contas da grade do dia, sem Flutter: onde cada agendamento entra e o
// trecho do dia que a grade mostra. tudo em minutos desde a meia-noite

// um agendamento posicionado: em qual coluna fica e quantas colunas o
// grupo dele tem (agendamentos que se sobrepõem dividem a largura)
class BlocoDaGrade {
  const BlocoDaGrade({
    required this.agendamento,
    required this.inicio,
    required this.fim,
    required this.coluna,
    required this.colunas,
  });

  final Agendamento agendamento;
  final int inicio;
  final int fim;
  final int coluna;
  final int colunas;
}

// sem serviço (duração zero) o bloco ainda precisa de altura para o toque
const duracaoMinimaDoBloco = 15;

int minutosDoDia(DateTime d) => d.hour * 60 + d.minute;

// distribui os agendamentos em colunas: quem se sobrepõe a alguém do mesmo
// grupo pega a primeira coluna livre; o grupo inteiro divide a largura pelo
// número de colunas que precisou
List<BlocoDaGrade> distribuirColunas(List<Agendamento> agendamentos) {
  final ordenados = [...agendamentos]
    ..sort((a, b) {
      final porInicio = a.dataHora.compareTo(b.dataHora);
      return porInicio != 0 ? porInicio : a.id.compareTo(b.id);
    });

  final blocos = <BlocoDaGrade>[];
  // o grupo atual: fim de cada coluna e os índices dos blocos dele
  var fimDasColunas = <int>[];
  var indicesDoGrupo = <int>[];
  var fimDoGrupo = -1;

  void fecharGrupo() {
    final colunas = fimDasColunas.length;
    for (final i in indicesDoGrupo) {
      final b = blocos[i];
      blocos[i] = BlocoDaGrade(
        agendamento: b.agendamento,
        inicio: b.inicio,
        fim: b.fim,
        coluna: b.coluna,
        colunas: colunas,
      );
    }
    fimDasColunas = [];
    indicesDoGrupo = [];
    fimDoGrupo = -1;
  }

  for (final a in ordenados) {
    final inicio = minutosDoDia(a.dataHora);
    final duracao = a.duracaoTotal > 0 ? a.duracaoTotal : duracaoMinimaDoBloco;
    final fim = inicio + duracao;

    // começa depois de tudo que estava aberto: novo grupo
    if (indicesDoGrupo.isNotEmpty && inicio >= fimDoGrupo) fecharGrupo();

    var coluna = fimDasColunas.indexWhere((f) => f <= inicio);
    if (coluna == -1) {
      coluna = fimDasColunas.length;
      fimDasColunas.add(fim);
    } else {
      fimDasColunas[coluna] = fim;
    }
    if (fim > fimDoGrupo) fimDoGrupo = fim;

    indicesDoGrupo.add(blocos.length);
    blocos.add(
      BlocoDaGrade(
        agendamento: a,
        inicio: inicio,
        fim: fim,
        coluna: coluna,
        colunas: 1,
      ),
    );
  }
  if (indicesDoGrupo.isNotEmpty) fecharGrupo();
  return blocos;
}

// o trecho do dia que a grade mostra: o expediente, esticado para caber
// qualquer agendamento fora dele, arredondado para a hora cheia. null
// quando o negócio não abre no dia e não há nada marcado
({int inicio, int fim})? intervaloDaGrade({
  required ({HoraDoDia abertura, HoraDoDia fechamento})? expediente,
  required List<BlocoDaGrade> blocos,
}) {
  int? inicio = expediente?.abertura.emMinutos;
  int? fim = expediente?.fechamento.emMinutos;
  for (final b in blocos) {
    if (inicio == null || b.inicio < inicio) inicio = b.inicio;
    if (fim == null || b.fim > fim) fim = b.fim;
  }
  if (inicio == null || fim == null) return null;

  inicio = inicio - inicio % 60;
  if (fim % 60 != 0) fim = fim + (60 - fim % 60);
  // um expediente vazio ou invertido ainda ganha uma hora de grade
  if (fim <= inicio) fim = inicio + 60;
  return (inicio: inicio, fim: fim.clamp(0, 24 * 60));
}

// a hora tocada num ponto da grade, presa à linha de baixo do passo
int minutoTocado({
  required int inicioDaGrade,
  required int minutosDesdeOTopo,
  required int passo,
}) {
  final minuto = inicioDaGrade + minutosDesdeOTopo;
  return minuto - (minuto - inicioDaGrade) % passo;
}
