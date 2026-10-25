// o ramo do negócio. o slug é o valor que o backend guarda (Nicho, em
// backend/apps_work/empresa/models.py); nome e ícone ficam na presentation.
// outro é a saída de quem não se acha na lista: o dono descreve o ramo e
// escolhe o modo de agenda
enum Nicho {
  cabeleireiro('cabeleireiro'),
  barbearia('barbearia'),
  manicure('manicure'),
  pedicure('pedicure'),
  depilacao('depilacao'),
  designSobrancelhas('design_sobrancelhas'),
  micropigmentacao('micropigmentacao'),
  cilios('cilios'),
  maquiagem('maquiagem'),
  massagem('massagem'),
  lavaRapido('lava_rapido'),
  banhoTosa('banho_tosa'),
  outro('outro');

  const Nicho(this.slug);

  final String slug;
}
