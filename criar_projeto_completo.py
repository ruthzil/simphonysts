#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Script para criar projeto Django 'setup' com integracao Oracle Simphony
Execute: python criar_projeto_completo.py
"""

import os

def criar_estrutura():
    """Cria toda a estrutura de pastas e arquivos do projeto"""
    
    # Estrutura base
    pastas = [
        'setup',
        'setup/setup',
        'setup/simphony_integration',
        'setup/simphony_integration/services',
        'setup/simphony_integration/templates',
        'setup/simphony_integration/templates/simphony_integration',
        'setup/simphony_integration/migrations',
        'setup/templates',
        'setup/static',
        'setup/static/css',
        'setup/static/js',
        'setup/media',
        'setup/logs',
    ]
    
    print("=" * 70)
    print("CRIANDO ESTRUTURA DO PROJETO SETUP")
    print("=" * 70)
    
    for pasta in pastas:
        os.makedirs(pasta, exist_ok=True)
        print(f"  OK {pasta}/")
    
    # 1. requirements.txt
    with open('setup/requirements.txt', 'w') as f:
        f.write("Django==4.2.7\n")
        f.write("requests==2.31.0\n")
        f.write("python-decouple==3.8\n")
        f.write("psycopg2-binary==2.9.9\n")
        f.write("django-cors-headers==4.3.1\n")
        f.write("python-dotenv==1.0.0\n")
    print("  OK requirements.txt")
    
    # 2. .env
    with open('setup/.env', 'w') as f:
        f.write("# Oracle Simphony Credentials - ZONE1/TTM\n")
        f.write("SIMPHONY_TOKEN_URL=https://ors-idm.us07.oraclerestaurants.com\n")
        f.write("SIMPHONY_API_URL=https://us07-ats.oraclemicros.com/api/v1/\n")
        f.write("SIMPHONY_CLIENT_ID=VFRNLmE5ZDMyY2ExLTJjMmYtNGUyNS04NDI2LWQ0ZTk5ZTFkMzVkNg\n")
        f.write("SIMPHONY_CLIENT_SECRET=Suporte@@2026\n")
        f.write("SIMPHONY_ORG_SHORT_NAME=TTM\n")
        f.write("\n")
        f.write("# Django Settings\n")
        f.write("SECRET_KEY=django-insecure-8x@2k#m!9$q^p&a*b(c)d_e+f=g-h*i/j*k*l+m+n-o=p\n")
        f.write("DEBUG=True\n")
        f.write("ALLOWED_HOSTS=localhost,127.0.0.1\n")
    print("  OK .env")
    
    # 3. .gitignore
    with open('setup/.gitignore', 'w') as f:
        f.write("__pycache__/\n*.pyc\n.env\nvenv/\ndb.sqlite3\nlogs/\nmedia/\nstaticfiles/\n")
    print("  OK .gitignore")
    
    # 4. manage.py
    with open('setup/manage.py', 'w') as f:
        f.write("#!/usr/bin/env python\n")
        f.write("import os\nimport sys\n\n")
        f.write("def main():\n")
        f.write("    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'setup.settings')\n")
        f.write("    try:\n")
        f.write("        from django.core.management import execute_from_command_line\n")
        f.write("    except ImportError as exc:\n")
        f.write("        raise ImportError(\"Couldn't import Django\") from exc\n")
        f.write("    execute_from_command_line(sys.argv)\n\n")
        f.write("if __name__ == '__main__':\n")
        f.write("    main()\n")
    print("  OK manage.py")
    
    # 5. setup/settings.py
    with open('setup/setup/settings.py', 'w') as f:
        f.write("from pathlib import Path\n")
        f.write("from decouple import config\n")
        f.write("import os\n\n")
        f.write("BASE_DIR = Path(__file__).resolve().parent.parent\n\n")
        f.write("SECRET_KEY = config('SECRET_KEY')\n")
        f.write("DEBUG = config('DEBUG', default=True, cast=bool)\n")
        f.write("ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='localhost').split(',')\n\n")
        f.write("INSTALLED_APPS = [\n")
        f.write("    'django.contrib.admin',\n")
        f.write("    'django.contrib.auth',\n")
        f.write("    'django.contrib.contenttypes',\n")
        f.write("    'django.contrib.sessions',\n")
        f.write("    'django.contrib.messages',\n")
        f.write("    'django.contrib.staticfiles',\n")
        f.write("    'corsheaders',\n")
        f.write("    'simphony_integration',\n")
        f.write("]\n\n")
        f.write("MIDDLEWARE = [\n")
        f.write("    'django.middleware.security.SecurityMiddleware',\n")
        f.write("    'corsheaders.middleware.CorsMiddleware',\n")
        f.write("    'django.contrib.sessions.middleware.SessionMiddleware',\n")
        f.write("    'django.middleware.common.CommonMiddleware',\n")
        f.write("    'django.middleware.csrf.CsrfViewMiddleware',\n")
        f.write("    'django.contrib.auth.middleware.AuthenticationMiddleware',\n")
        f.write("    'django.contrib.messages.middleware.MessageMiddleware',\n")
        f.write("    'django.middleware.clickjacking.XFrameOptionsMiddleware',\n")
        f.write("]\n\n")
        f.write("ROOT_URLCONF = 'setup.urls'\n\n")
        f.write("TEMPLATES = [{\n")
        f.write("    'BACKEND': 'django.template.backends.django.DjangoTemplates',\n")
        f.write("    'DIRS': [BASE_DIR / 'templates'],\n")
        f.write("    'APP_DIRS': True,\n")
        f.write("    'OPTIONS': {'context_processors': [\n")
        f.write("        'django.template.context_processors.debug',\n")
        f.write("        'django.template.context_processors.request',\n")
        f.write("        'django.contrib.auth.context_processors.auth',\n")
        f.write("        'django.contrib.messages.context_processors.messages',\n")
        f.write("    ]},\n")
        f.write("}]\n\n")
        f.write("WSGI_APPLICATION = 'setup.wsgi.application'\n\n")
        f.write("DATABASES = {\n")
        f.write("    'default': {\n")
        f.write("        'ENGINE': 'django.db.backends.sqlite3',\n")
        f.write("        'NAME': BASE_DIR / 'db.sqlite3',\n")
        f.write("    }\n")
        f.write("}\n\n")
        f.write("AUTH_PASSWORD_VALIDATORS = [\n")
        f.write("    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},\n")
        f.write("    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},\n")
        f.write("    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},\n")
        f.write("    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},\n")
        f.write("]\n\n")
        f.write("LANGUAGE_CODE = 'pt-br'\n")
        f.write("TIME_ZONE = 'America/Sao_Paulo'\n")
        f.write("USE_I18N = True\n")
        f.write("USE_TZ = True\n\n")
        f.write("STATIC_URL = '/static/'\n")
        f.write("STATICFILES_DIRS = [BASE_DIR / 'static']\n")
        f.write("STATIC_ROOT = BASE_DIR / 'staticfiles'\n\n")
        f.write("MEDIA_URL = '/media/'\n")
        f.write("MEDIA_ROOT = BASE_DIR / 'media'\n\n")
        f.write("DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'\n\n")
        f.write("CORS_ALLOW_ALL_ORIGINS = DEBUG\n")
    print("  OK setup/settings.py")
    
    # 6. setup/urls.py
    with open('setup/setup/urls.py', 'w') as f:
        f.write("from django.contrib import admin\n")
        f.write("from django.urls import path, include\n\n")
        f.write("urlpatterns = [\n")
        f.write("    path('admin/', admin.site.urls),\n")
        f.write("    path('simphony/', include('simphony_integration.urls')),\n")
        f.write("]\n")
    print("  OK setup/urls.py")
    
    # 7. setup/wsgi.py
    with open('setup/setup/wsgi.py', 'w') as f:
        f.write("import os\n")
        f.write("from django.core.wsgi import get_wsgi_application\n\n")
        f.write("os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'setup.settings')\n")
        f.write("application = get_wsgi_application()\n")
    print("  OK setup/wsgi.py")
    
    # 8. setup/asgi.py
    with open('setup/setup/asgi.py', 'w') as f:
        f.write("import os\n")
        f.write("from django.core.asgi import get_asgi_application\n\n")
        f.write("os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'setup.settings')\n")
        f.write("application = get_asgi_application()\n")
    print("  OK setup/asgi.py")
    
    # 9. setup/__init__.py
    with open('setup/setup/__init__.py', 'w') as f:
        f.write("# Setup project\n")
    print("  OK setup/__init__.py")
    
    # 10. simphony_integration/models.py
    with open('setup/simphony_integration/models.py', 'w') as f:
        f.write("from django.db import models\n\n")
        f.write("class MenuItemLog(models.Model):\n")
        f.write("    nome_item = models.CharField(max_length=255)\n")
        f.write("    simphony_id = models.CharField(max_length=100, blank=True, null=True)\n")
        f.write("    payload_enviado = models.JSONField()\n")
        f.write("    resposta_api = models.JSONField()\n")
        f.write("    status_code = models.IntegerField()\n")
        f.write("    criado_em = models.DateTimeField(auto_now_add=True)\n\n")
        f.write("    def __str__(self):\n")
        f.write("        return f'{self.nome_item} - {self.criado_em}'\n")
    print("  OK simphony_integration/models.py")
    
    # 11. simphony_integration/forms.py
    with open('setup/simphony_integration/forms.py', 'w') as f:
        f.write("from django import forms\n\n")
        f.write("class MenuItemForm(forms.Form):\n")
        f.write("    nome_item = forms.CharField(max_length=255, label='Nome do Item')\n")
        f.write("    descricao = forms.CharField(required=False, label='Descricao', widget=forms.Textarea)\n")
        f.write("    preco = forms.DecimalField(label='Preco (R$)', min_value=0, decimal_places=2)\n")
        f.write("    major_group_id = forms.CharField(label='ID do Grupo Principal')\n")
        f.write("    menu_item_class_id = forms.CharField(label='ID da Classe do Item')\n")
        f.write("    taxa_servico = forms.DecimalField(required=False, label='Taxa de Servico (%)', min_value=0, max_value=100)\n")
        f.write("    ativo = forms.BooleanField(required=False, initial=True, label='Item Ativo')\n")
    print("  OK simphony_integration/forms.py")
    
    # 12. simphony_integration/admin.py
    with open('setup/simphony_integration/admin.py', 'w') as f:
        f.write("from django.contrib import admin\n")
        f.write("from .models import MenuItemLog\n\n")
        f.write("@admin.register(MenuItemLog)\n")
        f.write("class MenuItemLogAdmin(admin.ModelAdmin):\n")
        f.write("    list_display = ['nome_item', 'status_code', 'criado_em']\n")
        f.write("    list_filter = ['status_code', 'criado_em']\n")
        f.write("    search_fields = ['nome_item']\n")
    print("  OK simphony_integration/admin.py")
    
    # 13. simphony_integration/apps.py
    with open('setup/simphony_integration/apps.py', 'w') as f:
        f.write("from django.apps import AppConfig\n\n")
        f.write("class SimphonyIntegrationConfig(AppConfig):\n")
        f.write("    default_auto_field = 'django.db.models.BigAutoField'\n")
        f.write("    name = 'simphony_integration'\n")
    print("  OK simphony_integration/apps.py")
    
    # 14. simphony_integration/__init__.py
    with open('setup/simphony_integration/__init__.py', 'w') as f:
        f.write("# Simphony Integration App\n")
    print("  OK simphony_integration/__init__.py")
    
    # 15. simphony_integration/urls.py
    with open('setup/simphony_integration/urls.py', 'w') as f:
        f.write("from django.urls import path\n")
        f.write("from . import views\n\n")
        f.write("app_name = 'simphony_integration'\n\n")
        f.write("urlpatterns = [\n")
        f.write("    path('', views.dashboard, name='dashboard'),\n")
        f.write("    path('cadastrar/', views.cadastrar_item, name='cadastrar_item'),\n")
        f.write("    path('logs/', views.listar_logs, name='logs'),\n")
        f.write("]\n")
    print("  OK simphony_integration/urls.py")
    
    # 16. simphony_integration/views.py
    with open('setup/simphony_integration/views.py', 'w') as f:
        f.write("from django.shortcuts import render, redirect\n")
        f.write("from django.contrib import messages\n")
        f.write("from django.contrib.auth.decorators import login_required\n")
        f.write("from .forms import MenuItemForm\n")
        f.write("from .models import MenuItemLog\n\n")
        f.write("@login_required\n")
        f.write("def cadastrar_item(request):\n")
        f.write("    if request.method == 'POST':\n")
        f.write("        form = MenuItemForm(request.POST)\n")
        f.write("        if form.is_valid():\n")
        f.write("            messages.success(request, 'Item cadastrado com sucesso!')\n")
        f.write("            return redirect('simphony_integration:cadastrar_item')\n")
        f.write("    else:\n")
        f.write("        form = MenuItemForm()\n")
        f.write("    return render(request, 'simphony_integration/cadastro_item.html', {'form': form})\n\n")
        f.write("@login_required\n")
        f.write("def listar_logs(request):\n")
        f.write("    logs = MenuItemLog.objects.all().order_by('-criado_em')\n")
        f.write("    return render(request, 'simphony_integration/logs.html', {'logs': logs})\n\n")
        f.write("@login_required\n")
        f.write("def dashboard(request):\n")
        f.write("    total = MenuItemLog.objects.count()\n")
        f.write("    sucessos = MenuItemLog.objects.filter(status_code__in=[200,201]).count()\n")
        f.write("    return render(request, 'simphony_integration/dashboard.html', {'total_envios': total, 'sucessos': sucessos, 'erros': total - sucessos})\n")
    print("  OK simphony_integration/views.py")
    
    # 17. services/simphony_client.py
    with open('setup/simphony_integration/services/simphony_client.py', 'w') as f:
        f.write("import requests\nimport urllib.parse\nfrom decouple import config\n\n")
        f.write("class SimphonyAPIClient:\n")
        f.write("    def __init__(self):\n")
        f.write("        self.api_url = config('SIMPHONY_API_URL')\n")
        f.write("        self.token_url = config('SIMPHONY_TOKEN_URL')\n")
        f.write("        self.client_id = config('SIMPHONY_CLIENT_ID')\n")
        f.write("        self.client_secret = config('SIMPHONY_CLIENT_SECRET')\n")
        f.write("        self.org_name = config('SIMPHONY_ORG_SHORT_NAME')\n")
        f.write("        self.access_token = None\n\n")
        f.write("    def authenticate(self):\n")
        f.write("        endpoint = f'{self.token_url}/oidc-provider/v1/oauth2/token'\n")
        f.write("        response = requests.post(endpoint, data={\n")
        f.write("            'grant_type': 'client_credentials',\n")
        f.write("            'client_id': self.client_id,\n")
        f.write("            'client_secret': urllib.parse.quote(self.client_secret),\n")
        f.write("            'scope': 'openid'\n")
        f.write("        })\n")
        f.write("        self.access_token = response.json()['access_token']\n")
        f.write("        return True\n")
    print("  OK simphony_integration/services/simphony_client.py")
    
    # 18. services/__init__.py
    with open('setup/simphony_integration/services/__init__.py', 'w') as f:
        f.write("# Services module\n")
    print("  OK simphony_integration/services/__init__.py")
    
    # 19. templates/base.html
    with open('setup/templates/base.html', 'w') as f:
        f.write("<!DOCTYPE html>\n")
        f.write("<html>\n<head>\n")
        f.write("<title>Setup - Simphony Integration</title>\n")
        f.write("<link href='https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css' rel='stylesheet'>\n")
        f.write("</head>\n<body>\n")
        f.write("<nav class='navbar navbar-dark bg-dark'>\n")
        f.write("<div class='container'><span class='navbar-brand'>Setup - Simphony Integration</span></div>\n")
        f.write("</nav>\n")
        f.write("<div class='container mt-4'>\n")
        f.write("{% block content %}{% endblock %}\n")
        f.write("</div>\n</body>\n</html>\n")
    print("  OK templates/base.html")
    
    # 20. templates/simphony_integration/cadastro_item.html
    with open('setup/simphony_integration/templates/simphony_integration/cadastro_item.html', 'w') as f:
        f.write("{% extends 'base.html' %}\n")
        f.write("{% block content %}\n")
        f.write("<div class='card'>\n")
        f.write("<div class='card-header bg-primary text-white'><h3>Cadastrar Item no Simphony</h3></div>\n")
        f.write("<div class='card-body'>\n")
        f.write("<form method='post'>\n")
        f.write("    {% csrf_token %}\n")
        f.write("    {{ form.as_p }}\n")
        f.write("    <button type='submit' class='btn btn-success'>Cadastrar</button>\n")
        f.write("</form>\n")
        f.write("</div>\n</div>\n")
        f.write("{% endblock %}\n")
    print("  OK simphony_integration/templates/simphony_integration/cadastro_item.html")
    
    # 21. templates/simphony_integration/logs.html
    with open('setup/simphony_integration/templates/simphony_integration/logs.html', 'w') as f:
        f.write("{% extends 'base.html' %}\n")
        f.write("{% block content %}\n")
        f.write("<h2>Logs de Envio</h2>\n")
        f.write("<table class='table table-striped'>\n")
        f.write("<tr><th>Item</th><th>Status</th><th>Data</th></tr>\n")
        f.write("{% for log in logs %}\n")
        f.write("<tr>\n")
        f.write("    <td>{{ log.nome_item }}</td>\n")
        f.write("    <td>{{ log.status_code }}</td>\n")
        f.write("    <td>{{ log.criado_em }}</td>\n")
        f.write("</tr>\n")
        f.write("{% empty %}\n")
        f.write("<tr><td colspan='3'>Nenhum log encontrado</td></tr>\n")
        f.write("{% endfor %}\n")
        f.write("</table>\n")
        f.write("{% endblock %}\n")
    print("  OK simphony_integration/templates/simphony_integration/logs.html")
    
    # 22. templates/simphony_integration/dashboard.html
    with open('setup/simphony_integration/templates/simphony_integration/dashboard.html', 'w') as f:
        f.write("{% extends 'base.html' %}\n")
        f.write("{% block content %}\n")
        f.write("<h2>Dashboard</h2>\n")
        f.write("<div class='row'>\n")
        f.write("<div class='col-md-4'><div class='card bg-info text-white'><div class='card-body'><h3>{{ total_envios }}</h3><p>Total de Envios</p></div></div></div>\n")
        f.write("<div class='col-md-4'><div class='card bg-success text-white'><div class='card-body'><h3>{{ sucessos }}</h3><p>Sucessos</p></div></div></div>\n")
        f.write("<div class='col-md-4'><div class='card bg-danger text-white'><div class='card-body'><h3>{{ erros }}</h3><p>Erros</p></div></div></div>\n")
        f.write("</div>\n")
        f.write("<a href='{% url \"simphony_integration:cadastrar_item\" %}' class='btn btn-primary mt-3'>Cadastrar Item</a>\n")
        f.write("<a href='{% url \"simphony_integration:logs\" %}' class='btn btn-secondary mt-3'>Ver Logs</a>\n")
        f.write("{% endblock %}\n")
    print("  OK simphony_integration/templates/simphony_integration/dashboard.html")
    
    # 23. testar_conexao.py
    with open('setup/testar_conexao.py', 'w') as f:
        f.write("#!/usr/bin/env python\n")
        f.write("import requests\nimport os\nfrom dotenv import load_dotenv\n\n")
        f.write("load_dotenv()\n\n")
        f.write("print('Testando conexao com Simphony...')\n")
        f.write("token_url = os.getenv('SIMPHONY_TOKEN_URL')\n")
        f.write("client_id = os.getenv('SIMPHONY_CLIENT_ID')\n")
        f.write("client_secret = os.getenv('SIMPHONY_CLIENT_SECRET')\n\n")
        f.write("endpoint = f'{token_url}/oidc-provider/v1/oauth2/token'\n")
        f.write("response = requests.post(endpoint, data={\n")
        f.write("    'grant_type': 'client_credentials',\n")
        f.write("    'client_id': client_id,\n")
        f.write("    'client_secret': client_secret,\n")
        f.write("    'scope': 'openid'\n")
        f.write("})\n\n")
        f.write("if response.status_code == 200:\n")
        f.write("    print('Autenticacao OK!')\n")
        f.write("    print(f'Token: {response.json()[\\\"access_token\\\"][:50]}...')\n")
        f.write("else:\n")
        f.write("    print(f'Erro: {response.status_code} - {response.text}')\n")
    print("  OK testar_conexao.py")
    
    print("=" * 70)
    print("PROJETO CRIADO COM SUCESSO!")
    print("=" * 70)
    print("\nProximo passos:")
    print("  cd setup")
    print("  python -m venv venv")
    print("  source venv/bin/activate  # ou venv\\Scripts\\activate no Windows")
    print("  pip install -r requirements.txt")
    print("  python manage.py migrate")
    print("  python manage.py createsuperuser")
    print("  python testar_conexao.py")
    print("  python manage.py runserver")

if __name__ == '__main__':
    criar_estrutura()
