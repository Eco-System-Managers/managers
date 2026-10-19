import threading

from django.db import connections, transaction
from django.tasks.backends.immediate import ImmediateBackend


class ThreadBackend(ImmediateBackend):
    """Executa cada task numa thread própria, depois do commit da transação.

    Serve para tirar trabalho lento ou que pode falhar (como enviar e-mail) do
    caminho da resposta, enquanto o projeto não tem um worker. Quando tiver,
    basta trocar o BACKEND em TASKS — quem chama `.enqueue()` não muda.

    Não há fila nem nova tentativa: se o processo cair, a task se perde. O
    resultado (falha incluída) fica só no TaskResult, como no ImmediateBackend.
    """

    def _execute_task(self, task_result):
        def executar():
            try:
                super(ThreadBackend, self)._execute_task(task_result)
            finally:
                # A thread abre conexões próprias; sem fechar, elas vazam.
                connections.close_all()

        transaction.on_commit(lambda: threading.Thread(target=executar, daemon=True).start())
