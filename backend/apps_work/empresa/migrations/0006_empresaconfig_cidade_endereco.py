from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('empresa', '0005_empresaconfig_latitude_longitude_logo_url'),
    ]

    operations = [
        migrations.AddField(
            model_name='empresaconfig',
            name='cidade',
            field=models.CharField(blank=True, max_length=100),
        ),
        migrations.AddField(
            model_name='empresaconfig',
            name='endereco',
            field=models.CharField(blank=True, max_length=255),
        ),
    ]
