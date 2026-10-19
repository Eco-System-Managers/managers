from django.dispatch import Signal

# Emitido quando o negócio marca ou desfaz falta num atendimento da esteira.
# Quem escuta é o apps_serv, que espelha o estado no AgendamentoConsumidor do
# schema público — o status da esteira normalmente é lido ao vivo da coluna do
# quadro, mas falta não é coluna, então precisa ser empurrada.
# É sinal, e não import direto, para o apps_work não passar a depender do
# apps_serv (a dependência só existe no sentido contrário).
atendimento_kanban_falta_alterada = Signal()
