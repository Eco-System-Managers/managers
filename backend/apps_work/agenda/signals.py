from django.dispatch import Signal

# Emitido quando o status de um Agendamento muda no painel. Quem escuta é o
# apps_serv, que espelha o novo status no AgendamentoConsumidor do schema
# público — sem isso o cliente continua vendo "agendado" no app depois de o
# negócio marcar falta, concluir ou reativar.
# É sinal, e não import direto, para o apps_work não passar a depender do
# apps_serv (a dependência só existe no sentido contrário).
agendamento_status_alterado = Signal()
