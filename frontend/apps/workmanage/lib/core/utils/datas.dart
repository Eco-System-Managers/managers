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
