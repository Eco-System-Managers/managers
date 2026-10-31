import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/features/clientes/domain/entities/porte.dart';
import 'package:managers/features/servicos/data/models/servico_model.dart';
import 'package:managers/features/servicos/domain/entities/servico.dart';

Servico _servico({Porte? porte}) => Servico(
  nome: 'Lavagem',
  porte: porte,
  duracao: 20,
  preco: Decimal.fromInt(25),
);

void main() {
  test('serviço de um porte só atende esse porte, como na API', () {
    final moto = _servico(porte: Porte.moto);

    expect(moto.servePara(Porte.moto), isTrue);
    expect(moto.servePara(Porte.carro), isFalse);
    // objeto sem porte: não há com o que comparar
    expect(moto.servePara(null), isTrue);
    // serviço sem porte vale para qualquer um
    expect(_servico().servePara(Porte.caminhao), isTrue);
  });

  test('o porte vem e vai como o valor da API; vazio é qualquer porte', () {
    final json = {
      'id': 1,
      'nome': 'Lavagem moto',
      'nicho': 'lava_rapido',
      'porte': 'moto',
      'descricao': '',
      'duracao': 20,
      'preco': '25.00',
      'taxa_cancelamento_tipo': '',
      'taxa_cancelamento_valor': '0.00',
      'ativo': true,
      'colaboradores': <int>[],
    };

    final servico = ServicoModel.fromJson(json).toEntity();
    final semPorte = ServicoModel.fromJson({...json, 'porte': ''}).toEntity();

    expect(servico.porte, Porte.moto);
    expect(semPorte.porte, isNull);
    expect(ServicoModel.fromEntity(servico).toJson()['porte'], 'moto');
    // vazio vai explícito, para tirar o porte de um serviço
    expect(ServicoModel.fromEntity(semPorte).toJson()['porte'], '');
  });
}
