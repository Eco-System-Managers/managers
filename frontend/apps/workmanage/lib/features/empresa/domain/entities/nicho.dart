// a área de um nicho é o modo que ele decide no backend (ModoAgendaService):
// agenda por horário, esteira com veículo ou esteira com pet. o negócio só
// junta nichos de uma área: agenda e quadro não convivem, e o card do quadro
// é um veículo ou um pet. não é cadastro, é só este agrupamento
enum AreaNicho { belezaBemEstar, automotivo, pet }

// o ramo do negócio. o slug é o valor que o backend guarda (Nicho, em
// backend/apps_work/empresa/models.py); nome e ícone ficam na presentation.
// a ordem aqui é a de exibição, a mesma do backend. outro é a saída de quem
// não se acha na lista: o dono descreve o ramo e escolhe o modo, então ele
// não tem área e vai sempre sozinho
enum Nicho {
  cabeleireiro('cabeleireiro', AreaNicho.belezaBemEstar),
  barbearia('barbearia', AreaNicho.belezaBemEstar),
  manicure('manicure', AreaNicho.belezaBemEstar),
  pedicure('pedicure', AreaNicho.belezaBemEstar),
  depilacao('depilacao', AreaNicho.belezaBemEstar),
  designSobrancelhas('design_sobrancelhas', AreaNicho.belezaBemEstar),
  micropigmentacao('micropigmentacao', AreaNicho.belezaBemEstar),
  cilios('cilios', AreaNicho.belezaBemEstar),
  maquiagem('maquiagem', AreaNicho.belezaBemEstar),
  massagem('massagem', AreaNicho.belezaBemEstar),
  lavaRapido('lava_rapido', AreaNicho.automotivo),
  banhoTosa('banho_tosa', AreaNicho.pet),
  outro('outro', null);

  const Nicho(this.slug, this.area);

  final String slug;
  final AreaNicho? area;

  // o negócio escolhe de 1 a 4
  static const maximoPorNegocio = 4;

  // slug desconhecido vira null
  static Nicho? doSlug(String slug) =>
      values.where((n) => n.slug == slug).firstOrNull;
}

// as regras da escolha, as mesmas do backend: até 4, da mesma área, e o
// outro sempre sozinho. a tela desabilita o que não pode entrar, e a lista
// fica sempre na ordem do enum
extension EscolhaDeNichos on List<Nicho> {
  // marcar este nicho é possível? os já marcados sempre podem sair; o outro
  // troca a escolha inteira, e qualquer nicho troca o outro
  bool aceita(Nicho nicho) {
    if (contains(nicho) || isEmpty) return true;
    if (nicho == Nicho.outro || contains(Nicho.outro)) return true;
    if (length >= Nicho.maximoPorNegocio) return false;
    return nicho.area == first.area;
  }

  // marca ou desmarca. o que a regra não aceita deixa a escolha como está
  List<Nicho> alternar(Nicho nicho) {
    if (contains(nicho)) return [...this]..remove(nicho);
    if (!aceita(nicho)) return this;
    if (nicho == Nicho.outro || contains(Nicho.outro)) return [nicho];
    return [...this, nicho]..sort((a, b) => a.index.compareTo(b.index));
  }
}
