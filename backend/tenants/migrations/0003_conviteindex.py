import uuid
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('tenants', '0002_usertenant'),
    ]

    operations = [
        migrations.CreateModel(
            name='ConviteIndex',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('token', models.UUIDField(default=uuid.uuid4, unique=True, db_index=True)),
                ('schema_name', models.CharField(max_length=63)),
                ('criado_em', models.DateTimeField(auto_now_add=True)),
            ],
        ),
    ]
