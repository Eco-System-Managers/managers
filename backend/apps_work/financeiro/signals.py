from django.dispatch import Signal

# Emitido no fim do `cobrar` dos dois modos de agenda (agenda/services.py e
# kanban/services.py) com o que a cobrança decidiu: o serviço feito de verdade
# (se foi trocado), o acréscimo com o motivo e o total cobrado. Quem escuta é o
# apps_serv, que espelha isso no AgendamentoConsumidor do schema público — sem
# isso o cliente continuaria vendo no app o serviço e o valor combinados na
# hora de marcar, não o que pagou no balcão. O desfazer da esteira manda o
# mesmo sinal com o acréscimo zerado.
#
# Argumentos: schema_name, agendamento_id, origem ('agenda' | 'kanban', que
# diz qual tabela do tenant o id aponta), valor_total, acrescimo,
# acrescimo_motivo e servicos — o retrato de cada serviço, no formato que o
# app do cliente guarda: [{nome, nicho, duracao, preco, taxa_cancelamento}],
# com o dinheiro em string ("45.50"). Quem monta é `snapshot_do_servico`.
#
# É sinal, e não import direto, para o apps_work não passar a depender do
# apps_serv (a dependência só existe no sentido contrário).
cobranca_registrada = Signal()
