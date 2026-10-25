import 'package:equatable/equatable.dart';

// uma coluna do quadro. a ordem define o status que o cliente vê no app
// dele: a primeira é "aguardando", a última é "concluído"
class Etapa extends Equatable {
  const Etapa({this.id = 0, required this.nome, this.ordem = 0, this.cor = ''});

  // 0 enquanto não existe na API
  final int id;
  final String nome;
  final int ordem;

  // hex como "#F59E0B"; vazio quando o negócio não escolheu
  final String cor;

  bool get ehNova => id == 0;

  Etapa copyWith({int? id, String? nome, int? ordem, String? cor}) {
    return Etapa(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      ordem: ordem ?? this.ordem,
      cor: cor ?? this.cor,
    );
  }

  @override
  List<Object?> get props => [id, nome, ordem, cor];
}
