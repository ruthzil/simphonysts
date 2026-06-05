#!/bin/bash

echo "========================================="
echo "🚀 ATUALIZANDO SISTEMA SIMPHONY"
echo "========================================="

cd /opt/simphony
source venv/bin/activate

# 1. Atualizar .env com as configurações corretas
echo ""
echo "📝 1. Atualizando arquivo .env..."

cat > /opt/simphony/.env << 'ENV_EOF'
# Oracle Simphony Config
OIDC_AUTHORITY_URL=https://ors-idm.us07.oraclerestaurants.com
CLIENT_ID=VFRNLmE5ZDMyY2ExLTJjMmYtNGUyNS04NDI2LWQ0ZTk5ZTFkMzVkNg
USERNAME=caio.citrangulo
PASSWORD=Suporte@@2026
ORG_SHORT_NAME=TTM
CCAPI_URL=https://ors-cncapi-us07.us07.oraclerestaurants.com/config/sim/v1
STS_API_URL=https://us07-sts.oraclemicros.com/api/v1
HIER_UNIT_ID=1
SECRET_KEY=django-insecure-8x@2k#m!9$q^p&a*b(c)d_e+f=g-h*i/j/k*l+m+n-o=p
DEBUG=True
ALLOWED_HOSTS=simphonysts.ddns.net,localhost,127.0.0.1
ENV_EOF

echo "✅ .env atualizado!"

# 2. Atualizar settings.py
echo ""
echo "⚙️ 2. Atualizando settings.py..."

cat > /opt/simphony/setup/settings.py << 'SETTINGS_EOF'
from pathlib import Path
from decouple import config
import os

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = config('SECRET_KEY')
DEBUG = config('DEBUG', default=True, cast=bool)
ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='localhost').split(',')

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'corsheaders',
    'django_extensions',
    'simphony_integration',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'setup.urls'

TEMPLATES = [{
    'BACKEND': 'django.template.backends.django.DjangoTemplates',
    'DIRS': [BASE_DIR / 'templates'],
    'APP_DIRS': True,
    'OPTIONS': {'context_processors': [
        'django.template.context_processors.debug',
        'django.template.context_processors.request',
        'django.contrib.auth.context_processors.auth',
        'django.contrib.messages.context_processors.messages',
    ]},
}]

WSGI_APPLICATION = 'setup.wsgi.application'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}

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

STATIC_URL = '/static/'
STATICFILES_DIRS = [BASE_DIR / 'static']
STATIC_ROOT = BASE_DIR / 'staticfiles'

MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

CORS_ALLOW_ALL_ORIGINS = DEBUG

# Oracle Simphony API Configuration
OIDC_AUTHORITY_URL = config('OIDC_AUTHORITY_URL')
CLIENT_ID = config('CLIENT_ID')
USERNAME = config('USERNAME')
PASSWORD = config('PASSWORD')
ORG_SHORT_NAME = config('ORG_SHORT_NAME')
CCAPI_URL = config('CCAPI_URL')
STS_API_URL = config('STS_API_URL')
HIER_UNIT_ID = config('HIER_UNIT_ID')

# URLs de redirecionamento
LOGIN_URL = '/accounts/login/'
LOGIN_REDIRECT_URL = '/simphony/dashboard/'
LOGOUT_REDIRECT_URL = '/accounts/login/'
SETTINGS_EOF

echo "✅ settings.py atualizado!"

# 3. Atualizar services.py com o endpoint correto
echo ""
echo "🔧 3. Atualizando services.py..."

cat > /opt/simphony/simphony_integration/services.py << 'SERVICES_EOF'
# simphony_integration/services.py
import requests
import json
import base64
import hashlib
import random
import string
from django.conf import settings
from datetime import datetime, timedelta

class SimphonyAPIService:
    """Serviço para interagir com a API do Oracle Simphony usando OAuth2 PKCE"""
    
    def __init__(self):
        self.oidc_url = settings.OIDC_AUTHORITY_URL
        self.client_id = settings.CLIENT_ID
        self.username = settings.USERNAME
        self.password = settings.PASSWORD
        self.org_short_name = settings.ORG_SHORT_NAME
        self.ccapi_url = settings.CCAPI_URL
        self.sts_api_url = settings.STS_API_URL
        self.hier_unit_id = settings.HIER_UNIT_ID
        self.access_token = None
        self.refresh_token = None
        self.token_expiry = None
        self.session = None
    
    def _create_random_string(self, length):
        chars = string.ascii_letters + string.digits
        return ''.join(random.choice(chars) for _ in range(length))
    
    def _generate_pkce_codes(self):
        code_verifier = self._create_random_string(random.randint(43, 128))
        sha256_hash = hashlib.sha256(code_verifier.encode()).digest()
        code_challenge = base64.urlsafe_b64encode(sha256_hash).decode().rstrip('=')
        return code_verifier, code_challenge
    
    def get_access_token(self):
        if self.access_token and self.token_expiry and datetime.now() < self.token_expiry:
            return self.access_token
        
        try:
            self.session = requests.Session()
            code_verifier, code_challenge = self._generate_pkce_codes()
            
            # 1. Authorize
            auth_url = f"{self.oidc_url}/oidc-provider/v1/oauth2/authorize"
            auth_params = {
                'client_id': self.client_id,
                'response_type': 'code',
                'scope': 'openid',
                'state': '999',
                'redirect_uri': 'apiaccount://callback',
                'code_challenge': code_challenge,
                'code_challenge_method': 'S256'
            }
            self.session.get(auth_url, params=auth_params, timeout=30)
            
            # 2. Signin
            signin_url = f"{self.oidc_url}/oidc-provider/v1/oauth2/signin"
            signin_data = {
                'username': self.username,
                'password': self.password,
                'orgname': self.org_short_name
            }
            signin_response = self.session.post(signin_url, data=signin_data, timeout=30)
            signin_json = signin_response.json()
            redirect_url = signin_json.get('redirectUrl', '')
            
            if 'code=' not in redirect_url:
                return None
            
            auth_code = redirect_url.split('code=')[1].split('&')[0]
            
            # 3. Token
            token_url = f"{self.oidc_url}/oidc-provider/v1/oauth2/token"
            token_data = {
                'grant_type': 'authorization_code',
                'code': auth_code,
                'client_id': self.client_id,
                'code_verifier': code_verifier,
                'redirect_uri': 'apiaccount://callback'
            }
            token_response = self.session.post(token_url, data=token_data, timeout=30)
            token_json = token_response.json()
            
            self.access_token = token_json.get('id_token')
            self.refresh_token = token_json.get('refresh_token')
            expires_in = token_json.get('expires_in', 1209600)
            self.token_expiry = datetime.now() + timedelta(seconds=expires_in - 60)
            
            print(f"✅ Token obtido com sucesso!")
            return self.access_token
            
        except Exception as e:
            print(f"❌ Erro ao obter token: {e}")
            return None
    
    def test_connection(self):
        token = self.get_access_token()
        if token:
            return {'success': True, 'message': 'Autenticado com sucesso'}
        return {'success': False, 'message': 'Falha na autenticação'}
    
    def get_employees(self):
        """Buscar funcionários do EMC usando CCAPI"""
        token = self.get_access_token()
        if not token:
            return {'success': False, 'error': 'Não foi possível obter token de acesso'}
        
        headers = {
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
        
        # Endpoint correto baseado na documentação CCAPI
        url = f"{self.ccapi_url}/employees/getEmployees"
        body = {"includeAll": "detailed"}
        
        try:
            response = requests.post(url, headers=headers, json=body, timeout=30)
            
            if response.status_code == 200:
                data = response.json()
                employees = data.get('items', [])
                return {
                    'success': True,
                    'employees': employees,
                    'count': len(employees)
                }
            else:
                return {'success': False, 'error': f'Erro {response.status_code}: {response.text}'}
                
        except Exception as e:
            return {'success': False, 'error': str(e)}
    
    def get_menu_items(self):
        """Buscar itens do menu usando CCAPI"""
        token = self.get_access_token()
        if not token:
            return {'success': False, 'error': 'Não foi possível obter token de acesso'}
        
        headers = {
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
        
        url = f"{self.ccapi_url}/menuItems/getMenuItems"
        body = {"includeAll": "detailed"}
        
        try:
            response = requests.post(url, headers=headers, json=body, timeout=30)
            
            if response.status_code == 200:
                data = response.json()
                items = data.get('items', [])
                return {
                    'success': True,
                    'menu_items': items,
                    'count': len(items)
                }
            else:
                return {'success': False, 'error': f'Erro {response.status_code}: {response.text}'}
                
        except Exception as e:
            return {'success': False, 'error': str(e)}
SERVICES_EOF

echo "✅ services.py atualizado!"

# 4. Atualizar views.py
echo ""
echo "📊 4. Atualizando views.py..."

cat > /opt/simphony/simphony_integration/views.py << 'VIEWS_EOF'
from django.shortcuts import render, redirect
from django.contrib.auth.decorators import login_required
from django.http import JsonResponse
from django.contrib import messages
from django.contrib.auth.models import User
from django.conf import settings
import json
from .services import SimphonyAPIService

def index(request):
    context = {
        'title': 'Simphony Integration',
        'message': 'Bem-vindo ao sistema de integração Simphony'
    }
    return render(request, 'simphony_integration/index.html', context)

@login_required
def dashboard(request):
    api_service = SimphonyAPIService()
    api_status = "Desconectado"
    
    try:
        test = api_service.test_connection()
        if test.get('success'):
            api_status = "Conectado"
    except:
        pass
    
    context = {
        'title': 'Dashboard',
        'user': request.user,
        'api_status': api_status
    }
    return render(request, 'simphony_integration/dashboard.html', context)

@login_required
def listar_usuarios_simphony(request):
    """Listar usuários do Simphony EMC"""
    api_service = SimphonyAPIService()
    resultado = api_service.get_employees()
    
    context = {
        'title': 'Usuários do Simphony EMC',
        'resultado': resultado
    }
    return render(request, 'simphony_integration/usuarios_simphony.html', context)

@login_required
def listar_menu_items(request):
    """Listar itens do menu do Simphony"""
    api_service = SimphonyAPIService()
    resultado = api_service.get_menu_items()
    
    context = {
        'title': 'Menu Items - Simphony',
        'resultado': resultado
    }
    return render(request, 'simphony_integration/menu_items.html', context)

def settings_view(request):
    return render(request, 'simphony_integration/settings.html', {'title': 'Configurações'})

def settings(request):
    return settings_view(request)
VIEWS_EOF

echo "✅ views.py atualizado!"

# 5. Atualizar URLs
echo ""
echo "🔗 5. Atualizando urls.py..."

cat > /opt/simphony/simphony_integration/urls.py << 'URLS_EOF'
from django.urls import path
from . import views

app_name = 'simphony_integration'

urlpatterns = [
    path('', views.index, name='index'),
    path('dashboard/', views.dashboard, name='dashboard'),
    path('settings/', views.settings, name='settings'),
    path('usuarios-simphony/', views.listar_usuarios_simphony, name='listar_usuarios_simphony'),
    path('menu-items/', views.listar_menu_items, name='listar_menu_items'),
]
URLS_EOF

echo "✅ urls.py atualizado!"

# 6. Criar template de usuários Simphony
echo ""
echo "🎨 6. Criando templates..."

cat > /opt/simphony/templates/simphony_integration/usuarios_simphony.html << 'TEMPLATE_EOF'
{% extends 'base.html' %}
{% block title %}Usuários Simphony EMC{% endblock %}
{% block content %}
<h2><i class="bi bi-cloud"></i> Usuários do Simphony EMC Cloud</h2>

{% if resultado.success %}
    <div class="alert alert-success">
        <i class="bi bi-check-circle"></i> Total de usuários encontrados: {{ resultado.count }}
    </div>
    
    <div class="table-responsive">
        <table class="table table-striped table-hover">
            <thead class="table-dark">
                <tr>
                    <th>ID</th>
                    <th>Nome</th>
                    <th>Email</th>
                    <th>Status</th>
                </tr>
            </thead>
            <tbody>
                {% for emp in resultado.employees %}
                <tr>
                    <td>{{ emp.objectNum|default:emp.id }}</td>
                    <td>{{ emp.firstName }} {{ emp.lastName }}</td>
                    <td>{{ emp.email|default:"N/A" }}</td>
                    <td>
                        <span class="badge bg-success">Ativo</span>
                    </td>
                </tr>
                {% empty %}
                <tr><td colspan="4" class="text-center">Nenhum usuário encontrado</td></tr>
                {% endfor %}
            </tbody>
        </table>
    </div>
{% else %}
    <div class="alert alert-danger">
        <i class="bi bi-exclamation-triangle"></i> Erro: {{ resultado.error }}
    </div>
{% endif %}

<a href="{% url 'simphony_integration:dashboard' %}" class="btn btn-secondary">
    <i class="bi bi-arrow-left"></i> Voltar
</a>
{% endblock %}
TEMPLATE_EOF

# 7. Atualizar dashboard.html com links
cat > /opt/simphony/templates/simphony_integration/dashboard.html << 'DASHBOARD_EOF'
{% extends 'base.html' %}
{% block title %}Dashboard - Simphony STS{% endblock %}
{% block content %}
<h1>Dashboard</h1>

<div class="row mt-4">
    <div class="col-md-4">
        <div class="card text-white bg-primary mb-3">
            <div class="card-header">Status da API</div>
            <div class="card-body">
                <h5 class="card-title">{{ api_status }}</h5>
                <p class="card-text">API Simphony está {% if api_status == 'Conectado' %}respondendo normalmente{% else %}com problemas{% endif %}.</p>
            </div>
        </div>
    </div>
    <div class="col-md-4">
        <div class="card text-white bg-success mb-3">
            <div class="card-header">Menu Items</div>
            <div class="card-body">
                <h5 class="card-title">Gerenciar Itens</h5>
                <p class="card-text">
                    <a href="{% url 'simphony_integration:listar_menu_items' %}" class="text-white">Ver itens do menu →</a>
                </p>
            </div>
        </div>
    </div>
    <div class="col-md-4">
        <div class="card text-white bg-info mb-3">
            <div class="card-header">Usuários EMC</div>
            <div class="card-body">
                <h5 class="card-title">Oracle Simphony</h5>
                <p class="card-text">
                    <a href="{% url 'simphony_integration:listar_usuarios_simphony' %}" class="text-white">Ver usuários do EMC Cloud →</a>
                </p>
            </div>
        </div>
    </div>
</div>
{% endblock %}
DASHBOARD_EOF

echo "✅ Templates criados!"

# 8. Coletar arquivos estáticos e reiniciar serviços
echo ""
echo "🔄 8. Atualizando serviços..."

python manage.py collectstatic --noinput
sudo systemctl restart gunicorn-simphony
sudo systemctl restart nginx

echo ""
echo "========================================="
echo "✅✅✅ SISTEMA ATUALIZADO COM SUCESSO! ✅✅✅"
echo "========================================="
echo ""
echo "🌐 Acesse: https://simphonysts.ddns.net/simphony/dashboard/"
echo "👤 Login: admin / admin123"
echo ""
echo "📊 Funcionalidades disponíveis:"
echo "   • Dashboard com status da API"
echo "   • Lista de usuários do Simphony EMC"
echo "   • Lista de menu items"
echo "========================================="
