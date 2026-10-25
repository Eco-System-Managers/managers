import 'package:flutter/material.dart';
import 'package:managers/features/empresa/presentation/widgets/dados_negocio_form.dart';

import '../providers/wizard_provider.dart';

// step 1: dados do negócio e endereço, com o formulário que as configurações
// também usam. o mapa entra numa próxima versão
class NegocioStep extends StatelessWidget {
  const NegocioStep({super.key, required this.provider});

  final WizardProvider provider;

  @override
  Widget build(BuildContext context) {
    return DadosNegocioForm(
      config: provider.config,
      buscandoCep: provider.buscandoCep,
      cepErro: provider.cepErrorMessage,
      enabled: !provider.isLoading,
      onBuscarCep: provider.buscarCep,
      textoBotao: 'Próximo',
      onSubmit: (dados) => provider.salvarNegocio(
        nome: dados.nome,
        telefone: dados.telefone,
        tipoDocumento: dados.tipoDocumento,
        documento: dados.documento,
        numero: dados.numero,
      ),
    );
  }
}
