import 'package:managers/features/empresa/domain/entities/empresa_config.dart'
    show TipoObjeto;

// o porte do que entra na esteira, como a API guarda (o name): o tipo do
// veículo ou a faixa de peso do pet. ele decide o tempo e o preço, por isso
// o serviço pode ser de um porte só e a lista de serviços de um atendimento
// segue o porte do veículo ou do pet. os ícones ficam na presentation
enum Porte {
  moto(TipoObjeto.veiculo),
  carro(TipoObjeto.veiculo),
  suv(TipoObjeto.veiculo),
  van(TipoObjeto.veiculo),
  caminhao(TipoObjeto.veiculo),
  pequeno(TipoObjeto.pet),
  medio(TipoObjeto.pet),
  grande(TipoObjeto.pet),
  gigante(TipoObjeto.pet);

  const Porte(this.tipo);

  final TipoObjeto tipo;

  // os portes de um tipo, na ordem de exibição
  static List<Porte> doTipo(TipoObjeto tipo) =>
      values.where((p) => p.tipo == tipo).toList();

  // o valor da API; vazio (cadastro de antes do porte) ou desconhecido é null
  static Porte? daApi(String? valor) => values.asNameMap()[valor ?? ''];
}

extension PorteNomes on Porte {
  String get nome => switch (this) {
    Porte.moto => 'Moto',
    Porte.carro => 'Carro',
    Porte.suv => 'SUV ou caminhonete',
    Porte.van => 'Van',
    Porte.caminhao => 'Caminhão',
    Porte.pequeno => 'Pequeno',
    Porte.medio => 'Médio',
    Porte.grande => 'Grande',
    Porte.gigante => 'Gigante',
  };

  // o pet é escolhido pelo peso, que é fato; "médio" sozinho é opinião.
  // vazio no veículo
  String get faixa => switch (this) {
    Porte.pequeno => 'até 10 kg',
    Porte.medio => '10 a 25 kg',
    Porte.grande => '25 a 45 kg',
    Porte.gigante => 'acima de 45 kg',
    _ => '',
  };
}
