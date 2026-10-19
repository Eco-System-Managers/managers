from django.dispatch import Signal

# Emitido quando o negócio remove pelo painel um cliente que veio do Service
# Manage. Quem escuta é o apps_serv, que desfaz o vínculo no schema público —
# assim o app do consumidor não segue mostrando o negócio em "Seus negócios".
# É sinal, e não import direto, para o apps_work não passar a depender do
# apps_serv (hoje a dependência só existe no sentido contrário).
cliente_servicemanage_removido = Signal()
