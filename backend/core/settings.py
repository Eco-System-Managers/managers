from pathlib import Path
from datetime import timedelta
import hashlib
import hmac
import os
from django.core.exceptions import ImproperlyConfigured
from dotenv import load_dotenv

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent

# Sem valor padrão: com uma chave conhecida no código, qualquer pessoa forjaria
# tokens dos dois produtos — inclusive com schema_name arbitrário.
SECRET_KEY = os.getenv('SECRET_KEY', '')
if not SECRET_KEY:
    raise ImproperlyConfigured('Defina SECRET_KEY no ambiente (veja .env.example).')


def _chave_jwt(produto: str) -> str:
    """Chave de assinatura JWT de um produto.

    Cada produto assina com a própria chave, para um token de um nunca ser
    aceito pelo outro e para a SECRET_KEY não ser usada direto como chave de
    token. Sem a variável JWT_SIGNING_KEY_<PRODUTO>, a chave é derivada da
    SECRET_KEY — definir a variável permite trocá-la sem mexer na SECRET_KEY.
    """
    return os.getenv(f'JWT_SIGNING_KEY_{produto}') or hmac.new(
        SECRET_KEY.encode(), f'jwt:{produto}'.encode(), hashlib.sha256,
    ).hexdigest()

DEBUG = os.getenv('DEBUG', 'False') == 'True'

ALLOWED_HOSTS = os.getenv('ALLOWED_HOSTS', 'localhost,127.0.0.1,.localhost').split(',')

SHARED_APPS = [
    'django_tenants',
    'tenants',
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'rest_framework_simplejwt',
    'rest_framework_simplejwt.token_blacklist',
    'corsheaders',
    'apps_work.billing',
    'apps_work.autenticacao',
    'apps_serv.autenticacao',
    'apps_serv.consumidores',
    'apps_serv.vitrine',
]

TENANT_APPS = [
    'apps_work.usuarios',
    'apps_work.clientes',
    'apps_work.agenda',
    'apps_work.servicos',
    'apps_work.financeiro',
    'apps_work.empresa',
    'apps_work.kanban',
    'apps_work.contratos',
    'apps_work.notificacoes',
]

INSTALLED_APPS = list(SHARED_APPS) + [app for app in TENANT_APPS if app not in SHARED_APPS]

TENANT_MODEL = 'tenants.Tenant'
TENANT_DOMAIN_MODEL = 'tenants.Domain'
SHOW_PUBLIC_IF_NO_TENANT_FOUND = True
# Sufixo do subdomínio de cada empresa: <slug>.<sufixo>
TENANT_DOMAIN_SUFFIX = os.getenv('TENANT_DOMAIN_SUFFIX', 'localhost')

MIDDLEWARE = [
    'django_tenants.middleware.main.TenantMainMiddleware',
    'core.middleware.JWTTenantMiddleware',
    'core.middleware.AssinaturaBloqueadaMiddleware',
    'core.middleware.InactivityMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'core.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'core.wsgi.application'

DATABASES = {
    'default': {
        'ENGINE': 'django_tenants.postgresql_backend',
        'NAME': os.getenv('DB_NAME', 'workmanage'),
        'USER': os.getenv('DB_USER', 'postgres'),
        'PASSWORD': os.getenv('DB_PASSWORD', ''),
        'HOST': os.getenv('DB_HOST', 'localhost'),
        'PORT': os.getenv('DB_PORT', '5432'),
    }
}

DATABASE_ROUTERS = ['django_tenants.routers.TenantSyncRouter']

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'pt-br'
TIME_ZONE = 'America/Sao_Paulo'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# Storage padrão do projeto: é por aqui que passam as imagens.
#
# Precisa ser STORAGES e não DEFAULT_FILE_STORAGE — o Django removeu a segunda
# na 5.1, e aqui roda a 6.x. Enquanto estava assim, a configuração era ignorada
# em silêncio e tudo caía no FileSystemStorage.
_AWS_BUCKET = os.getenv('AWS_STORAGE_BUCKET_NAME', '')
_AWS_REGIAO = os.getenv('AWS_S3_REGION_NAME', 'sa-east-1')

# Sem isto o django-storages monta a URL global (bucket.s3.amazonaws.com), que
# para bucket fora de us-east-1 responde com redirecionamento antes de entregar
# o arquivo. O host regional evita esse salto em toda imagem carregada.
# A variável existe para, no futuro, apontar para um domínio de CDN.
_AWS_DOMINIO = os.getenv('AWS_S3_CUSTOM_DOMAIN') or (
    f'{_AWS_BUCKET}.s3.{_AWS_REGIAO}.amazonaws.com' if _AWS_BUCKET else None
)

STORAGES = {
    'default': {
        'BACKEND': 'storages.backends.s3.S3Storage',
        'OPTIONS': {
            'bucket_name': _AWS_BUCKET,
            'region_name': _AWS_REGIAO,
            'custom_domain': _AWS_DOMINIO,
            # O bucket tem ACLs desabilitadas: quem concede leitura é a policy,
            # que libera apenas o prefixo logos/. Mandar ACL faria o PutObject
            # ser recusado.
            'default_acl': None,
            # Cada dono tem uma chave fixa, então trocar a imagem sobrescreve
            # em vez de acumular arquivo novo a cada upload.
            'file_overwrite': True,
            # Sem assinatura na URL: as logos são públicas de propósito.
            # Quando entrarem fotos de pessoa, elas usarão URL assinada por
            # chamada, não por configuração global.
            'querystring_auth': False,
        },
    },
    # Imagens de pessoa. O bucket libera leitura pública apenas de logos/, então
    # aqui a URL precisa vir assinada — sem assinatura o objeto simplesmente não
    # abre. A validade curta limita o estrago de uma URL que vaze em log, print
    # ou cache de proxy: ela deixa de funcionar sozinha.
    'privado': {
        'BACKEND': 'storages.backends.s3.S3Storage',
        'OPTIONS': {
            'bucket_name': _AWS_BUCKET,
            'region_name': _AWS_REGIAO,
            'default_acl': None,
            'file_overwrite': True,
            'querystring_auth': True,
            # Uma hora. Curto o bastante para uma URL que vaze deixar de servir
            # sozinha, e longo o bastante para a tela ficar aberta sem a foto
            # sumir no meio do uso. O app busca o perfil de novo ao abrir, então
            # cada visita começa com um endereço novo.
            'querystring_expire': 3600,
            # Sem isto o boto3 assina com SigV2, que é legado: funciona nas
            # regiões antigas e é recusado nas novas.
            'signature_version': 's3v4',
            # Obrigatório junto do SigV4. No padrão do botocore a URL sai no
            # host global (bucket.s3.amazonaws.com) enquanto a assinatura é
            # calculada sobre o host regional — e como o SigV4 assina o header
            # Host, o S3 recusa com SignatureDoesNotMatch. Com 'virtual' os dois
            # passam a ser o mesmo host regional.
            'addressing_style': 'virtual',
            # `custom_domain` fica de fora de propósito: quando definido, o
            # django-storages monta a URL por concatenação e não assina nada.
            # O host regional volta a ser o do próprio S3, que é o que
            # reconhece a assinatura.
        },
    },
    'staticfiles': {
        'BACKEND': 'django.contrib.staticfiles.storage.StaticFilesStorage',
    },
}

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'core.authentication.TenantJWTAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticated',
    ),
    'DEFAULT_THROTTLE_CLASSES': (
        'rest_framework.throttling.ScopedRateThrottle',
    ),
    'DEFAULT_THROTTLE_RATES': {
        'auth_login': '5/min',
        'auth_cadastro': '3/min',
        'auth_recovery': '3/min',
        'auth_verify': '10/min',
        'convite_criar': '5/min',
    },
}

# Work Manage (B2B)
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=60),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'SIGNING_KEY': _chave_jwt('B2B'),
    'AUDIENCE': 'workmanage',
    'ISSUER': 'workmanage',
    # Cada refresh vale uma vez: renovar devolve um novo e revoga o anterior.
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
    # Grava um hash da senha no token: trocar a senha derruba access e refresh.
    'CHECK_REVOKE_TOKEN': True,
}

# Service Manage (B2C) — tokens próprios em apps_serv/autenticacao/authentication.py
SERVICEMANAGE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=60),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'SIGNING_KEY': _chave_jwt('B2C'),
    'AUDIENCE': 'servicemanage',
    'ISSUER': 'servicemanage',
}

INACTIVITY_TIMEOUT_MINUTES = 30

# Intervalo minimo entre duas gravacoes do relogio de atividade. Sem isto, toda
# requisicao autenticada fazia um UPDATE so para adiantar o horario em
# milissegundos. E ordens de grandeza menor que o timeout acima, entao o
# instante do logout por inatividade nao muda de forma perceptivel.
INACTIVITY_WRITE_WINDOW_SECONDS = 60

# Cache local ao processo. E o padrao do Django quando CACHES nao e declarado —
# fica explicito aqui porque agora ha codigo dependendo dele (o estado de
# bloqueio da assinatura, em core/cache.py).
#
# Consequencia de ser local ao processo: com mais de um worker, invalidar em um
# nao invalida nos outros. Na pratica isso limita o atraso ao TTL da chave, nao
# ao proximo evento de cobranca. Trocar por Redis aqui resolve, e nenhum outro
# arquivo precisa mudar.
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
        'LOCATION': 'workmanage-local',
    }
}

CORS_ALLOWED_ORIGINS = os.getenv('CORS_ALLOWED_ORIGINS', 'http://localhost:5173').split(',')
CORS_ALLOW_CREDENTIALS = True

# Trocar e colocar o seu dominio para ir para a produção
FRONTEND_URL = os.getenv('FRONTEND_URL', 'http://localhost:5173')

# Tasks rodam numa thread depois do commit (core/tasks.py). Trocar por um
# backend com worker não exige mudar quem chama .enqueue().
TASKS = {
    'default': {'BACKEND': 'core.tasks.ThreadBackend'},
}

EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
EMAIL_HOST = 'smtp.gmail.com'
EMAIL_PORT = 587
EMAIL_USE_TLS = True
EMAIL_HOST_USER = os.getenv('EMAIL_HOST_USER', '')
EMAIL_HOST_PASSWORD = os.getenv('EMAIL_HOST_PASSWORD', '')
DEFAULT_FROM_EMAIL = os.getenv('EMAIL_HOST_USER', 'noreply@workmanage.com.br')

# Mercado Pago
MERCADOPAGO_ACCESS_TOKEN = os.getenv('MERCADOPAGO_ACCESS_TOKEN', '')
MERCADOPAGO_PUBLIC_KEY = os.getenv('MERCADOPAGO_PUBLIC_KEY', '')
MERCADOPAGO_WEBHOOK_SECRET = os.getenv('MERCADOPAGO_WEBHOOK_SECRET', '')
# O Mercado Pago exige uma URL https válida pro back_url (redirecionamento pós-checkout) —
# não aceita http://localhost, então não dá pra reaproveitar FRONTEND_URL em dev.
MERCADOPAGO_BACK_URL = os.getenv('MERCADOPAGO_BACK_URL', 'https://workmanage.com.br')

