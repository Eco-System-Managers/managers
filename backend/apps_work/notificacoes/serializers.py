from rest_framework import serializers
from .models import Notificacao


class NotificacaoSerializer(serializers.ModelSerializer):
    cliente_nome = serializers.CharField(source='cliente.nome', default='', read_only=True)

    class Meta:
        model = Notificacao
        fields = ['id', 'tipo', 'titulo', 'mensagem', 'cliente', 'cliente_nome', 'lida', 'criado_em']
        read_only_fields = fields
