import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/confirmar_dialog.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:validatorless/validatorless.dart';

import '../../contratos_provider.dart';
import '../../domain/entities/modelo_contrato.dart';
import '../providers/modelo_form_provider.dart';

// cria ou edita um modelo: título e texto livre, com os chips que inserem
// as variáveis no cursor. fecha com true quando salvou ou inativou
class ModeloFormPage extends ConsumerStatefulWidget {
  const ModeloFormPage({super.key, this.id});

  // null = novo
  final int? id;

  @override
  ConsumerState<ModeloFormPage> createState() => _ModeloFormPageState();
}

class _ModeloFormPageState extends ConsumerState<ModeloFormPage> {
  // o required do Validatorless aceita só espaços; isto exige um caractere
  static final _notBlank = RegExp(r'\S');

  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _corpoController = TextEditingController();
  final _corpoFocus = FocusNode();

  // os campos são preenchidos uma vez, quando o modelo chega
  bool _preenchido = false;

  ModeloFormProvider get _provider => ref.read(modeloFormProvider(widget.id));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _provider.carregar();
    });
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _corpoController.dispose();
    _corpoFocus.dispose();
    super.dispose();
  }

  // a variável entra onde está o cursor (ou no fim), no lugar da seleção
  void _inserir(String variavel) {
    final texto = '{{$variavel}}';
    final valor = _corpoController.value;
    final selecao = valor.selection;
    final inicio = selecao.isValid ? selecao.start : valor.text.length;
    final fim = selecao.isValid ? selecao.end : valor.text.length;
    _corpoController.value = TextEditingValue(
      text: valor.text.replaceRange(inicio, fim, texto),
      selection: TextSelection.collapsed(offset: inicio + texto.length),
    );
    _corpoFocus.requestFocus();
    _provider.limparErroDoCampo('corpo');
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    await _provider.salvar(
      ModeloContrato(
        titulo: _tituloController.text.trim(),
        corpo: _corpoController.text.trim(),
        ativo: _provider.modelo?.ativo ?? true,
      ),
    );
  }

  Future<void> _alterarAtivo(bool ativo) async {
    final ok = await confirmar(
      context,
      titulo: ativo ? 'Reativar modelo' : 'Inativar modelo',
      mensagem: ativo
          ? 'Ele volta a aparecer na hora de gerar contrato.'
          : 'Ele some da geração. Os contratos já gerados continuam.',
      textoConfirmar: ativo ? 'Reativar' : 'Inativar',
      destrutivo: !ativo,
    );
    if (!ok || !mounted) return;
    await _provider.alterarAtivo(ativo);
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(modeloFormProvider(widget.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(provider.ehNovo ? 'Novo modelo' : 'Editar modelo'),
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

          final modelo = provider.modelo;
          if (!_preenchido && modelo != null) {
            _tituloController.text = modelo.titulo;
            _corpoController.text = modelo.corpo;
            _preenchido = true;
          }

          return _formulario(context, provider, modelo);
        },
      ),
    );
  }

  Widget _formulario(
    BuildContext context,
    ModeloFormProvider provider,
    ModeloContrato? modelo,
  ) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (provider.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                provider.errorMessage!,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
            const SizedBox(height: 16),
          ],

          TextFormField(
            controller: _tituloController,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            validator: Validatorless.regex(_notBlank, 'Informe o título'),
            forceErrorText: provider.erroDoCampo('titulo'),
            onChanged: (_) => provider.limparErroDoCampo('titulo'),
            decoration: const InputDecoration(
              labelText: 'Título',
              hintText: 'Ex.: Contrato de prestação de serviço',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 24),
          Text('Variáveis', style: textos.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Toque para inserir no texto. Ao gerar, viram os dados do cliente.',
            style: textos.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final (variavel, rotulo) in ModeloContrato.variaveis)
                ActionChip(
                  label: Text(rotulo),
                  avatar: const Icon(Icons.data_object, size: 16),
                  onPressed: () => _inserir(variavel),
                ),
            ],
          ),

          const SizedBox(height: 16),
          TextFormField(
            controller: _corpoController,
            focusNode: _corpoFocus,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
            minLines: 10,
            maxLines: null,
            validator: Validatorless.regex(_notBlank, 'Escreva o texto'),
            forceErrorText: provider.erroDoCampo('corpo'),
            onChanged: (_) => provider.limparErroDoCampo('corpo'),
            decoration: const InputDecoration(
              labelText: 'Texto do contrato',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 24),
          FilledButton(
            onPressed: provider.isLoading ? null : _salvar,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Salvar'),
          ),

          if (modelo != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: provider.isLoading
                  ? null
                  : () => _alterarAtivo(!modelo.ativo),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: modelo.ativo ? colors.error : null,
              ),
              child: Text(modelo.ativo ? 'Inativar' : 'Reativar'),
            ),
          ],
        ],
      ),
    );
  }
}
