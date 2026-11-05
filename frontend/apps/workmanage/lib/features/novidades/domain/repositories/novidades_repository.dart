// onde fica a última versão de novidades que este aparelho já mostrou
abstract class NovidadesRepository {
  // null quando nunca mostrou nenhuma
  Future<String?> ultimaVista();

  Future<void> marcarVista(String versao);
}
