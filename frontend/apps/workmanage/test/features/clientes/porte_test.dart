import 'package:flutter_test/flutter_test.dart';
import 'package:managers/features/clientes/domain/entities/objeto_cliente.dart';

void main() {
  test('o valor da API vira o porte; vazio ou desconhecido é null', () {
    expect(Porte.daApi('caminhao'), Porte.caminhao);
    expect(Porte.daApi('medio'), Porte.medio);
    expect(Porte.daApi(''), isNull);
    expect(Porte.daApi(null), isNull);
    expect(Porte.daApi('enorme'), isNull);
  });

  test('cada tipo tem os seus portes, na ordem de exibição', () {
    expect(Porte.doTipo(TipoObjeto.veiculo), [
      Porte.moto,
      Porte.carro,
      Porte.suv,
      Porte.van,
      Porte.caminhao,
    ]);
    expect(Porte.doTipo(TipoObjeto.pet), [
      Porte.pequeno,
      Porte.medio,
      Porte.grande,
      Porte.gigante,
    ]);
  });

  test('o pet vai pelo peso; o veículo não tem faixa', () {
    expect(Porte.medio.faixa, '10 a 25 kg');
    expect(Porte.gigante.faixa, 'acima de 45 kg');
    expect(Porte.van.faixa, isEmpty);
  });

  test('o porte entra no detalhe e no objeto da esteira', () {
    const uno = Veiculo(
      clienteId: 1,
      placa: 'ABC1D23',
      marca: 'Fiat',
      modelo: 'Uno',
      cor: 'Prata',
      porte: Porte.carro,
    );
    const rex = Pet(clienteId: 1, nome: 'Rex', especie: 'Cachorro');

    expect(uno.detalhe, 'ABC1D23 · Prata · Carro');
    expect(const ObjetoCliente.veiculo(uno).porte, Porte.carro);
    // cadastro de antes do porte
    expect(const ObjetoCliente.pet(rex).porte, isNull);
  });
}
