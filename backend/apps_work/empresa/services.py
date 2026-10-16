import urllib.request
import urllib.parse
import json
import logging

from io import BytesIO

from django.core.files.base import ContentFile
from django.core.files.storage import default_storage, storages
from PIL import Image, ImageOps

logger = logging.getLogger(__name__)


class GeocodificacaoService:
    NOMINATIM_URL = 'https://nominatim.openstreetmap.org/search'
    NOMINATIM_REVERSE_URL = 'https://nominatim.openstreetmap.org/reverse'
    TIMEOUT = 5

    def geocodificar(self, endereco: str, cidade: str, uf: str = '') -> tuple[str, str] | None:
        partes = [p for p in [endereco, cidade, uf, 'Brasil'] if p]
        query = ', '.join(partes)

        params = urllib.parse.urlencode({
            'q': query,
            'format': 'json',
            'limit': 1,
            'addressdetails': 0,
        })
        url = f'{self.NOMINATIM_URL}?{params}'

        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'WorkManage/1.0'})
            with urllib.request.urlopen(req, timeout=self.TIMEOUT) as resp:
                data = json.loads(resp.read())
                if data:
                    return str(data[0]['lat']), str(data[0]['lon'])
        except Exception as e:
            logger.warning('Geocodificação falhou para "%s": %s', query, e)

        return None

    def rua_no_ponto(self, latitude: float, longitude: float) -> str | None:
        """Nome da via em que a coordenada cai, pelo OSM.

        Serve para o dono conferir visualmente que o pino caiu na rua certa. Não
        é fonte de verdade: o OSM tem a mesma via cadastrada com grafias
        diferentes (e às vezes com erro de digitação), então quem compara com o
        logradouro do CEP precisa tolerar divergência.
        """
        params = urllib.parse.urlencode({
            'lat': latitude,
            'lon': longitude,
            'format': 'jsonv2',
            'zoom': 17,
            'addressdetails': 1,
        })
        url = f'{self.NOMINATIM_REVERSE_URL}?{params}'

        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'WorkManage/1.0'})
            with urllib.request.urlopen(req, timeout=self.TIMEOUT) as resp:
                data = json.loads(resp.read())
                return data.get('address', {}).get('road') or None
        except Exception as e:
            logger.warning('Reverse geocoding falhou para %s,%s: %s', latitude, longitude, e)

        return None


class ImagemInvalidaError(ValueError):
    """Arquivo recusado pelas regras de imagem. A view traduz para HTTP 400."""


class ArmazenamentoImagemService:
    """Valida, normaliza e guarda imagens do produto, devolvendo a URL.

    Concentra tudo que é específico do armazenamento — caminho, formato e
    redimensionamento. Quem chama informa apenas o prefixo lógico e a chave.

    Os prefixos não são só organização: são a fronteira de permissão no bucket.
    Logo de negócio é pública, aparece no mapa do app do cliente; foto de pessoa
    não pode ser. A policy libera leitura pública apenas de `logos/`.
    """

    PREFIXO_LOGOS = 'logos'
    PREFIXO_COLABORADORES = 'colaboradores'
    PREFIXO_CONSUMIDORES = 'consumidores'

    # Só a logo é pública — ela aparece no mapa para quem nem tem conta. Imagem
    # de pessoa vai para o storage que assina a URL. A separação é a mesma da
    # policy do bucket, e mantê-las alinhadas é o que impede um rosto de virar
    # público por descuido.
    _PREFIXOS_PUBLICOS = {PREFIXO_LOGOS}

    TAMANHO_MAXIMO = 5 * 1024 * 1024
    LADO_MAXIMO = 400

    # Tudo vira webp. O formato de saída ser único é o que mantém a chave
    # determinística: sem isso, trocar um .jpg por um .png deixaria o arquivo
    # antigo órfão no bucket, ainda acessível pela URL antiga.
    FORMATO = 'WEBP'
    EXTENSAO = 'webp'
    QUALIDADE = 85

    def validar(self, arquivo) -> None:
        if arquivo.size > self.TAMANHO_MAXIMO:
            raise ImagemInvalidaError('Imagem deve ter no máximo 5MB.')

        if not (arquivo.content_type or '').startswith('image/'):
            raise ImagemInvalidaError('Apenas imagens são permitidas.')

    def salvar(self, arquivo, prefixo: str, chave: str) -> str:
        """Sobe a imagem e devolve o **caminho** no armazenamento, não a URL.

        Quem precisa exibir chama `url()` na hora — para imagem privada o
        endereço é assinado e tem validade curta.

        `chave` identifica o dono da imagem dentro do prefixo — o schema do
        tenant no caso das logos. Como é sempre a mesma para o mesmo dono, cada
        um tem um único arquivo.
        """
        caminho = f'{prefixo}/{chave}.{self.EXTENSAO}'
        conteudo = self._normalizar(arquivo)
        storage = self._storage(prefixo)

        # file_overwrite=True sobrescreve, mas apagar antes evita depender desse
        # comportamento e cobre o caso de o backend mudar.
        storage.delete(caminho)
        storage.save(caminho, ContentFile(conteudo))

        return caminho

    def url(self, caminho: str) -> str:
        """Endereço de leitura para um caminho já guardado.

        Para imagem privada a URL é assinada e expira, então precisa ser gerada
        no momento da resposta — guardá-la no banco faria a foto parar de abrir
        sozinha depois de alguns minutos.
        """
        if not caminho:
            return ''
        prefixo = caminho.split('/', 1)[0]
        return self._storage(prefixo).url(caminho)

    def apagar(self, caminho: str) -> None:
        if not caminho:
            return
        prefixo = caminho.split('/', 1)[0]
        self._storage(prefixo).delete(caminho)

    def _storage(self, prefixo: str):
        return default_storage if prefixo in self._PREFIXOS_PUBLICOS else storages['privado']

    def _normalizar(self, arquivo) -> bytes:
        """Reduz e converte para webp, devolvendo os bytes prontos."""
        imagem = Image.open(arquivo)

        # Foto de celular guarda a rotação em metadado em vez de girar os pixels.
        # Sem isto, a imagem aparece deitada depois da conversão.
        imagem = ImageOps.exif_transpose(imagem)

        # thumbnail preserva a proporção e nunca amplia — é o mesmo
        # comportamento do crop:limit que o Cloudinary aplicava.
        imagem.thumbnail((self.LADO_MAXIMO, self.LADO_MAXIMO))

        if imagem.mode not in ('RGB', 'RGBA'):
            imagem = imagem.convert('RGBA' if 'A' in imagem.getbands() else 'RGB')

        buffer = BytesIO()
        imagem.save(buffer, format=self.FORMATO, quality=self.QUALIDADE, method=6)
        return buffer.getvalue()
