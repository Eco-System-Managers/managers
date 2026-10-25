import 'package:flutter/material.dart';
import 'package:managers/core/widgets/mascara_formatter.dart';
import 'package:validatorless/validatorless.dart';

import '../../domain/entities/empresa_config.dart';

// o que o formulário entrega no submit, já sem máscara
class DadosNegocio {
  const DadosNegocio({
    required this.nome,
    required this.telefone,
    required this.tipoDocumento,
    required this.documento,
    required this.numero,
  });

  final String nome;
  final String telefone;
  final TipoDocumento tipoDocumento;
  final String documento;
  final String numero;
}

// o formulário dos dados do negócio, o mesmo no step 1 do onboarding e na
// tela de configurações. quem usa cuida da busca de CEP (o endereço achado
// chega pela config) e recebe os valores validados no submit
class DadosNegocioForm extends StatefulWidget {
  const DadosNegocioForm({
    super.key,
    required this.config,
    required this.buscandoCep,
    required this.cepErro,
    required this.enabled,
    required this.onBuscarCep,
    required this.onSubmit,
    required this.textoBotao,
  });

  // valores iniciais e o endereço que a busca de CEP encontrou
  final EmpresaConfig config;
  final bool buscandoCep;
  final String? cepErro;
  final bool enabled;
  final ValueChanged<String> onBuscarCep;
  final ValueChanged<DadosNegocio> onSubmit;
  final String textoBotao;

  @override
  State<DadosNegocioForm> createState() => _DadosNegocioFormState();
}

class _DadosNegocioFormState extends State<DadosNegocioForm> {
  // o required do Validatorless aceita só espaços; isto exige um caractere
  static final _notBlank = RegExp(r'\S');

  final _formKey = GlobalKey<FormState>();

  final _telefoneMascara = MascaraFormatter.dinamica(MascaraFormatter.telefone);
  final _cepMascara = MascaraFormatter(MascaraFormatter.cep);
  final _cpfMascara = MascaraFormatter(MascaraFormatter.cpf);
  final _cnpjMascara = MascaraFormatter(MascaraFormatter.cnpj);

  late final TextEditingController _nomeController;
  late final TextEditingController _telefoneController;
  late final TextEditingController _documentoController;
  late final TextEditingController _cepController;
  late final TextEditingController _numeroController;

  late TipoDocumento _tipoDocumento;

  // evita buscar de novo o mesmo CEP a cada letra digitada depois dele
  String _ultimoCepBuscado = '';

  @override
  void initState() {
    super.initState();
    // os campos começam com o que já foi salvo (o nome vem do cadastro)
    final config = widget.config;
    _tipoDocumento = config.tipoDocumento ?? TipoDocumento.cpf;
    _nomeController = TextEditingController(text: config.nome);
    _telefoneController = TextEditingController(
      text: _telefoneMascara.aplicar(config.telefone),
    );
    _documentoController = TextEditingController(
      text: _documentoMascara.aplicar(config.documento),
    );
    _cepController = TextEditingController(
      text: _cepMascara.aplicar(config.cep),
    );
    _numeroController = TextEditingController(text: config.numero);
    _ultimoCepBuscado = config.cep;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _telefoneController.dispose();
    _documentoController.dispose();
    _cepController.dispose();
    _numeroController.dispose();
    super.dispose();
  }

  MascaraFormatter get _documentoMascara =>
      _tipoDocumento == TipoDocumento.cpf ? _cpfMascara : _cnpjMascara;

  // o endereço só aparece depois que a busca achou o CEP
  bool get _temEndereco => widget.config.endereco.isNotEmpty;

  void _trocarTipoDocumento(TipoDocumento tipo) {
    setState(() {
      _tipoDocumento = tipo;
      // o número digitado não vale para o outro tipo de documento
      _documentoController.clear();
    });
  }

  // busca assim que o CEP fica completo, sem precisar de botão
  void _onCepChanged(String value) {
    final cep = value.replaceAll(RegExp(r'\D'), '');
    if (cep.length != 8 || cep == _ultimoCepBuscado) return;
    _ultimoCepBuscado = cep;
    widget.onBuscarCep(cep);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    // o CEP pode estar válido e a busca ainda não ter achado o endereço
    if (!_temEndereco) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um CEP válido para continuar')),
      );
      return;
    }

    widget.onSubmit(
      DadosNegocio(
        nome: _nomeController.text.trim(),
        telefone: _soDigitos(_telefoneController.text),
        tipoDocumento: _tipoDocumento,
        documento: _soDigitos(_documentoController.text),
        numero: _numeroController.text.trim(),
      ),
    );
  }

  // máscaras ficam na tela; o backend guarda só os dígitos
  String _soDigitos(String valor) => valor.replaceAll(RegExp(r'\D'), '');

  @override
  Widget build(BuildContext context) {
    final config = widget.config;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // nome da empresa
          TextFormField(
            controller: _nomeController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: Validatorless.regex(_notBlank, 'Informe a empresa'),
            decoration: const InputDecoration(
              labelText: 'Nome da empresa',
              prefixIcon: Icon(Icons.business_outlined),
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          // telefone
          TextFormField(
            controller: _telefoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [_telefoneMascara],
            validator: Validatorless.multiple([
              Validatorless.required('Informe o telefone'),
              Validatorless.phone('Telefone inválido'),
            ]),
            decoration: const InputDecoration(
              labelText: 'Telefone',
              hintText: '(00) 00000-0000',
              prefixIcon: Icon(Icons.phone_outlined),
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          // tipo de documento: troca a máscara e a validação do campo abaixo
          SegmentedButton<TipoDocumento>(
            segments: const [
              ButtonSegment(value: TipoDocumento.cpf, label: Text('CPF')),
              ButtonSegment(value: TipoDocumento.cnpj, label: Text('CNPJ')),
            ],
            selected: {_tipoDocumento},
            onSelectionChanged: (selecao) =>
                _trocarTipoDocumento(selecao.first),
          ),

          const SizedBox(height: 16),

          // documento
          TextFormField(
            // a key nova recria o campo: as máscaras de CPF e CNPJ são
            // formatters diferentes
            key: ValueKey(_tipoDocumento),
            controller: _documentoController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [_documentoMascara],
            validator: _tipoDocumento == TipoDocumento.cpf
                ? Validatorless.multiple([
                    Validatorless.required('Informe o CPF'),
                    Validatorless.cpf('CPF inválido'),
                  ])
                : Validatorless.multiple([
                    Validatorless.required('Informe o CNPJ'),
                    Validatorless.cnpj('CNPJ inválido'),
                  ]),
            decoration: InputDecoration(
              labelText: _tipoDocumento == TipoDocumento.cpf ? 'CPF' : 'CNPJ',
              prefixIcon: const Icon(Icons.badge_outlined),
              border: const OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          // CEP: busca o endereço sozinho quando completa os 8 dígitos
          TextFormField(
            controller: _cepController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [_cepMascara],
            onChanged: _onCepChanged,
            validator: Validatorless.multiple([
              Validatorless.required('Informe o CEP'),
              Validatorless.cep('CEP inválido'),
            ]),
            decoration: InputDecoration(
              labelText: 'CEP',
              hintText: '00000-000',
              prefixIcon: const Icon(Icons.location_on_outlined),
              border: const OutlineInputBorder(),
              // erro da busca (ex.: CEP não encontrado), separado do validator
              errorText: widget.cepErro,
              suffixIcon: widget.buscandoCep
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
          ),

          // endereço encontrado + número: só depois que a busca achou o CEP
          if (_temEndereco) ...[
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(config.endereco),
                subtitle: Text('${config.cidade} - ${config.uf}'),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _numeroController,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: Validatorless.regex(_notBlank, 'Informe o número'),
              decoration: const InputDecoration(
                labelText: 'Número do estabelecimento',
                prefixIcon: Icon(Icons.pin_outlined),
                border: OutlineInputBorder(),
              ),
            ),
          ],

          const SizedBox(height: 24),

          FilledButton(
            onPressed: widget.enabled ? _submit : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(widget.textoBotao),
          ),
        ],
      ),
    );
  }
}
