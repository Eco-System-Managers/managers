// o ramo do negócio. o slug é o valor que o backend guarda (Nicho, em
// backend/apps_work/empresa/models.py); nome e ícone ficam na presentation
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
  banhoTosa('banho_tosa');

  const Nicho(this.slug);

  final String slug;
}
