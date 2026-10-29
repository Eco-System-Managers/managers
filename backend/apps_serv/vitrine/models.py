from django.contrib.postgres.fields import ArrayField
from django.db import models

from apps_work.clientes.models import TipoObjeto
from apps_work.empresa.models import TipoAgenda


class NegocioPublico(models.Model):
    """
    Perfil público de um negócio no schema público.
    Sincronizado a partir do EmpresaConfig do tenant correspondente.
    """
    schema_name = models.CharField(max_length=63, unique=True, db_index=True)
    nome = models.CharField(max_length=255)
    # Espelha EmpresaConfig.nichos: de 1 a 4, na ordem de exibição.
    nichos = ArrayField(models.CharField(max_length=50), default=list)
    tipo_agenda = models.CharField(max_length=20, choices=TipoAgenda.choices, default=TipoAgenda.HORARIO)
    tipo_objeto = models.CharField(max_length=20, choices=TipoObjeto.choices, null=True, blank=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6)
    longitude = models.DecimalField(max_digits=9, decimal_places=6)
    logo_url = models.URLField(blank=True)
    descricao = models.TextField(blank=True)
    cidade = models.CharField(max_length=100, blank=True)
    ativo = models.BooleanField(default=True)
    atualizado_em = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Negócio Público'
        verbose_name_plural = 'Negócios Públicos'
        ordering = ['nome']

    def __str__(self):
        return f'{self.nome} ({", ".join(self.nichos)})'
