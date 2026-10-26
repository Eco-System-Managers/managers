import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/widgets/campo_data.dart';

void main() {
  test('interpretar lê dd/mm/aaaa e recusa data incompleta ou inexistente', () {
    expect(CampoData.interpretar('25/10/1990'), DateTime(1990, 10, 25));
    expect(CampoData.interpretar('29/02/2024'), DateTime(2024, 2, 29));
    expect(CampoData.interpretar('29/02/2023'), isNull);
    expect(CampoData.interpretar('31/04/2020'), isNull);
    expect(CampoData.interpretar('25/10/90'), isNull);
    expect(CampoData.interpretar('25/1'), isNull);
    expect(CampoData.interpretar(''), isNull);
  });
}
