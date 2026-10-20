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
    'drf_spectacular',
    'core',
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
    # Security e CORS antes de tudo que pode responder sozinho: assim as
    # respostas 401/402 dos middlewares abaixo saem com cabeçalho CORS (o front
    # consegue ler o erro), e o preflight (OPTIONS) é respondido pelo CORS antes
    # de cair no bloqueio de assinatura. Nenhum dos dois depende do schema.
    'django.middleware.security.SecurityMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django_tenants.middleware.main.TenantMainMiddleware',
    'core.middleware.JWTTenantMiddleware',
    'core.middleware.AssinaturaBloqueadaMiddleware',
    'core.middleware.InactivityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'core.urls'

# HTTPS — ligado só com HTTPS=True. Não depende de DEBUG: os testes rodam com
# DEBUG=False (o redirect daria 301 em toda requisição), e DEBUG já é False por
# padrão aqui, então o runserver sem .env mandaria tudo para https://localhost.
HTTPS = os.getenv('HTTPS', 'False') == 'True'
if HTTPS:
    SECURE_SSL_REDIRECT = True
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    # Curto de propósito até o HTTPS estar estável: o navegador recusa HTTP
    # pelo tempo inteiro, em todos os subdomínios (as empresas).
    SECURE_HSTS_SECONDS = int(os.getenv('SECURE_HSTS_SECONDS', '3600'))
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    # Sem preload de propósito: entrar na lista dos navegadores é praticamente
    # irreversível. O check --deploy avisa (W021); o aviso é silenciado.
    SILENCED_SYSTEM_CHECKS = ['security.W021']
    if int(os.getenv('NUM_PROXIES', '0')) > 0:
        # Atrás de proxy a conexão chega em HTTP; o proxy diz qual era o esquema.
        SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')

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
    # Contrato único de erro: {detail, code, fields?} (core/excecoes.py).
    'EXCEPTION_HANDLER': 'core.excecoes.tratar_excecao',
    # Toda coleção de recurso sai paginada: {count, next, previous, results}.
    'DEFAULT_PAGINATION_CLASS': 'core.paginacao.Paginacao',
    # Schema OpenAPI, um por produto (core/openapi.py).
    'DEFAULT_SCHEMA_CLASS': 'drf_spectacular.openapi.AutoSchema',
    # Valem para toda view que não declara throttle_classes própria. O
    # ScopedRateThrottle só age onde a view define throttle_scope.
    'DEFAULT_THROTTLE_CLASSES': (
        'rest_framework.throttling.ScopedRateThrottle',
        'rest_framework.throttling.AnonRateThrottle',
        'core.throttling.UsuarioRateThrottle',
    ),
    'DEFAULT_THROTTLE_RATES': {
        'anon': '120/min',
        'user': '600/min',
        # Work Manage (B2B)
        'auth_login': '5/min',
        'auth_cadastro': '3/min',
        'auth_recovery': '3/min',
        'auth_verify': '10/min',
        'recuperacao_email': '5/hour',
        'convite_criar': '5/min',
        # Service Manage (B2C) — contadores separados dos do B2B
        'sm_auth_login': '5/min',
        'sm_auth_cadastro': '3/min',
        'sm_auth_recovery': '3/min',
        'sm_auth_verify': '10/min',
        'sm_recuperacao_email': '5/hour',
        # Mercado Pago
        'webhook': '120/min',
    },
    # Quantos proxies confiáveis ficam na frente da aplicação. Com 0 o IP é o
    # REMOTE_ADDR. Sem definir (None), o DRF usaria o X-Forwarded-For inteiro
    # como identidade — um cabeçalho que o cliente escreve, e com o qual
    # burlaria todo limite por IP mandando um valor diferente a cada requisição.
    'NUM_PROXIES': int(os.getenv('NUM_PROXIES', '0')),
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

# Contadores de rate limiting e o estado de bloqueio da assinatura
# (core/cache.py) vivem aqui. Com REDIS_URL, ficam no Redis e valem para todos
# os processos; sem ela, ficam na memória de cada processo — suficiente com um
# processo só (runserver), mas com N workers cada um teria o próprio contador.
REDIS_URL = os.getenv('REDIS_URL', '')
CACHES = {
    'default': (
        {'BACKEND': 'django.core.cache.backends.redis.RedisCache', 'LOCATION': REDIS_URL}
        if REDIS_URL else
        {'BACKEND': 'django.core.cache.backends.locmem.LocMemCache', 'LOCATION': 'workmanage-local'}
    ),
}

CORS_ALLOWED_ORIGINS = os.getenv('CORS_ALLOWED_ORIGINS', 'http://localhost:5173').split(',')
CORS_ALLOW_CREDENTIALS = True

# Base de todo link público (convite, contrato, volta do checkout) — ver
# core/links.py. No deploy, o domínio que também publica os arquivos de App
# Link/Universal Link. FRONTEND_URL ainda é lido para não quebrar .env antigos.
LINKS_BASE_URL = os.getenv('LINKS_BASE_URL') or os.getenv('FRONTEND_URL', 'http://localhost:5173')

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

# Billing: gateway das assinaturas da plataforma e plano do trial/checkout
BILLING_GATEWAY = os.getenv('BILLING_GATEWAY', 'mercadopago')
PLANO_PADRAO = os.getenv('PLANO_PADRAO', 'pro')

# Mercado Pago
MERCADOPAGO_ACCESS_TOKEN = os.getenv('MERCADOPAGO_ACCESS_TOKEN', '')
MERCADOPAGO_PUBLIC_KEY = os.getenv('MERCADOPAGO_PUBLIC_KEY', '')
MERCADOPAGO_WEBHOOK_SECRET = os.getenv('MERCADOPAGO_WEBHOOK_SECRET', '')
# O Mercado Pago exige uma URL https válida pro back_url (redirecionamento pós-checkout) —
# não aceita http://localhost, então não dá pra reaproveitar LINKS_BASE_URL em dev.
MERCADOPAGO_BACK_URL = os.getenv('MERCADOPAGO_BACK_URL', 'https://workmanage.com.br')

# OpenAPI (drf-spectacular). Título e filtro de rotas vêm de cada produto
# (core/openapi.py); aqui fica o que vale para os dois.
SPECTACULAR_SETTINGS = {
    'VERSION': '1.0.0',
    # Componentes de request e response separados (campos read-only não viram
    # obrigatórios na escrita), o que os geradores de client Dart esperam.
    'COMPONENT_SPLIT_REQUEST': True,
    'SERVE_INCLUDE_SCHEMA': False,
    # Nomes estáveis para os enums: sem isso o drf-spectacular gera nomes como
    # "Status939Enum" quando dois models têm um campo de mesmo nome, e o client
    # Dart muda de tipo a cada regeração.
    'ENUM_NAME_OVERRIDES': {
        # Usado no B2B (Agendamento) e no B2C (AgendamentoConsumidor).
        'StatusAgendamentoEnum': 'apps_work.agenda.models.StatusAgendamento',
        'StatusContratoEnum': 'apps_work.contratos.models.StatusContrato',
        'StatusAssinaturaEnum': 'apps_work.billing.models.StatusAssinatura',
        'StatusPagamentoAssinaturaEnum': 'apps_work.billing.models.StatusPagamento',
        'OrigemClienteEnum': 'apps_work.clientes.models.OrigemCliente',
        'OrigemTransacaoCreditoEnum': 'apps_work.financeiro.models.OrigemTransacao',
        # agenda | kanban: de qual modo de agenda veio o atendimento.
        'OrigemAtendimentoEnum': 'apps_work.agenda.models.OrigemAtendimento',
        'TipoTransacaoCreditoEnum': 'apps_work.financeiro.models.TipoTransacao',
        'TipoNotificacaoEnum': 'apps_work.notificacoes.models.TipoNotificacao',
        'TipoAgendaEnum': 'apps_work.empresa.models.TipoAgenda',
        'TipoPlanoEnum': 'apps_work.billing.models.TipoPlano',
        # pet | veiculo: usado no B2B (ObjetoCliente) e no B2C.
        'TipoObjetoEnum': 'apps_work.clientes.models.TipoObjeto',
    },
    'POSTPROCESSING_HOOKS': [
        'drf_spectacular.hooks.postprocess_schema_enums',
        'core.openapi.adicionar_erros',
    ],
}

