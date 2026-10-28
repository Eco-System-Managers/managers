import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/widgets/campo_data.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/folha.dart';
import 'package:managers/core/widgets/mascara_formatter.dart';
import 'package:validatorless/validatorless.dart';

import '../../clientes_provider.dart';
import '../../domain/entities/cliente.dart';
import '../providers/cliente_form_provider.dart';

// cria ou edita um cliente. fecha devolvendo o cliente salvo (quem abriu a
// partir de uma busca já o seleciona). para quem veio do app, os campos
// espelhados ficam só leitura: a API ignoraria a mudança
class ClienteFormPage extends ConsumerStatefulWidget {
  const ClienteFormPage({
    super.key,
    this.id,
    this.nomeInicial = '',
    this.telefoneInicial = '',
  });

  // null = novo
  final int? id;

  // o que foi digitado numa busca sem resultado: já entra no campo
  final String nomeInicial;
  final String telefoneInicial;

  @override
  ConsumerState<ClienteFormPage> createState() => _ClienteFormPageState();
}

class _ClienteFormPageState extends ConsumerState<ClienteFormPage> {
  // o required do Validatorless aceita só espaços; isto exige um caractere
  static final _notBlank = RegExp(r'\S');
  static final _emailPattern = RegExp(r'^\s*[^@\s]+@[^@\s]+\.[^@\s]+\s*$');

  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _cpfController = TextEditingController();
  final _cepController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _numeroController = TextEditingController();
  final _observacaoController = TextEditingController();
  final _alergiaController = TextEditingController();

  final _telefoneMascara = MascaraFormatter.dinamica(MascaraFormatter.telefone);
  final _cpfMascara = MascaraFormatter(MascaraFormatter.cpf);
  final _cepMascara = MascaraFormatter(MascaraFormatter.cep);

  DateTime? _dataNascimento;

  // evita buscar de novo o mesmo CEP a cada letra digitada depois dele
  String _ultimoCepBuscado = '';

  // os campos são preenchidos uma vez, quando o cliente chega
  bool _preenchido = false;

  ClienteFormProvider get _provider => ref.read(clienteFormProvider(widget.id));

  @override
  void initState() {
    super.initState();
    _nomeController.text = widget.nomeInicial;
    _telefoneController.text = _telefoneMascara.aplicar(widget.telefoneInicial);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _provider.carregar();
    });
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _telefoneController.dispose();
    _emailController.dispose();
    _cpfController.dispose();
    _cepController.dispose();
    _enderecoController.dispose();
    _numeroController.dispose();
    _observacaoController.dispose();
    _alergiaController.dispose();
    super.dispose();
  }

  void _preencher(Cliente cliente) {
    _nomeController.text = cliente.nome;
    _telefoneController.text = _telefoneMascara.aplicar(cliente.telefone);
    _emailController.text = cliente.email;
    _cpfController.text = _cpfMascara.aplicar(cliente.cpf);
    _cepController.text = _cepMascara.aplicar(cliente.cep);
    _enderecoController.text = cliente.endereco;
    _numeroController.text = cliente.numeroEndereco;
    _observacaoController.text = cliente.observacao;
    _alergiaController.text = cliente.alergia;
    _dataNascimento = cliente.dataNascimento;
    _ultimoCepBuscado = cliente.cep;
  }

  // busca assim que o CEP fica completo e preenche o endereço, que a
  // pessoa pode corrigir
  Future<void> _onCepChanged(String value) async {
    final cep = _soDigitos(value);
    if (cep.length != 8 || cep == _ultimoCepBuscado) return;
    _ultimoCepBuscado = cep;
    final endereco = await _provider.buscarCep(cep);
    if (endereco != null && mounted) {
      _enderecoController.text = endereco.endereco;
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final atual = _provider.cliente;
    await _provider.salvar(
      Cliente(
        nome: _nomeController.text.trim(),
        telefone: _soDigitos(_telefoneController.text),
        email: _emailController.text.trim(),
        cpf: _soDigitos(_cpfController.text),
        dataNascimento: _dataNascimento,
        cep: _soDigitos(_cepController.text),
        endereco: _enderecoController.text.trim(),
        numeroEndereco: _numeroController.text.trim(),
        observacao: _observacaoController.text.trim(),
        alergia: _alergiaController.text.trim(),
        origem: atual?.origem ?? OrigemCliente.manual,
      ),
    );
  }

  // máscaras ficam na tela; o backend guarda só os dígitos
  String _soDigitos(String valor) => valor.replaceAll(RegExp(r'\D'), '');

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(clienteFormProvider(widget.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(provider.ehNovo ? 'Novo cliente' : 'Editar cliente'),
      ),
      body: ListenableBuilder(
        listenable: provider,
        builder: (context, _) {
          if (provider.salvo) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.pop(provider.cliente);
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

          final cliente = provider.cliente;
          if (!_preenchido && cliente != null) {
            _preencher(cliente);
            _preenchido = true;
          }

          return _formulario(context, provider, cliente);
        },
      ),
    );
  }

  Widget _formulario(
    BuildContext context,
    ClienteFormProvider provider,
    Cliente? cliente,
  ) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final cores = BrandColors.of(context);
    // quem veio do app mantém a própria ficha por lá
    final espelhado = cliente?.veioDoApp ?? false;
    final habilitado = !provider.isLoading;
    // o que vem do app aparece travado: o texto no cinza do secundário e o
    // cadeado no fim do campo, no lugar do apagado do campo desabilitado
    final estiloTravado = espelhado
        ? textos.bodyLarge?.copyWith(color: colors.onSurfaceVariant)
        : null;
    final cadeado = espelhado ? const Icon(Icons.lock_outline_rounded) : null;

    return Form(
      key: _formKey,
      child: ListView(
        padding: paddingDaPagina(context),
        children: [
          if (espelhado) ...[
            Container(
              padding: const EdgeInsets.all(BrandSpacing.space3),
              decoration: BoxDecoration(
                color: cores.blueSoft,
                borderRadius: BrandRadius.mdAll,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 20),
                  const SizedBox(width: BrandSpacing.space2),
                  Expanded(
                    child: Text(
                      'Cadastro feito pelo app: nome, telefone, CPF, '
                      'nascimento e endereço só mudam por lá. Você edita o '
                      'e-mail, a observação e as alergias.',
                      style: textos.bodyMedium?.copyWith(color: cores.ink),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: BrandSpacing.space4),
          ],

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
            enabled: habilitado && !espelhado,
            style: estiloTravado,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: Validatorless.regex(_notBlank, 'Informe o nome'),
            forceErrorText: provider.erroDoCampo('nome'),
            onChanged: (_) => provider.limparErroDoCampo('nome'),
            decoration: InputDecoration(
              labelText: 'Nome',
              prefixIcon: const Icon(Icons.person_outline_rounded),
              suffixIcon: cadeado,
            ),
          ),

          const SizedBox(height: BrandSpacing.space4),

          TextFormField(
            controller: _telefoneController,
            enabled: habilitado && !espelhado,
            style: estiloTravado,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [_telefoneMascara],
            validator: Validatorless.multiple([
              Validatorless.required('Informe o telefone'),
              Validatorless.phone('Telefone inválido'),
            ]),
            forceErrorText: provider.erroDoCampo('telefone'),
            onChanged: (_) => provider.limparErroDoCampo('telefone'),
            decoration: InputDecoration(
              labelText: 'Telefone',
              hintText: '(00) 00000-0000',
              prefixIcon: const Icon(Icons.phone_rounded),
              suffixIcon: cadeado,
            ),
          ),

          const SizedBox(height: BrandSpacing.space4),

          TextFormField(
            controller: _emailController,
            enabled: habilitado,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            // opcional: só valida se foi preenchido
            validator: (valor) => (valor ?? '').trim().isEmpty
                ? null
                : Validatorless.regex(_emailPattern, 'E-mail inválido')(valor),
            forceErrorText: provider.erroDoCampo('email'),
            onChanged: (_) => provider.limparErroDoCampo('email'),
            decoration: const InputDecoration(
              labelText: 'E-mail (opcional)',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),

          const SizedBox(height: BrandSpacing.space4),

          TextFormField(
            controller: _cpfController,
            enabled: habilitado && !espelhado,
            style: estiloTravado,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [_cpfMascara],
            validator: (valor) => (valor ?? '').trim().isEmpty
                ? null
                : Validatorless.cpf('CPF inválido')(valor),
            forceErrorText: provider.erroDoCampo('cpf'),
            onChanged: (_) => provider.limparErroDoCampo('cpf'),
            decoration: InputDecoration(
              labelText: 'CPF (opcional)',
              prefixIcon: const Icon(Icons.badge_rounded),
              suffixIcon: cadeado,
            ),
          ),

          const SizedBox(height: BrandSpacing.space4),

          // a data fica no CampoData mesmo travada: ele não aceita o estilo
          // nem o cadeado, mas é ele que valida a data no salvar
          CampoData(
            valor: _dataNascimento,
            // nascimento é longe de hoje: digitar é mais rápido que rolar o
            // calendário décadas para trás
            modo: ModoCampoData.digitacao,
            enabled: habilitado && !espelhado,
            label: 'Nascimento (opcional)',
            ultimaData: somenteData(DateTime.now()),
            forceErrorText: provider.erroDoCampo('data_nascimento'),
            onChanged: (data) => setState(() {
              _dataNascimento = data;
              provider.limparErroDoCampo('data_nascimento');
            }),
          ),

          const SizedBox(height: BrandSpacing.space4),

          TextFormField(
            controller: _cepController,
            enabled: habilitado && !espelhado,
            style: estiloTravado,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [_cepMascara],
            onChanged: (valor) {
              provider.limparErroDoCampo('cep');
              _onCepChanged(valor);
            },
            validator: (valor) => (valor ?? '').trim().isEmpty
                ? null
                : Validatorless.cep('CEP inválido')(valor),
            forceErrorText: provider.erroDoCampo('cep'),
            decoration: InputDecoration(
              labelText: 'CEP (opcional)',
              hintText: '00000-000',
              prefixIcon: const Icon(Icons.location_on_rounded),
              // erro da busca (ex.: CEP não encontrado), separado do validator
              errorText: provider.cepErrorMessage,
              suffixIcon: provider.buscandoCep
                  ? const Padding(
                      padding: EdgeInsets.all(BrandSpacing.space3),
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : cadeado,
            ),
          ),

          const SizedBox(height: BrandSpacing.space4),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _enderecoController,
                  enabled: habilitado && !espelhado,
                  style: estiloTravado,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  forceErrorText: provider.erroDoCampo('endereco'),
                  onChanged: (_) => provider.limparErroDoCampo('endereco'),
                  decoration: InputDecoration(
                    labelText: 'Endereço',
                    suffixIcon: cadeado,
                  ),
                ),
              ),
              const SizedBox(width: BrandSpacing.space3),
              Expanded(
                // estreito demais para o cadeado: o do endereço, ao lado,
                // vale para os dois
                child: TextFormField(
                  controller: _numeroController,
                  enabled: habilitado && !espelhado,
                  style: estiloTravado,
                  textInputAction: TextInputAction.next,
                  forceErrorText: provider.erroDoCampo('numero_endereco'),
                  onChanged: (_) =>
                      provider.limparErroDoCampo('numero_endereco'),
                  decoration: const InputDecoration(labelText: 'Nº'),
                ),
              ),
            ],
          ),

          const SizedBox(height: BrandSpacing.space4),

          TextFormField(
            controller: _observacaoController,
            enabled: habilitado,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            forceErrorText: provider.erroDoCampo('observacao'),
            onChanged: (_) => provider.limparErroDoCampo('observacao'),
            decoration: const InputDecoration(
              labelText: 'Observação',
              alignLabelWithHint: true,
            ),
          ),

          const SizedBox(height: BrandSpacing.space4),

          TextFormField(
            controller: _alergiaController,
            enabled: habilitado,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            forceErrorText: provider.erroDoCampo('alergia'),
            onChanged: (_) => provider.limparErroDoCampo('alergia'),
            decoration: const InputDecoration(
              labelText: 'Alergias',
              hintText: 'Ex.: amônia, látex',
              alignLabelWithHint: true,
            ),
          ),

          const SizedBox(height: BrandSpacing.space5),

          FilledButton(
            onPressed: habilitado ? _salvar : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
