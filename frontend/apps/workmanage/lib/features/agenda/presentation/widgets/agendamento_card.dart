import 'package:flutter/material.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/dinheiro.dart';

import '../../domain/entities/agendamento.dart';
import 'status_agendamento_chip.dart';

// uma linha da agenda do dia: horário, cliente, serviços, profissional,
// status e valor
class AgendamentoCard extends StatelessWidget {
  const AgendamentoCard({
    super.key,
    required this.agendamento,
    required this.onTap,
  });

  final Agendamento agendamento;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final a = agendamento;
    final servicos = a.servicos.map((s) => s.nome).join(', ');
    final detalhe = [
      if (servicos.isNotEmpty) servicos,
      if (a.colaboradorNome != null && a.colaboradorNome!.isNotEmpty)
        a.colaboradorNome!,
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 52,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatarHora(horaDe(a.dataHora)),
                    style: textos.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    formatarHora(horaDe(a.fim)),
                    style: textos.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 3,
              height: 44,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: a.status.cor(colors),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.clienteNome,
                    style: textos.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (detalhe.isNotEmpty)
                    Text(
                      detalhe,
                      style: textos.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      StatusAgendamentoChip(status: a.status),
                      const Spacer(),
                      Text(
                        formatarDinheiro(a.valorTotal),
                        style: textos.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
