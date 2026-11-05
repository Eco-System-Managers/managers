import 'package:flutter/foundation.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../../domain/entities/novidade.dart';
import '../../domain/usecases/buscar_novidades_use_case.dart';
import '../../domain/usecases/marcar_novidades_vistas_use_case.dart';

// decide, uma vez por abertura da casca, se a folha de novidades aparece.
// marca como vista ao entregar a lista: a folha aparece uma vez só, mesmo
// que a pessoa feche o app com ela aberta
class NovidadesProvider extends ChangeNotifier {
  NovidadesProvider({required this._buscar, required this._marcarVistas});

  final BuscarNovidadesUseCase _buscar;
  final MarcarNovidadesVistasUseCase _marcarVistas;

  bool _verificado = false;

  // vazia quando não há o que mostrar
  Future<List<Novidade>> paraMostrar({required bool isKanban}) async {
    if (_verificado) return const [];
    _verificado = true;
    final result = await _buscar(BuscarNovidadesParams(isKanban: isKanban));
    final itens = result.getOrElse(() => const []);
    if (itens.isNotEmpty) await _marcarVistas(NoParams());
    return itens;
  }
}
