import 'package:flutter/material.dart';

import '../../domain/entities/nicho.dart';

// como cada nicho aparece na tela. fica na presentation porque nome e ícone
// são coisa de tela (o backend só conhece o slug). o switch sem default faz
// o analyze reclamar se um nicho novo entrar no enum sem nome e ícone aqui
extension NichoVisual on Nicho {
  String get nome => switch (this) {
    Nicho.cabeleireiro => 'Cabeleireiro(a)',
    Nicho.barbearia => 'Barbearia',
    Nicho.manicure => 'Manicure',
    Nicho.pedicure => 'Pedicure',
    Nicho.depilacao => 'Depilação',
    Nicho.designSobrancelhas => 'Design de sobrancelhas',
    Nicho.micropigmentacao => 'Micropigmentação',
    Nicho.cilios => 'Cílios',
    Nicho.maquiagem => 'Maquiagem',
    Nicho.massagem => 'Massagem',
    Nicho.lavaRapido => 'Lava-rápido',
    Nicho.banhoTosa => 'Banho e Tosa',
    Nicho.outro => 'Outro',
  };

  // na família Round, como todo ícone do app
  IconData get icone => switch (this) {
    Nicho.cabeleireiro => Icons.content_cut_rounded,
    Nicho.barbearia => Icons.face_rounded,
    Nicho.manicure => Icons.back_hand_rounded,
    Nicho.pedicure => Icons.self_improvement_rounded,
    Nicho.depilacao => Icons.water_drop_rounded,
    Nicho.designSobrancelhas => Icons.visibility_rounded,
    Nicho.micropigmentacao => Icons.brush_rounded,
    Nicho.cilios => Icons.remove_red_eye_rounded,
    Nicho.maquiagem => Icons.face_retouching_natural_rounded,
    Nicho.massagem => Icons.spa_rounded,
    Nicho.lavaRapido => Icons.local_car_wash_rounded,
    Nicho.banhoTosa => Icons.pets_rounded,
    Nicho.outro => Icons.more_horiz_rounded,
  };
}
