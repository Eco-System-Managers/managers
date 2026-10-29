import 'package:flutter/material.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/widgets/selo_de_status.dart';

import '../../domain/entities/contrato.dart';

// o status do contrato como selo: a cor diz o que falta fazer. pendente é
// atenção (warning), enviado é neutro (ink), assinado é success e recusado,
// danger. a cor vai no texto, sobre fundo neutro com borda fina
class StatusContratoChip extends StatelessWidget {
  const StatusContratoChip({super.key, required this.status});

  final StatusContrato status;

  static Color cor(StatusContrato status, BrandColors cores) {
    return switch (status) {
      StatusContrato.pendente => cores.warning,
      StatusContrato.enviado => cores.ink,
      StatusContrato.assinado => cores.success,
      StatusContrato.recusado => cores.danger,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SeloDeStatus(
      texto: status.nome,
      cor: cor(status, BrandColors.of(context)),
    );
  }
}
