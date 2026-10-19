from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('servicos', '0003_remove_servico_categoria_delete_categoriaservico'),
    ]

    operations = [
        migrations.AddField(
            model_name='servico',
            name='sinal',
            field=models.DecimalField(decimal_places=2, default=0, max_digits=8),
        ),
    ]
