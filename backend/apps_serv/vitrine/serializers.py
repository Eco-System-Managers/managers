from rest_framework import serializers

from .models import NegocioPublico


class NegocioPublicoSerializer(serializers.ModelSerializer):
    class Meta:
        model = NegocioPublico
        fields = ['id', 'schema_name', 'nome', 'nicho', 'tipo_agenda', 'tipo_objeto', 'cidade', 'latitude', 'longitude', 'logo_url', 'descricao']
