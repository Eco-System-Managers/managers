from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('vitrine', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='negociopublico',
            name='cidade',
            field=models.CharField(blank=True, max_length=100),
        ),
    ]
