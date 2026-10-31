import 'package:equatable/equatable.dart';

// uma coluna do quadro. a primeira é onde o atendimento entra ("aguardando"
// para o cliente); a de pronto é a que o dono marca: chegando nela (ou em
// qualquer uma depois dela) o atendimento está pronto, a vaga é liberada e
// o cliente vê "pronto". sem marcação, vale a última
class Etapa extends Equatable {
  const Etapa({
    this.id = 0,
    required this.nome,
    this.ordem = 0,
    this.cor = '',
    this.pronto = false,
  });

  // 0 enquanto não existe na API
  final int id;
  final String nome;
  final int ordem;

  // hex como "#F59E0B"; vazio quando o negócio não escolheu
  final String cor;

  // a etapa de pronto, uma só por quadro
  final bool pronto;

  bool get ehNova => id == 0;

  Etapa copyWith({
    int? id,
    String? nome,
    int? ordem,
    String? cor,
    bool? pronto,
  }) {
    return Etapa(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      ordem: ordem ?? this.ordem,
      cor: cor ?? this.cor,
      pronto: pronto ?? this.pronto,
    );
  }

  @override
  List<Object?> get props => [id, nome, ordem, cor, pronto];
}

// a posição a partir da qual o atendimento conta como pronto: a etapa
// marcada ou, sem marcação, a última. -1 numa lista vazia
int indiceDePronto(List<Etapa> etapas) {
  final marcada = etapas.indexWhere((e) => e.pronto);
  return marcada >= 0 ? marcada : etapas.length - 1;
}
