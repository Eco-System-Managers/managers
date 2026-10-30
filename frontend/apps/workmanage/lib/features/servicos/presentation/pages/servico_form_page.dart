import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/utils/dinheiro.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/confirmar_dialog.dart';
import 'package:managers/core/widgets/dinheiro_input_formatter.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/folha.dart';
import 'package:managers/features/clientes/domain/entities/porte.dart';
import 'package:managers/features/clientes/presentation/widgets/escolha_de_porte.dart';
import 'package:managers/features/empresa/domain/entities/nicho.dart';
import 'package:managers/features/empresa/presentation/widgets/nicho_visual.dart';
import 'package:validatorless/validatorless.dart';

import '../../domain/entities/servico.dart';
import '../../servicos_provider.dart';
import '../providers/servico_form_provider.dart';

// cria ou edita um serviço. fecha com true quando salvou ou inativou, para
// a lista recarregar. os nomes dos campos de erro são os do contrato
class ServicoFormPage extends ConsumerStatefulWidget {
  const ServicoFormPage({super.key, this.id, this.nichoInicial});

  // null = novo
  final int? id;

  // a pasta de onde o serviço novo foi criado; já vem escolhida
  final Nicho? nichoInicial;

  @override
  ConsumerState<ServicoFormPage> createState() => _ServicoFormPageState();
}

class _ServicoFormPageState extends ConsumerState<ServicoFormPage> {
  // o required do Validatorless aceita só espaços; isto exige um caractere
  static final _notBlank = RegExp(r'\S');

  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _duracaoController = TextEditingController();
  final _precoController = TextEditingController();
  final _taxaController = TextEditingController();

  TipoTaxaCancelamento? _taxaTipo;
  final Set<int> _colaboradores = {};
  late Nicho? _nicho = widget.nichoInicial;

  // null = qualquer porte
  Porte? _porte;

  // os campos são preenchidos uma vez, quando o serviço chega
  bool _preenchido = false;

  ServicoFormProvider get _provider => ref.read(servicoFormProvider(widget.id));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _provider.carregar();
    });
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _duracaoController.dispose();
    _precoController.dispose();
    _taxaController.dispose();
    super.dispose();
  }

  void _preencher(Servico servico) {
    _nomeController.text = servico.nome;
    _descricaoController.text = servico.descricao;
    _duracaoController.text = '${servico.duracao}';
    _precoController.text = DinheiroInputFormatter.formatar(servico.preco);
    _taxaTipo = servico.taxaCancelamentoTipo;
    _taxaController.text = switch (servico.taxaCancelamentoTipo) {
      TipoTaxaCancelamento.valor => DinheiroInputFormatter.formatar(
        servico.taxaCancelamentoValor,
      ),
      TipoTaxaCancelamento.percentual =>
        servico.taxaCancelamentoValor.toStringAsFixed(0),
      null => '',
    };
    _colaboradores
      ..clear()
      ..addAll(servico.colaboradores);
    // serviço de um nicho que o negócio deixou volta sem pasta: a pessoa
    // escolhe uma das atuais
    _nicho = _provider.nichos.contains(servico.nicho) ? servico.nicho : null;
    _porte = servico.porte;
  }

  // com um nicho só, o serviço fica nele (inclusive o que veio de um nicho
  // que saiu)
  Nicho? _nichoParaSalvar() {
    final nichos = _provider.nichos;
    return nichos.length == 1 ? nichos.first : _nicho;
  }

  Decimal? _taxaValor() {
    return switch (_taxaTipo) {
      TipoTaxaCancelamento.valor => dinheiroDoTexto(_taxaController.text),
      TipoTaxaCancelamento.percentual => Decimal.tryParse(
        _taxaController.text.replaceAll(',', '.'),
      ),
      null => null,
    };
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    await _provider.salvar(
      Servico(
        nome: _nomeController.text.trim(),
        nicho: _nichoParaSalvar(),
        porte: _provider.escolhePorte ? _porte : null,
        descricao: _descricaoController.text.trim(),
        duracao: int.parse(_duracaoController.text),
        preco: dinheiroDoTexto(_precoController.text)!,
        taxaCancelamentoTipo: _taxaTipo,
        taxaCancelamentoValor: _taxaValor(),
        ativo: _provider.servico?.ativo ?? true,
        colaboradores: _colaboradores.toList()..sort(),
      ),
    );
  }

  Future<void> _alterarAtivo(bool ativo) async {
    final ok = await confirmar(
      context,
      titulo: ativo ? 'Reativar serviço' : 'Inativar serviço',
      mensagem: ativo
          ? 'Ele volta a aparecer para os clientes.'
          : 'Ele some da vitrine na hora. Os agendamentos já feitos continuam.',
      textoConfirmar: ativo ? 'Reativar' : 'Inativar',
      destrutivo: !ativo,
    );
    if (!ok || !mounted) return;
    await _provider.alterarAtivo(ativo);
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(servicoFormProvider(widget.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(provider.ehNovo ? 'Novo serviço' : 'Editar serviço'),
      ),
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

          final servico = provider.servico;
          if (!_preenchido && servico != null) {
            _preencher(servico);
            _preenchido = true;
          }

          return _formulario(context, provider, servico);
        },
      ),
    );
  }

  Widget _formulario(
    BuildContext context,
    ServicoFormProvider provider,
    Servico? servico,
  ) {
    final colors = Theme.of(context).colorScheme;
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;

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

          TextFormField(
            controller: _nomeController,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            validator: Validatorless.regex(_notBlank, 'Informe o nome'),
            forceErrorText: provider.erroDoCampo('nome'),
            onChanged: (_) => provider.limparErroDoCampo('nome'),
            decoration: const InputDecoration(labelText: 'Nome'),
          ),

          if (provider.escolheNicho) ...[
            const SizedBox(height: BrandSpacing.space4),
            DropdownButtonFormField<Nicho>(
              // a pasta da URL pode não ser mais do negócio
              initialValue: provider.nichos.contains(_nicho) ? _nicho : null,
              isExpanded: true,
              items: [
                for (final nicho in provider.nichos)
                  DropdownMenuItem(value: nicho, child: Text(nicho.nome)),
              ],
              onChanged: (nicho) => setState(() {
                _nicho = nicho;
                provider.limparErroDoCampo('nicho');
              }),
              validator: (nicho) => nicho == null ? 'Escolha o nicho' : null,
              forceErrorText: provider.erroDoCampo('nicho'),
              decoration: const InputDecoration(
                labelText: 'Nicho',
                helperText: 'A pasta em que o serviço aparece',
                prefixIcon: Icon(Icons.folder_rounded),
              ),
            ),
          ],

          if (provider.escolhePorte) ...[
            const SizedBox(height: BrandSpacing.space4),
            DropdownButtonFormField<Porte?>(
              initialValue: _porte,
              isExpanded: true,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Qualquer porte'),
                ),
                for (final porte in provider.portes)
                  DropdownMenuItem(value: porte, child: Text(porte.rotulo)),
              ],
              onChanged: (porte) => setState(() {
                _porte = porte;
                provider.limparErroDoCampo('porte');
              }),
              forceErrorText: provider.erroDoCampo('porte'),
              decoration: const InputDecoration(
                labelText: 'Porte',
                helperText: 'Com um porte, o serviço só aparece para ele',
                prefixIcon: Icon(Icons.straighten_rounded),
              ),
            ),
          ],

          const SizedBox(height: BrandSpacing.space4),

          TextFormField(
            controller: _descricaoController,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            forceErrorText: provider.erroDoCampo('descricao'),
            onChanged: (_) => provider.limparErroDoCampo('descricao'),
            decoration: const InputDecoration(
              labelText: 'Descrição (opcional)',
            ),
          ),

          const SizedBox(height: BrandSpacing.space4),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // duração: a API aceita de 1 a 360 minutos
              Expanded(
                child: TextFormField(
                  controller: _duracaoController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: Validatorless.multiple([
                    Validatorless.required('Informe a duração'),
                    Validatorless.between(1, 360, 'De 1 a 360 minutos'),
                  ]),
                  forceErrorText: provider.erroDoCampo('duracao'),
                  onChanged: (_) => provider.limparErroDoCampo('duracao'),
                  decoration: const InputDecoration(
                    labelText: 'Duração',
                    suffixText: 'min',
                  ),
                ),
              ),
              const SizedBox(width: BrandSpacing.space4),
              Expanded(
                child: TextFormField(
                  controller: _precoController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: const [DinheiroInputFormatter()],
                  validator: (valor) {
                    final preco = dinheiroDoTexto(valor ?? '');
                    if (preco == null || preco <= Decimal.fromInt(0)) {
                      return 'Informe o preço';
                    }
                    return null;
                  },
                  forceErrorText: provider.erroDoCampo('preco'),
                  onChanged: (_) => provider.limparErroDoCampo('preco'),
                  decoration: const InputDecoration(
                    labelText: 'Preço',
                    prefixText: 'R\$ ',
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: BrandSpacing.space5),

          Text('Taxa de cancelamento', style: textos.titleSmall),
          const SizedBox(height: BrandSpacing.space1),
          Text(
            'Cobrada só quando o cliente cancela fora do prazo. No máximo 30% do preço.',
            style: textos.bodyMedium?.copyWith(color: cores.inkMuted),
          ),
          const SizedBox(height: BrandSpacing.space3),
          SegmentedButton<TipoTaxaCancelamento?>(
            segments: const [
              ButtonSegment(value: null, label: Text('Sem taxa')),
              ButtonSegment(
                value: TipoTaxaCancelamento.valor,
                label: Text('Valor'),
              ),
              ButtonSegment(
                value: TipoTaxaCancelamento.percentual,
                label: Text('Percentual'),
              ),
            ],
            selected: {_taxaTipo},
            onSelectionChanged: (selecao) => setState(() {
              _taxaTipo = selecao.first;
              _taxaController.clear();
              provider.limparErroDoCampo('taxa_cancelamento_valor');
            }),
          ),

          if (_taxaTipo != null) ...[
            const SizedBox(height: BrandSpacing.space3),
            TextFormField(
              // a key nova recria o campo: as máscaras são formatters diferentes
              key: ValueKey(_taxaTipo),
              controller: _taxaController,
              keyboardType: TextInputType.number,
              inputFormatters: _taxaTipo == TipoTaxaCancelamento.valor
                  ? const [DinheiroInputFormatter()]
                  : [FilteringTextInputFormatter.digitsOnly],
              validator: (_) {
                final valor = _taxaValor();
                if (valor == null) return 'Informe a taxa';
                if (_taxaTipo == TipoTaxaCancelamento.percentual &&
                    valor > Decimal.fromInt(30)) {
                  return 'No máximo 30%';
                }
                return null;
              },
              forceErrorText: provider.erroDoCampo('taxa_cancelamento_valor'),
              onChanged: (_) =>
                  provider.limparErroDoCampo('taxa_cancelamento_valor'),
              decoration: InputDecoration(
                labelText: _taxaTipo == TipoTaxaCancelamento.valor
                    ? 'Valor da taxa'
                    : 'Percentual do preço',
                prefixText: _taxaTipo == TipoTaxaCancelamento.valor
                    ? 'R\$ '
                    : null,
                suffixText: _taxaTipo == TipoTaxaCancelamento.percentual
                    ? '%'
                    : null,
              ),
            ),
          ],

          const SizedBox(height: BrandSpacing.space5),

          Text('Quem executa', style: textos.titleSmall),
          const SizedBox(height: BrandSpacing.space1),
          Text(
            provider.colaboradores.isEmpty
                ? 'Sem equipe cadastrada: qualquer um executa.'
                : 'Sem ninguém marcado, qualquer um executa.',
            style: textos.bodyMedium?.copyWith(color: cores.inkMuted),
          ),
          for (final colaborador in provider.colaboradores)
            CheckboxListTile(
              value: _colaboradores.contains(colaborador.id),
              title: Text(colaborador.nome),
              subtitle: colaborador.funcao.isEmpty
                  ? null
                  : Text(colaborador.funcao),
              contentPadding: EdgeInsets.zero,
              onChanged: (marcado) => setState(() {
                if (marcado == true) {
                  _colaboradores.add(colaborador.id);
                } else {
                  _colaboradores.remove(colaborador.id);
                }
              }),
            ),

          const SizedBox(height: BrandSpacing.space5),

          FilledButton(
            onPressed: provider.isLoading ? null : _salvar,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Salvar'),
          ),

          if (servico != null) ...[
            const SizedBox(height: BrandSpacing.space3),
            OutlinedButton(
              onPressed: provider.isLoading
                  ? null
                  : () => _alterarAtivo(!servico.ativo),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: servico.ativo ? cores.danger : null,
              ),
              child: Text(servico.ativo ? 'Inativar' : 'Reativar'),
            ),
          ],
        ],
      ),
    );
  }
}
