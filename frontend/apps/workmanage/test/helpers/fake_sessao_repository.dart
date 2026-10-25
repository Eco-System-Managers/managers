import 'package:managers/core/session/sessao.dart';
import 'package:managers/core/session/sessao_repository.dart';

// guarda a sessão em memória, no lugar do armazenamento seguro
class FakeSessaoRepository implements SessaoRepository {
  FakeSessaoRepository([this.guardada]);

  Sessao? guardada;

  @override
  Future<Sessao?> carregar() async => guardada;

  @override
  Future<void> salvar(Sessao sessao) async => guardada = sessao;

  @override
  Future<void> limpar() async => guardada = null;
}

const sessaoDeTeste = Sessao(
  access: 'access-1',
  refresh: 'refresh-1',
  schemaName: 'barbearia_central',
  empresa: 'Barbearia Central',
);

const sessaoRenovada = Sessao(
  access: 'access-2',
  refresh: 'refresh-2',
  schemaName: 'barbearia_central',
  empresa: 'Barbearia Central',
);

Map<String, dynamic> sessaoJson(Sessao sessao) => {
  'access': sessao.access,
  'refresh': sessao.refresh,
  'schema_name': sessao.schemaName,
  'empresa': sessao.empresa,
};
