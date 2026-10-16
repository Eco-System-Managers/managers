from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name='NegocioPublico',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('schema_name', models.CharField(db_index=True, max_length=63, unique=True)),
                ('nome', models.CharField(max_length=255)),
                ('nicho', models.CharField(max_length=50)),
                ('latitude', models.DecimalField(decimal_places=6, max_digits=9)),
                ('longitude', models.DecimalField(decimal_places=6, max_digits=9)),
                ('logo_url', models.URLField(blank=True)),
                ('descricao', models.TextField(blank=True)),
                ('ativo', models.BooleanField(default=True)),
                ('atualizado_em', models.DateTimeField(auto_now=True)),
            ],
            options={'verbose_name': 'Negócio Público', 'verbose_name_plural': 'Negócios Públicos', 'ordering': ['nome']},
        ),
    ]
