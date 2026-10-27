import 'entities/dashboard_resumo.dart';

// qual dos atendimentos de hoje é "o próximo": o primeiro cuja hora ainda
// não passou. passou da hora, o card já mostra o seguinte (o anterior está
// sendo atendido, ou não veio; a ficha resolve). na esteira (sem hora
// fixa) é o primeiro da lista
AgendamentoHoje? proximoDeHoje(
  List<AgendamentoHoje> hoje, {
  required int minutosAgora,
  bool isKanban = false,
}) {
  if (hoje.isEmpty) return null;
  if (isKanban) return hoje.first;
  final ordenados = [...hoje]..sort((a, b) => a.minutos.compareTo(b.minutos));
  for (final a in ordenados) {
    if (a.minutos >= minutosAgora) return a;
  }
  return null;
}
