"""Logs da API no formato que o Railway entende.

Uma linha de JSON por registro, com `message` e `level`: o Railway mostra a
mensagem e transforma o resto em atributos filtráveis no Log Explorer
(`@status:500`, `@codigo:horario_conflito`, `@schema_name:barbearia_ze`).
O traceback vai dentro da mesma linha; quebrado em várias, cada pedaço viraria
um registro solto.
"""
import json
import logging

# O Railway reconhece estes nomes; o `levelname` do Python diz WARNING e CRITICAL.
_NIVEL = {
    logging.DEBUG: 'debug',
    logging.INFO: 'info',
    logging.WARNING: 'warn',
    logging.ERROR: 'error',
    logging.CRITICAL: 'error',
}


class FormatoJson(logging.Formatter):
    def format(self, record):
        linha = {
            'level': _NIVEL.get(record.levelno, 'info'),
            'message': record.getMessage(),
            'logger': record.name,
        }
        # Os atributos de quem loga vão em `extra={'dados': {...}}`.
        linha.update(getattr(record, 'dados', None) or {})
        if record.exc_info:
            linha['traceback'] = self.formatException(record.exc_info)
        return json.dumps(linha, ensure_ascii=False, default=str)
