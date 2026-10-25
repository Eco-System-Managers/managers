import '../../domain/entities/horario_funcionamento.dart';

// o formato do /empresa/horarios/. o backend usa TimeField, que vai e volta
// como texto "HH:MM:SS"
class HorarioFuncionamentoModel {
  const HorarioFuncionamentoModel({
    required this.dia,
    required this.ativo,
    required this.abertura,
    required this.fechamento,
    required this.capacidade,
  });

  final int dia;
  final bool ativo;
  final String? abertura;
  final String? fechamento;
  final int? capacidade;

  factory HorarioFuncionamentoModel.fromJson(Map<String, dynamic> json) {
    return HorarioFuncionamentoModel(
      dia: json['dia'] as int,
      ativo: json['ativo'] as bool? ?? true,
      abertura: json['abertura'] as String?,
      fechamento: json['fechamento'] as String?,
      capacidade: json['capacidade'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dia': dia,
      'ativo': ativo,
      'abertura': abertura,
      'fechamento': fechamento,
      'capacidade': capacidade,
    };
  }

  factory HorarioFuncionamentoModel.fromEntity(HorarioFuncionamento horario) {
    return HorarioFuncionamentoModel(
      // o index do enum já é a numeração do backend (0 = segunda)
      dia: horario.dia.index,
      ativo: horario.ativo,
      abertura: _paraTexto(horario.abertura),
      fechamento: _paraTexto(horario.fechamento),
      capacidade: horario.capacidade,
    );
  }

  HorarioFuncionamento toEntity() {
    return HorarioFuncionamento(
      dia: DiaSemana.values[dia],
      ativo: ativo,
      abertura: _paraHora(abertura),
      fechamento: _paraHora(fechamento),
      capacidade: capacidade,
    );
  }

  // "08:30:00" -> HoraDoDia(8, 30)
  static HoraDoDia? _paraHora(String? texto) {
    if (texto == null || texto.isEmpty) return null;
    final partes = texto.split(':');
    return HoraDoDia(int.parse(partes[0]), int.parse(partes[1]));
  }

  // HoraDoDia(8, 30) -> "08:30:00"
  static String? _paraTexto(HoraDoDia? hora) {
    if (hora == null) return null;
    final h = hora.hora.toString().padLeft(2, '0');
    final m = hora.minuto.toString().padLeft(2, '0');
    return '$h:$m:00';
  }
}
