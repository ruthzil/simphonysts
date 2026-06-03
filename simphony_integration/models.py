from django.db import models
from django.contrib.auth.models import User

class MenuItemLog(models.Model):
    """Registro de itens enviados ao Simphony"""
    nome_item = models.CharField(max_length=255)
    simphony_id = models.CharField(max_length=100, blank=True, null=True)
    payload_enviado = models.JSONField()
    resposta_api = models.JSONField()
    status_code = models.IntegerField()
    criado_em = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return f"{self.nome_item} - {self.criado_em}"

class SyncLog(models.Model):
    """Registro de sincronizações"""
    tipo = models.CharField(max_length=50)
    status = models.CharField(max_length=20)
    registros_sincronizados = models.IntegerField(default=0)
    erro = models.TextField(blank=True, null=True)
    criado_em = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return f"{self.tipo} - {self.status} - {self.criado_em}"
