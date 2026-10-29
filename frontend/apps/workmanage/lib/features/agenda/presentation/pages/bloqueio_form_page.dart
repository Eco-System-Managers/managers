import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/widgets/campo_data.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/folha.dart';
import 'package:managers/features/usuarios/domain/entities/colaborador.dart';
import 'package:validatorless/validatorless.dart';

import '../../agenda_provider.dart';
import '../../domain/entities/bloqueio.dart';
import '../providers/bloqueio_form_provider.dart';

// bloqueia um período da agenda: de quem, por quanto tempo (um dia, uma
// semana, um mês ou fixo), a partir de quando e em que horário. fecha com
// true quando bloqueou, para a agenda recarregar
class BloqueioFormPage extends ConsumerStatefulWidget {
  const BloqueioFormPage({super.key, this.dataInicial, this.colaboradorId});

  // o dia e o profissional abertos na agenda
  final DateTime? dataInicial;
  final int? colaboradorId;

  BloqueioFormArgs get args =>
      BloqueioFormArgs(data: dataInicial, colaboradorId: colaboradorId);

  @override
  ConsumerState<BloqueioFormPage> createState() => _BloqueioFormPageState();
}

class _BloqueioFormPageState extends ConsumerState<BloqueioFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _motivoController = TextEditingController();

  BloqueioFormProvider get _provider =>
      ref.read(bloqueioFormProvider(widget.args));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _provider.carregar();
    });
  }

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    await _provider.salvar(motivo: _motivoController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(bloqueioFormProvider(widget.args));

    return Scaffold(
      appBar: AppBar(title: const Text('Bloquear horário')),
      body: ListenableBuilder(
        listenable: provider,
        builder: (context, _) {
          if (provider.salvo) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.pop(true);
            });
          }

          if (!provider.carregado) {
            final erro = provider.erroAoCarregar;
            if (erro != null) {
              return EstadoErro(
                mensagem: erro.message,
                onTentarDeNovo: provider.carregar,
              );
            }
            return const Carregando();
          }

          return _formulario(context, provider);
        },
      ),
    );
  }

  Widget _formulario(BuildContext context, BloqueioFormProvider provider) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final hoje = provider.hoje;
    final dataFim = provider.dataFim;
    final erroHorario =
        provider.erroDoCampo('hora_fim') ??
        provider.erroDoCampo('hora_inicio') ??
        (provider.horarioValido ? null : 'O fim vem depois do início');

    return Form(
      key: _formKey,
      child: ListView(
        padding: paddingDaPagina(context),
        children: [
          if (provider.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(BrandSpacing.space3),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BrandRadius.mdAll,
              ),
              child: Text(
                provider.errorMessage!,
                style: textos.bodyMedium?.copyWith(
                  color: colors.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(height: BrandSpacing.space4),
          ],

          DropdownButtonFormField<Colaborador>(
            key: ValueKey('colaborador-${provider.colaborador?.id}'),
            initialValue: provider.colaborador,
            isExpanded: true,
            items: [
              for (final c in provider.colaboradores)
                DropdownMenuItem(
                  value: c,
                  child: Text(c.nome, overflow: TextOverflow.ellipsis),
                ),
            ],
            // o parceiro só bloqueia a própria agenda
            onChanged: provider.colaboradorFixo
                ? null
                : provider.selecionarColaborador,
            validator: (c) => c == null ? 'Escolha o profissional' : null,
            decoration: InputDecoration(
              labelText: 'Profissional',
              prefixIcon: const Icon(Icons.badge_rounded),
              errorText: provider.erroDoCampo('colaborador'),
            ),
          ),

          const SizedBox(height: BrandSpacing.space5),

          Text('Por quanto tempo', style: textos.titleSmall),
          const SizedBox(height: BrandSpacing.space2),
          SegmentedButton<PeriodoDoBloqueio>(
            segments: const [
              ButtonSegment(
                value: PeriodoDoBloqueio.umDia,
                label: Text('Um dia'),
              ),
              ButtonSegment(
                value: PeriodoDoBloqueio.umaSemana,
                label: Text('Semana'),
              ),
              ButtonSegment(value: PeriodoDoBloqueio.umMes, label: Text('Mês')),
              ButtonSegment(value: PeriodoDoBloqueio.fixo, label: Text('Fixo')),
            ],
            selected: {provider.periodo},
            showSelectedIcon: false,
            onSelectionChanged: (s) => provider.selecionarPeriodo(s.first),
          ),

          const SizedBox(height: BrandSpacing.space4),

          CampoData(
            valor: provider.dataInicio,
            onChanged: (d) {
              if (d != null) provider.selecionarDataInicio(d);
            },
            label: 'A partir de',
            limpavel: false,
            primeiraData: hoje,
            ultimaData: DateTime(hoje.year + 1, hoje.month, hoje.day),
            forceErrorText: provider.erroDoCampo('data_inicio'),
          ),
          const SizedBox(height: BrandSpacing.space2),
          Text(
            dataFim == null
                ? 'Vale todos os dias, sem data para acabar.'
                : mesmoDia(dataFim, provider.dataInicio)
                ? 'Só neste dia.'
                : 'Até ${formatarData(dataFim)}.',
            style: textos.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),

          const SizedBox(height: BrandSpacing.space4),

          SwitchListTile(
            value: provider.diaInteiro,
            onChanged: provider.alterarDiaInteiro,
            title: const Text('Dia inteiro'),
            contentPadding: EdgeInsets.zero,
          ),
          if (!provider.diaInteiro) ...[
            const SizedBox(height: BrandSpacing.space2),
            Row(
              children: [
                Expanded(
                  child: _HoraButton(
                    rotulo: 'Das',
                    hora: provider.horaInicio,
                    onChanged: provider.selecionarHoraInicio,
                  ),
                ),
                const SizedBox(width: BrandSpacing.space3),
                Expanded(
                  child: _HoraButton(
                    rotulo: 'Até',
                    hora: provider.horaFim,
                    onChanged: provider.selecionarHoraFim,
                  ),
                ),
              ],
            ),
            if (erroHorario != null) ...[
              const SizedBox(height: BrandSpacing.space2),
              Text(
                erroHorario,
                style: textos.bodySmall?.copyWith(color: colors.error),
              ),
            ],
          ],

          const SizedBox(height: BrandSpacing.space5),

          TextFormField(
            controller: _motivoController,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 60,
            validator: Validatorless.max(60, 'No máximo 60 caracteres'),
            forceErrorText: provider.erroDoCampo('motivo'),
            decoration: const InputDecoration(
              labelText: 'Motivo (opcional)',
              hintText: 'Almoço, férias, consulta...',
            ),
          ),

          const SizedBox(height: BrandSpacing.space5),

          FilledButton(
            onPressed: provider.isLoading || !provider.horarioValido
                ? null
                : _salvar,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Bloquear'),
          ),
        ],
      ),
    );
  }
}

// botão que mostra a hora e abre o relógio do sistema para trocar
class _HoraButton extends StatelessWidget {
  const _HoraButton({
    required this.rotulo,
    required this.hora,
    required this.onChanged,
  });

  final String rotulo;
  final Hora hora;
  final ValueChanged<Hora> onChanged;

  Future<void> _escolher(BuildContext context) async {
    // o TimeOfDay é do Flutter: a conversão fica aqui, na presentation
    final escolhida = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hora.hora, minute: hora.minuto),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (escolhida != null) {
      onChanged((hora: escolhida.hour, minuto: escolhida.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _escolher(context),
      icon: const Icon(Icons.schedule_rounded, size: 18),
      label: Text('$rotulo ${formatarHora(hora)}'),
    );
  }
}
