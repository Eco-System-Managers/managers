import 'package:intl/intl.dart';

// formatos da API (backend/openapi/README.md): data "2026-10-19", data e
// hora ISO 8601 com fuso "2026-10-19T10:30:00-03:00", hora "10:30" ou
// "10:30:00" conforme o campo. na tela, o formato brasileiro

final _dataApi = DateFormat('yyyy-MM-dd');
final _dataHoraApi = DateFormat("yyyy-MM-dd'T'HH:mm:ss");
final _dataTela = DateFormat('dd/MM/yyyy');

// um horário sem data, como vem nos campos de hora da API
typedef Hora = ({int hora, int minuto});

// "2026-10-19" -> meia-noite local daquele dia
DateTime dataDaApi(String valor) => DateTime.parse(valor);

String dataParaApi(DateTime data) => _dataApi.format(data);

// sempre em horário local: a API manda o fuso, o Dart converte
DateTime dataHoraDaApi(String valor) => DateTime.parse(valor).toLocal();

// o toIso8601String do Dart omite o fuso em data local, e a API precisa
// dele para não interpretar a hora no fuso do servidor
String dataHoraParaApi(DateTime dataHora) {
  final local = dataHora.toLocal();
  final offset = local.timeZoneOffset;
  final sinal = offset.isNegative ? '-' : '+';
  final horas = _doisDigitos(offset.abs().inHours);
  final minutos = _doisDigitos(offset.abs().inMinutes % 60);
  return '${_dataHoraApi.format(local)}$sinal$horas:$minutos';
}

// "10:30" ou "10:30:00"
Hora horaDaApi(String valor) {
  final partes = valor.split(':');
  return (hora: int.parse(partes[0]), minuto: int.parse(partes[1]));
}

String horaParaApi(Hora hora) =>
    '${_doisDigitos(hora.hora)}:${_doisDigitos(hora.minuto)}';

String formatarData(DateTime data) => _dataTela.format(data);

String formatarHora(Hora hora) => horaParaApi(hora);

String formatarDataHora(DateTime dataHora) {
  final local = dataHora.toLocal();
  return '${formatarData(local)} '
      '${formatarHora((hora: local.hour, minuto: local.minute))}';
}

String _doisDigitos(int valor) => valor.toString().padLeft(2, '0');

// a data sem a hora, para comparar e agrupar por dia
DateTime somenteData(DateTime d) => DateTime(d.year, d.month, d.day);

bool mesmoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

Hora horaDe(DateTime d) => (hora: d.hour, minuto: d.minute);

DateTime juntarDataHora(DateTime data, Hora hora) =>
    DateTime(data.year, data.month, data.day, hora.hora, hora.minuto);

// nomes em português sem depender dos dados de locale do intl (que
// precisam ser carregados antes e não existem nos testes)
const nomesDosMeses = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

// na ordem de DateTime.weekday (segunda = 1)
const nomesCurtosDosDias = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

// como se fala: "quinta", "sábado" (sem o "-feira")
const nomesDosDias = [
  'segunda',
  'terça',
  'quarta',
  'quinta',
  'sexta',
  'sábado',
  'domingo',
];

String nomeDoMes(int mes) => nomesDosMeses[mes - 1];

String nomeCurtoDoDia(DateTime d) => nomesCurtosDosDias[d.weekday - 1];

String nomeDoDiaDaSemana(DateTime d) => nomesDosDias[d.weekday - 1];

// uma duração em minutos como se fala: "40 min", "1 h", "1h30", "2 h"
String formatarDuracao(int minutos) {
  if (minutos < 60) return '$minutos min';
  final horas = minutos ~/ 60;
  final resto = minutos % 60;
  return resto == 0 ? '$horas h' : '${horas}h${_doisDigitos(resto)}';
}

// "outubro de 2026"
String formatarMesAno(DateTime d) => '${nomeDoMes(d.month)} de ${d.year}';

// "sex, 25 de outubro"
String formatarDataPorExtenso(DateTime d) =>
    '${nomeCurtoDoDia(d)}, ${d.day} de ${nomeDoMes(d.month)}';
