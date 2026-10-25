import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'via_cep_datasource.dart';

// injeção da busca por CEP: as features pegam daqui via ref
final cepDataSourceProvider = Provider<ViaCepDataSource>(
  (ref) => ViaCepDataSource(),
);
