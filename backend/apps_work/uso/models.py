from django.db import models


class EventoDeUso(models.Model):
    """Uma ação feita no app, para acompanhar como os negócios usam o Work Manage.

    Vive no schema público, para o relatório ler todos os negócios de uma vez.
    O negócio e o usuário são guardados por nome e id, sem FK: o evento é um
    registro do que aconteceu e não pode travar nem sumir junto com o que
    apaga o negócio. Quem apaga é a exclusão de conta (`ExclusaoContaService`).

    Nada do conteúdo entra aqui, só o tipo da ação (`registro.py`).
    """

    criado_em = models.DateTimeField(auto_now_add=True, db_index=True)
    schema_name = models.CharField(max_length=63, blank=True, db_index=True)
    user_id = models.PositiveIntegerField(null=True, blank=True, db_index=True)
    papel = models.CharField(max_length=20, blank=True)
    evento = models.CharField(max_length=80, db_index=True)
    metodo = models.CharField(max_length=7)
    objeto_id = models.CharField(max_length=40, blank=True)
    status = models.PositiveSmallIntegerField()
    codigo = models.CharField(max_length=60, blank=True)
    duracao_ms = models.PositiveIntegerField()
    plataforma = models.CharField(max_length=10, blank=True)
    versao_app = models.CharField(max_length=30, blank=True)

    class Meta:
        ordering = ['-criado_em']
        indexes = [models.Index(fields=['schema_name', 'criado_em'])]
        verbose_name = 'evento de uso'
        verbose_name_plural = 'eventos de uso'

    def __str__(self):
        return f'{self.evento} ({self.status})'
