#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Script para criar projeto Django 'setup' com integração Oracle Simphony
Execute: python criar_projeto_setup.py
"""

import os
import sys

def criar_estrutura():
    """Cria toda a estrutura de pastas e arquivos do projeto"""
    
    # Estrutura base
    pastas = [
        'setup_project',
        'setup_project/setup_project',
        'setup_project/simphony_integration',
        'setup_project/simphony_integration/services',
        'setup_project/simphony_integration/templates',
        'setup_project/simphony_integration/templates/simphony_integration',
        'setup_project/templates',
        'setup_project/static',
        'setup_project/static/css',
        'setup_project/static/js',
        'setup_project/media',
        'setup_project/logs',
    ]
    
    print("📁 Criando estrutura de pastas...")
    for pasta in pastas:
        os.makedirs(pasta, exist_ok=True)
        print(f"  ✓ {pasta}/")
    
    # ==================== ARQUIVOS DO PROJETO ====================
    
    # 1. requirements.txt
    conteudo = """Django==4.2.7
requests==2.31.0
python-decouple==3.8
psycopg2-binary==2.9.9
django-cors-headers==4.3.1
python-dotenv==1.0.0
"""
    with open('setup_project/requirements.txt', 'w') as f:
        f.write(conteudo)
    print("  ✓ requirements.txt")
    
    # 2. .env
    conteudo = """# Oracle Simphony Credentials
SIMPHONY_API_URL=https://api.simphony.example.com/v2/
SIMPHONY_TOKEN_URL=https://auth.simphony.example.com/oauth2/token
SIMPHONY_CLIENT_ID=seu_client_id_aqui
SIMPHONY_CLIENT_SECRET=seu_client_secret_aqui
SIMPHONY_ORG_SHORT_NAME=RESTAURANTE01

# Django Settings
SECRET_KEY=seu-secret-key-muito-seguro-aqui-mude-em-producao
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1

# Database
DB_NAME=setup_db
DB_USER=postgres
DB_PASSWORD=senha
DB_HOST=localhost
DB_PORT=5432
"""
    with open('setup_project/.env', 'w') as f:
        f.write(conteudo)
    print("  ✓ .env")
    
    # 3. .gitignore
    conteudo = """# Python
__pycache__/
*.py[cod]
*.so
.Python
env/
venv/
ENV/
env.bak/
venv.bak/

# Django
*.log
*.pot
*.pyc
local_settings.py
db.sqlite3
media/
staticfiles/

# Environment
.env
.venv

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Project specific
logs/
*.sql
"""
    with open('setup_project/.gitignore', 'w') as f:
        f.write(conteudo)
    print("  ✓ .gitignore")
    
    # 4. README.md
    conteudo = """# Setup Project - Integração Oracle Simphony

Sistema para cadastro de itens no Oracle Simphony via API.

## Configuração Rápida

### 1. Criar ambiente virtual
```bash
cd setup_project
python -m venv venv
source venv/bin/activate  # Linux/Mac
venv\\Scripts\\activate     # Windows
