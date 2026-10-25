import 'package:dio/dio.dart';

// o que a busca por CEP devolve. o número não vem: quem informa é a pessoa
class EnderecoCep {
  const EnderecoCep({
    required this.cep,
    required this.logradouro,
    required this.bairro,
    required this.cidade,
    required this.uf,
  });

  // só os dígitos
  final String cep;
  final String logradouro;
  final String bairro;
  final String cidade;
  final String uf;
}

class CepNaoEncontradoException implements Exception {
  const CepNaoEncontradoException();
}

// busca de endereço por CEP no ViaCEP (viacep.com.br): serviço público, sem
// chave, fora da nossa API. fica no core porque o onboarding e a ficha do
// cliente usam. tem Dio próprio: não leva token nem a base URL da API
class ViaCepDataSource {
  ViaCepDataSource([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://viacep.com.br/ws/',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );

  final Dio _dio;

  Future<EnderecoCep> buscar(String cep) async {
    final digitos = cep.replaceAll(RegExp(r'\D'), '');
    // o ViaCEP responde 400 para formato errado; aqui vira "não encontrado"
    // antes de ir à rede
    if (digitos.length != 8) throw const CepNaoEncontradoException();

    final response = await _dio.get<Map<String, dynamic>>('$digitos/json/');
    final json = response.data;

    // CEP bem formado mas inexistente volta 200 com {"erro": true}
    // (em versões antigas, "true" como texto)
    if (json == null || json['erro'] == true || json['erro'] == 'true') {
      throw const CepNaoEncontradoException();
    }

    return EnderecoCep(
      cep: digitos,
      logradouro: json['logradouro'] as String? ?? '',
      bairro: json['bairro'] as String? ?? '',
      cidade: json['localidade'] as String? ?? '',
      uf: json['uf'] as String? ?? '',
    );
  }
}
