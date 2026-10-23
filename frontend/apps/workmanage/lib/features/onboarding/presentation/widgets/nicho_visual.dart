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
  };

  IconData get icone => switch (this) {
    Nicho.cabeleireiro => Icons.content_cut,
    Nicho.barbearia => Icons.face_outlined,
    Nicho.manicure => Icons.back_hand_outlined,
    Nicho.pedicure => Icons.self_improvement,
    Nicho.depilacao => Icons.water_drop_outlined,
    Nicho.designSobrancelhas => Icons.visibility_outlined,
    Nicho.micropigmentacao => Icons.brush_outlined,
    Nicho.cilios => Icons.remove_red_eye_outlined,
    Nicho.maquiagem => Icons.face_retouching_natural,
    Nicho.massagem => Icons.spa_outlined,
    Nicho.lavaRapido => Icons.local_car_wash_outlined,
    Nicho.banhoTosa => Icons.pets_outlined,
  };
}
