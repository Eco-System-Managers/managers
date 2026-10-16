from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('clientes', '0006_cliente_visivel'),
    ]

    operations = [
        migrations.AddField(
            model_name='cliente',
            name='origem',
            field=models.CharField(
                choices=[
                    ('manual', 'Cadastrado pelo negócio'),
                    ('servicemanage', 'Veio do Service Manage'),
                ],
                default='manual',
                max_length=20,
            ),
        ),
    ]
