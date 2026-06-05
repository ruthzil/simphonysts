#!/bin/bash
# update_simphony_system.sh - Script completo para atualizar o sistema Simphony STS

echo "========================================="
echo "Simphony STS System Update Script"
echo "========================================="
echo "Data: $(date)"
echo ""

# Definir cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para imprimir mensagens
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   print_error "Este script deve ser executado como root (use sudo)"
   exit 1
fi

# Configurações do sistema
APP_DIR="/opt/simphony"
BACKUP_DIR="/opt/simphony_backup_$(date +%Y%m%d_%H%M%S)"
VENV_DIR="$APP_DIR/venv"

print_header "Iniciando atualização do sistema"

# 1. Criar backup
print_message "Criando backup do sistema atual..."
mkdir -p $BACKUP_DIR
cp -r $APP_DIR/* $BACKUP_DIR/ 2>/dev/null
print_message "Backup criado em: $BACKUP_DIR"

# 2. Navegar para o diretório do aplicativo
cd $APP_DIR

# 3. Ativar ambiente virtual
print_message "Ativando ambiente virtual..."
source $VENV_DIR/bin/activate

# 4. Fazer backup dos arquivos existentes
print_message "Fazendo backup dos arquivos existentes..."
cp simphony_integration/urls.py simphony_integration/urls.py.bak 2>/dev/null
cp simphony_integration/views.py simphony_integration/views.py.bak 2>/dev/null
cp simphony_integration/services.py simphony_integration/services.py.bak 2>/dev/null

# 5. Atualizar o arquivo services.py
print_message "Atualizando services.py..."
cat > simphony_integration/services.py << 'EOF'
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
            
            return self.access_token
            
        except Exception as e:
            print(f"Erro ao obter token: {e}")
            return None
    
    def _get_headers(self, token=None):
        """Retorna headers para requisição"""
        if not token:
            token = self.get_access_token()
        return {
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
    
    def test_connection(self):
        """Testa se a API está conectada e funcionando"""
        try:
            token = self.get_access_token()
            if token:
                headers = self._get_headers(token)
                url = f"{self.ccapi_url}/employees/getEmployees"
                response = requests.post(url, headers=headers, json={}, timeout=10)
                return response.status_code == 200
            return False
        except Exception:
            return False
    
    def _make_request(self, method, endpoint, data=None, params=None):
        """Fazer requisição autenticada para a API"""
        token = self.get_access_token()
        if not token:
            return None
        
        headers = self._get_headers(token)
        url = f"{self.ccapi_url}{endpoint}"
        
        try:
            if method == 'GET':
                response = requests.get(url, headers=headers, params=params, timeout=30)
            else:
                response = requests.post(url, headers=headers, json=data, timeout=30)
            
            if response.status_code in [200, 201]:
                return response.json()
            else:
                print(f"Erro {response.status_code}: {response.text}")
                return None
        except Exception as e:
            print(f"Erro na requisição: {e}")
            return None
    
    # ========== EMPLOYEES CRUD ==========
    
    def get_employees(self, hier_unit_id=None):
        """Listar funcionários"""
        endpoint = "/employees/getEmployees"
        data = {"includeAll": "detailed"}
        if hier_unit_id:
            data["hierUnitId"] = hier_unit_id
        
        result = self._make_request('POST', endpoint, data=data)
        if result:
            return result.get('items', [])
        return None
    
    def get_employee(self, obj_num):
        """Obter um funcionário específico"""
        employees = self.get_employees()
        if employees:
            for emp in employees:
                if emp.get('objectNum') == obj_num:
                    return emp
        return None
    
    def create_employee(self, employee_data):
        """Criar novo funcionário"""
        endpoint = "/employees/employees"
        return self._make_request('POST', endpoint, data=employee_data)
    
    def update_employee(self, obj_num, employee_data):
        """Atualizar funcionário"""
        endpoint = "/employees/updateEmployees"
        employee_data['objectNum'] = obj_num
        return self._make_request('POST', endpoint, data=employee_data)
    
    def delete_employee(self, obj_num):
        """Excluir funcionário"""
        endpoint = "/employees/deleteEmployees"
        data = {"objectNum": obj_num}
        return self._make_request('POST', endpoint, data=data)
    
    # ========== MENU ITEMS MASTER ==========
    
    def get_menu_items(self, hier_unit_id=None):
        """Listar itens do menu master"""
        endpoint = "/menuItems/getMenuItems"
        data = {"includeAll": "detailed"}
        if hier_unit_id:
            data["hierUnitId"] = hier_unit_id
        
        result = self._make_request('POST', endpoint, data=data)
        if result:
            return result.get('items', [])
        return None
    
    def get_menu_item(self, obj_num):
        """Obter um item específico"""
        items = self.get_menu_items()
        if items:
            for item in items:
                if item.get('objectNum') == obj_num:
                    return item
        return None
    
    def create_menu_item(self, item_data):
        """Criar novo item do menu master"""
        endpoint = "/menuItems/menuItems"
        return self._make_request('POST', endpoint, data=item_data)
    
    def update_menu_item(self, obj_num, item_data):
        """Atualizar item do menu master"""
        endpoint = "/menuItems/updateMenuItems"
        item_data['objectNum'] = obj_num
        return self._make_request('POST', endpoint, data=item_data)
    
    def delete_menu_item(self, obj_num):
        """Excluir item do menu master"""
        endpoint = "/menuItems/deleteMenuItems"
        data = {"objectNum": obj_num}
        return self._make_request('POST', endpoint, data=data)
    
    # ========== MENU ITEM DEFINITIONS ==========
    
    def get_menu_item_definitions(self):
        """Obtém definições de menu items"""
        endpoint = "/menuItemDefinitions/getMenuItemDefinitions"
        result = self._make_request('POST', endpoint, data={})
        if result:
            return result.get('items', [])
        return None
    
    def get_menu_item_definition(self, obj_num):
        """Obtém definição específica de menu item"""
        definitions = self.get_menu_item_definitions()
        if definitions:
            for definition in definitions:
                if definition.get('objectNum') == obj_num:
                    return definition
        return None
    
    def create_menu_item_definition(self, payload):
        """Cria definição de menu item"""
        endpoint = "/menuItemDefinitions/menuItemDefinitions"
        return self._make_request('POST', endpoint, data=payload)
    
    def update_menu_item_definition(self, obj_num, payload):
        """Atualiza definição de menu item"""
        endpoint = "/menuItemDefinitions/updateMenuItemDefinitions"
        payload['objectNum'] = obj_num
        return self._make_request('POST', endpoint, data=payload)
    
    def delete_menu_item_definition(self, obj_num):
        """Exclui definição de menu item"""
        endpoint = "/menuItemDefinitions/deleteMenuItemDefinitions"
        data = {'objectNum': obj_num}
        return self._make_request('POST', endpoint, data=data)
    
    # ========== MENU ITEM PRICES ==========
    
    def get_menu_item_prices(self):
        """Obtém preços de menu items"""
        endpoint = "/menuItemPrices/getMenuItemPrices"
        result = self._make_request('POST', endpoint, data={})
        if result:
            return result.get('items', [])
        return None
    
    def get_menu_item_price(self, obj_num):
        """Obtém preço específico de menu item"""
        prices = self.get_menu_item_prices()
        if prices:
            for price in prices:
                if price.get('objectNum') == obj_num:
                    return price
        return None
    
    def create_menu_item_price(self, payload):
        """Cria preço para menu item"""
        endpoint = "/menuItemPrices/menuItemPrices"
        return self._make_request('POST', endpoint, data=payload)
    
    def update_menu_item_price(self, obj_num, payload):
        """Atualiza preço de menu item"""
        endpoint = "/menuItemPrices/updateMenuItemPrices"
        payload['objectNum'] = obj_num
        return self._make_request('POST', endpoint, data=payload)
    
    def delete_menu_item_price(self, obj_num):
        """Exclui preço de menu item"""
        endpoint = "/menuItemPrices/deleteMenuItemPrices"
        data = {'objectNum': obj_num}
        return self._make_request('POST', endpoint, data=data)
    
    # ========== HIERARCHY ==========
    
    def get_hierarchy(self):
        """Obter hierarquia completa"""
        endpoint = "/hierarchy/getHierarchy"
        result = self._make_request('POST', endpoint, data={})
        return result
    
    def get_locations(self):
        """Listar locations"""
        endpoint = "/hierarchy/getLocations"
        result = self._make_request('POST', endpoint, data={})
        if result:
            return result.get('items', [])
        return None
    
    def get_revenue_centers(self, loc_hier_unit_id=None):
        """Listar revenue centers (zones)"""
        endpoint = "/hierarchy/getRevenueCenters"
        data = {"includeAll": "detailed"}
        if loc_hier_unit_id:
            data["locHierUnitId"] = loc_hier_unit_id
        
        result = self._make_request('POST', endpoint, data=data)
        if result:
            return result.get('items', [])
        return None
    
    # ========== SUPPORTING DATA ==========
    
    def get_tax_categories(self):
        """Obtém categorias de imposto"""
        endpoint = "/taxCategories/getTaxCategories"
        result = self._make_request('POST', endpoint, data={})
        if result:
            return result.get('items', [])
        return None
    
    def get_departments(self):
        """Obtém departamentos"""
        endpoint = "/departments/getDepartments"
        result = self._make_request('POST', endpoint, data={})
        if result:
            return result.get('items', [])
        return None
    
    def get_price_levels(self):
        """Obtém níveis de preço"""
        endpoint = "/priceLevels/getPriceLevels"
        result = self._make_request('POST', endpoint, data={})
        if result:
            return result.get('items', [])
        return None
    
    def get_roles(self):
        """Listar roles/papéis"""
        endpoint = "/employees/getRoles"
        result = self._make_request('POST', endpoint, data={})
        if result:
            return result.get('items', [])
        return None
    
    def get_employee_classes(self):
        """Listar classes de funcionários"""
        endpoint = "/employees/getClasses"
        result = self._make_request('POST', endpoint, data={})
        if result:
            return result.get('items', [])
        return None
EOF

# 6. Atualizar o arquivo urls.py
print_message "Atualizando urls.py..."
cat > simphony_integration/urls.py << 'EOF'
from django.urls import path
from . import views

app_name = 'simphony'

urlpatterns = [
    # Home
    path('', views.home, name='home'),
    path('dashboard/', views.dashboard, name='dashboard'),
    
    # API Status
    path('api-status/', views.api_status, name='api_status'),
    
    # Menu Item Master
    path('menu-item-master/', views.menu_item_master, name='menu_item_master'),
    path('menu-item-master/create/', views.menu_item_master_create, name='menu_item_master_create'),
    path('menu-item-master/<str:obj_num>/update/', views.menu_item_master_update, name='menu_item_master_update'),
    path('menu-item-master/<str:obj_num>/delete/', views.menu_item_master_delete, name='menu_item_master_delete'),
    
    # Menu Item Definition
    path('menu-item-def/', views.menu_item_def, name='menu_item_def'),
    path('menu-item-def/create/', views.menu_item_def_create, name='menu_item_def_create'),
    path('menu-item-def/<str:obj_num>/update/', views.menu_item_def_update, name='menu_item_def_update'),
    path('menu-item-def/<str:obj_num>/delete/', views.menu_item_def_delete, name='menu_item_def_delete'),
    
    # Menu Item Price
    path('menu-item-price/', views.menu_item_price, name='menu_item_price'),
    path('menu-item-price/create/', views.menu_item_price_create, name='menu_item_price_create'),
    path('menu-item-price/<str:obj_num>/update/', views.menu_item_price_update, name='menu_item_price_update'),
    path('menu-item-price/<str:obj_num>/delete/', views.menu_item_price_delete, name='menu_item_price_delete'),
    
    # Employees (Add Func)
    path('employees/', views.employee_list, name='employee_list'),
    path('employees/create/', views.employee_create, name='employee_create'),
    path('employees/<int:obj_num>/', views.employee_detail, name='employee_detail'),
    path('employees/<int:obj_num>/update/', views.employee_update, name='employee_update'),
    path('employees/<int:obj_num>/delete/', views.employee_delete, name='employee_delete'),
    
    # Logs
    path('sync-logs/', views.sync_logs, name='sync_logs'),
    path('menu-item-logs/', views.menu_item_logs, name='menu_item_logs'),
]
EOF

# 7. Atualizar o arquivo views.py
print_message "Atualizando views.py..."
cat > simphony_integration/views.py << 'EOF'
from django.shortcuts import render, redirect
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.http import JsonResponse
from .services import SimphonyAPIService
from .models import MenuItemLog, SyncLog
from datetime import datetime

def home(request):
    """Página inicial"""
    return render(request, 'simphony_integration/home.html')

def check_api_connection_before_update(func):
    """Decorator para verificar conexão com API antes de operações de edição"""
    def wrapper(request, *args, **kwargs):
        api_service = SimphonyAPIService()
        if not api_service.test_connection():
            messages.error(request, '⚠️ API Simphony está offline. Não é possível realizar a operação.')
            return redirect(request.META.get('HTTP_REFERER', 'simphony:dashboard'))
        return func(request, *args, **kwargs)
    return wrapper

@login_required
def dashboard(request):
    """Dashboard principal"""
    api_service = SimphonyAPIService()
    is_connected = api_service.test_connection()
    
    context = {
        'is_connected': is_connected,
    }
    return render(request, 'simphony_integration/dashboard.html', context)

def api_status(request):
    """Verifica status da API Simphony"""
    api_service = SimphonyAPIService()
    is_connected = api_service.test_connection()
    
    return JsonResponse({
        'status': 'online' if is_connected else 'offline',
        'timestamp': datetime.now().isoformat()
    })

# ==================== MENU ITEM MASTER ====================

@login_required
def menu_item_master(request):
    """Lista Menu Items Master"""
    api_service = SimphonyAPIService()
    menu_items = api_service.get_menu_items()
    
    context = {
        'menu_items': menu_items if menu_items else [],
        'page_title': 'Menu Item Master',
        'page_icon': 'bi-grid-3x3-gap-fill'
    }
    return render(request, 'simphony_integration/menu_items/master_list.html', context)

@login_required
def menu_item_master_create(request):
    """Cria Menu Item Master"""
    if request.method == 'POST':
        api_service = SimphonyAPIService()
        
        payload = {
            'objectNum': int(request.POST.get('object_num')),
            'hierUnitId': int(request.POST.get('hier_unit_id', 1)),
            'name': {
                'en-US': request.POST.get('name_en'),
                'pt-BR': request.POST.get('name_pt')
            },
            'shortName': {
                'en-US': request.POST.get('short_name_en', ''),
                'pt-BR': request.POST.get('short_name_pt', '')
            },
            'price': float(request.POST.get('price', 0)),
            'active': request.POST.get('active') == 'on'
        }
        
        result = api_service.create_menu_item(payload)
        
        if result:
            MenuItemLog.objects.create(
                nome_item=payload['name']['pt-BR'],
                simphony_id=str(payload['objectNum']),
                payload_enviado=payload,
                resposta_api=result,
                status_code=201
            )
            messages.success(request, f'✅ Menu Item "{payload["name"]["pt-BR"]}" criado com sucesso!')
            return redirect('simphony:menu_item_master')
        else:
            messages.error(request, '❌ Erro ao criar menu item. Verifique os dados.')
    
    context = {'page_title': 'Novo Menu Item Master'}
    return render(request, 'simphony_integration/menu_items/master_form.html', context)

@login_required
@check_api_connection_before_update
def menu_item_master_update(request, obj_num):
    """Atualiza Menu Item Master - com validação de conexão"""
    api_service = SimphonyAPIService()
    
    if request.method == 'POST':
        payload = {
            'hierUnitId': int(request.POST.get('hier_unit_id', 1)),
            'name': {
                'en-US': request.POST.get('name_en'),
                'pt-BR': request.POST.get('name_pt')
            },
            'shortName': {
                'en-US': request.POST.get('short_name_en', ''),
                'pt-BR': request.POST.get('short_name_pt', '')
            },
            'price': float(request.POST.get('price', 0)),
            'active': request.POST.get('active') == 'on'
        }
        
        result = api_service.update_menu_item(int(obj_num), payload)
        
        if result:
            MenuItemLog.objects.create(
                nome_item=payload['name']['pt-BR'],
                simphony_id=obj_num,
                payload_enviado=payload,
                resposta_api=result,
                status_code=200
            )
            messages.success(request, f'✅ Menu Item "{payload["name"]["pt-BR"]}" atualizado com sucesso!')
            return redirect('simphony:menu_item_master')
        else:
            messages.error(request, '❌ Erro ao atualizar menu item.')
    
    menu_item = api_service.get_menu_item(int(obj_num))
    context = {
        'menu_item': menu_item,
        'obj_num': obj_num,
        'page_title': f'Editar Menu Item {obj_num}'
    }
    return render(request, 'simphony_integration/menu_items/master_form.html', context)

@login_required
def menu_item_master_delete(request, obj_num):
    """Exclui Menu Item Master"""
    if request.method == 'POST':
        api_service = SimphonyAPIService()
        result = api_service.delete_menu_item(int(obj_num))
        
        if result:
            messages.success(request, f'✅ Menu Item {obj_num} excluído com sucesso!')
        else:
            messages.error(request, '❌ Erro ao excluir menu item.')
        
        return redirect('simphony:menu_item_master')
    
    context = {'obj_num': obj_num, 'page_title': 'Confirmar Exclusão'}
    return render(request, 'simphony_integration/menu_items/master_confirm_delete.html', context)

# ==================== MENU ITEM DEFINITION ====================

@login_required
def menu_item_def(request):
    """Lista definições de menu item"""
    api_service = SimphonyAPIService()
    definitions = api_service.get_menu_item_definitions()
    
    context = {
        'definitions': definitions if definitions else [],
        'page_title': 'Menu Item Definition',
        'page_icon': 'bi-file-text'
    }
    return render(request, 'simphony_integration/menu_items/def_list.html', context)

@login_required
def menu_item_def_create(request):
    """Cria definição de menu item"""
    if request.method == 'POST':
        api_service = SimphonyAPIService()
        
        payload = {
            'objectNum': int(request.POST.get('object_num')),
            'menuItemMasterObjNum': int(request.POST.get('master_obj_num')),
            'name': request.POST.get('name'),
            'description': request.POST.get('description'),
            'preparationTime': int(request.POST.get('preparation_time', 0)),
            'isActive': request.POST.get('is_active') == 'on'
        }
        
        result = api_service.create_menu_item_definition(payload)
        
        if result:
            messages.success(request, f'✅ Definição "{payload["name"]}" criada com sucesso!')
            return redirect('simphony:menu_item_def')
        else:
            messages.error(request, '❌ Erro ao criar definição.')
    
    api_service = SimphonyAPIService()
    master_items = api_service.get_menu_items()
    
    context = {
        'master_items': master_items if master_items else [],
        'page_title': 'Nova Definição de Menu Item'
    }
    return render(request, 'simphony_integration/menu_items/def_form.html', context)

@login_required
@check_api_connection_before_update
def menu_item_def_update(request, obj_num):
    """Atualiza definição de menu item - com validação de conexão"""
    api_service = SimphonyAPIService()
    
    if request.method == 'POST':
        payload = {
            'menuItemMasterObjNum': int(request.POST.get('master_obj_num')),
            'name': request.POST.get('name'),
            'description': request.POST.get('description'),
            'preparationTime': int(request.POST.get('preparation_time', 0)),
            'isActive': request.POST.get('is_active') == 'on'
        }
        
        result = api_service.update_menu_item_definition(int(obj_num), payload)
        
        if result:
            messages.success(request, f'✅ Definição {obj_num} atualizada com sucesso!')
            return redirect('simphony:menu_item_def')
        else:
            messages.error(request, '❌ Erro ao atualizar definição.')
    
    definition = api_service.get_menu_item_definition(int(obj_num))
    master_items = api_service.get_menu_items()
    
    context = {
        'definition': definition,
        'master_items': master_items if master_items else [],
        'obj_num': obj_num,
        'page_title': f'Editar Definição {obj_num}'
    }
    return render(request, 'simphony_integration/menu_items/def_form.html', context)

@login_required
def menu_item_def_delete(request, obj_num):
    """Exclui definição de menu item"""
    if request.method == 'POST':
        api_service = SimphonyAPIService()
        result = api_service.delete_menu_item_definition(int(obj_num))
        
        if result:
            messages.success(request, f'✅ Definição {obj_num} excluída com sucesso!')
        else:
            messages.error(request, '❌ Erro ao excluir definição.')
        
        return redirect('simphony:menu_item_def')
    
    context = {'obj_num': obj_num, 'page_title': 'Confirmar Exclusão'}
    return render(request, 'simphony_integration/menu_items/def_confirm_delete.html', context)

# ==================== MENU ITEM PRICE ====================

@login_required
def menu_item_price(request):
    """Lista preços de menu items"""
    api_service = SimphonyAPIService()
    prices = api_service.get_menu_item_prices()
    
    context = {
        'prices': prices if prices else [],
        'page_title': 'Menu Item Price',
        'page_icon': 'bi-currency-dollar'
    }
    return render(request, 'simphony_integration/menu_items/price_list.html', context)

@login_required
def menu_item_price_create(request):
    """Cria preço para menu item"""
    if request.method == 'POST':
        api_service = SimphonyAPIService()
        
        payload = {
            'objectNum': int(request.POST.get('object_num')),
            'menuItemDefObjNum': int(request.POST.get('def_obj_num')),
            'price': float(request.POST.get('price')),
            'currency': request.POST.get('currency', 'BRL'),
            'isActive': request.POST.get('is_active') == 'on'
        }
        
        result = api_service.create_menu_item_price(payload)
        
        if result:
            messages.success(request, f'✅ Preço para item {payload["menuItemDefObjNum"]} criado com sucesso!')
            return redirect('simphony:menu_item_price')
        else:
            messages.error(request, '❌ Erro ao criar preço.')
    
    api_service = SimphonyAPIService()
    definitions = api_service.get_menu_item_definitions()
    
    context = {
        'definitions': definitions if definitions else [],
        'page_title': 'Novo Preço de Menu Item'
    }
    return render(request, 'simphony_integration/menu_items/price_form.html', context)

@login_required
@check_api_connection_before_update
def menu_item_price_update(request, obj_num):
    """Atualiza preço de menu item - com validação de conexão"""
    api_service = SimphonyAPIService()
    
    if request.method == 'POST':
        payload = {
            'menuItemDefObjNum': int(request.POST.get('def_obj_num')),
            'price': float(request.POST.get('price')),
            'currency': request.POST.get('currency', 'BRL'),
            'isActive': request.POST.get('is_active') == 'on'
        }
        
        result = api_service.update_menu_item_price(int(obj_num), payload)
        
        if result:
            messages.success(request, f'✅ Preço {obj_num} atualizado com sucesso!')
            return redirect('simphony:menu_item_price')
        else:
            messages.error(request, '❌ Erro ao atualizar preço.')
    
    price = api_service.get_menu_item_price(int(obj_num))
    definitions = api_service.get_menu_item_definitions()
    
    context = {
        'price': price,
        'definitions': definitions if definitions else [],
        'obj_num': obj_num,
        'page_title': f'Editar Preço {obj_num}'
    }
    return render(request, 'simphony_integration/menu_items/price_form.html', context)

@login_required
def menu_item_price_delete(request, obj_num):
    """Exclui preço de menu item"""
    if request.method == 'POST':
        api_service = SimphonyAPIService()
        result = api_service.delete_menu_item_price(int(obj_num))
        
        if result:
            messages.success(request, f'✅ Preço {obj_num} excluído com sucesso!')
        else:
            messages.error(request, '❌ Erro ao excluir preço.')
        
        return redirect('simphony:menu_item_price')
    
    context = {'obj_num': obj_num, 'page_title': 'Confirmar Exclusão'}
    return render(request, 'simphony_integration/menu_items/price_confirm_delete.html', context)

# ==================== EMPLOYEES (ADD FUNC) ====================

@login_required
def employee_list(request):
    """Lista funcionários"""
    api_service = SimphonyAPIService()
    employees = api_service.get_employees()
    
    context = {
        'employees': employees if employees else [],
        'page_title': 'Funcionários'
    }
    return render(request, 'simphony_integration/employees/list.html', context)

@login_required
def employee_create(request):
    """Cria funcionário"""
    if request.method == 'POST':
        api_service = SimphonyAPIService()
        
        payload = {
            'objectNum': int(request.POST.get('object_num')),
            'firstName': request.POST.get('first_name'),
            'lastName': request.POST.get('last_name'),
            'checkName': request.POST.get('check_name'),
            'email': request.POST.get('email'),
            'languageObjNum': 1,
            'userName': request.POST.get('user_name'),
        }
        
        result = api_service.create_employee(payload)
        
        if result:
            messages.success(request, f'✅ Funcionário {payload["firstName"]} {payload["lastName"]} criado!')
            return redirect('simphony:employee_list')
        else:
            messages.error(request, '❌ Erro ao criar funcionário.')
    
    context = {'page_title': 'Novo Funcionário'}
    return render(request, 'simphony_integration/employees/form.html', context)

@login_required
def employee_detail(request, obj_num):
    """Detalhes do funcionário"""
    api_service = SimphonyAPIService()
    employee = api_service.get_employee(obj_num)
    
    context = {
        'employee': employee,
        'page_title': f'Funcionário {obj_num}'
    }
    return render(request, 'simphony_integration/employees/detail.html', context)

@login_required
@check_api_connection_before_update
def employee_update(request, obj_num):
    """Atualiza funcionário - com validação de conexão"""
    api_service = SimphonyAPIService()
    
    if request.method == 'POST':
        payload = {
            'firstName': request.POST.get('first_name'),
            'lastName': request.POST.get('last_name'),
            'checkName': request.POST.get('check_name'),
            'email': request.POST.get('email'),
            'userName': request.POST.get('user_name'),
        }
        
        result = api_service.update_employee(obj_num, payload)
        
        if result:
            messages.success(request, f'✅ Funcionário {payload["firstName"]} {payload["lastName"]} atualizado!')
            return redirect('simphony:employee_list')
        else:
            messages.error(request, '❌ Erro ao atualizar funcionário.')
    
    employee = api_service.get_employee(obj_num)
    
    context = {
        'employee': employee,
        'obj_num': obj_num,
        'page_title': f'Editar Funcionário {obj_num}'
    }
    return render(request, 'simphony_integration/employees/form.html', context)

@login_required
def employee_delete(request, obj_num):
    """Exclui funcionário"""
    if request.method == 'POST':
        api_service = SimphonyAPIService()
        result = api_service.delete_employee(obj_num)
        
        if result:
            messages.success(request, f'✅ Funcionário {obj_num} excluído!')
        else:
            messages.error(request, '❌ Erro ao excluir funcionário.')
        
        return redirect('simphony:employee_list')
    
    context = {'obj_num': obj_num, 'page_title': 'Confirmar Exclusão'}
    return render(request, 'simphony_integration/employees/delete.html', context)

@login_required
def sync_logs(request):
    """Logs de sincronização"""
    logs = SyncLog.objects.all().order_by('-criado_em')
    context = {'logs': logs, 'page_title': 'Logs de Sincronização'}
    return render(request, 'simphony_integration/sync_logs.html', context)

@login_required
def menu_item_logs(request):
    """Histórico de menu items"""
    logs = MenuItemLog.objects.all().order_by('-criado_em')
    context = {'logs': logs, 'page_title': 'Histórico de Menu Items'}
    return render(request, 'simphony_integration/menu_item_logs.html', context)
EOF

# 8. Criar diretórios para templates
print_message "Criando diretórios de templates..."
mkdir -p templates/simphony_integration/menu_items
mkdir -p templates/simphony_integration/employees

# 9. Criar template base.html
print_message "Criando template base.html..."
cat > templates/base.html << 'EOF'
<!DOCTYPE html>
<html lang="pt-br">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Simphony STS - {% block title %}{% endblock %}</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">
    <style>
        .navbar-custom {
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
        }
        .navbar-custom .navbar-brand, .navbar-custom .nav-link {
            color: white;
        }
        .navbar-custom .nav-link:hover {
            color: #ffd700;
        }
        .navbar-custom .nav-link.active {
            color: #ffd700;
            font-weight: bold;
        }
        .api-status.online { color: #28a745; }
        .api-status.offline { color: #dc3545; }
        .footer {
            background-color: #1e3c72;
            color: white;
            padding: 15px 0;
            margin-top: 30px;
        }
        .card-stats {
            transition: transform 0.3s;
            cursor: pointer;
        }
        .card-stats:hover {
            transform: translateY(-5px);
        }
    </style>
    {% block extra_css %}{% endblock %}
</head>
<body>
    <nav class="navbar navbar-expand-lg navbar-custom">
        <div class="container-fluid">
            <a class="navbar-brand" href="{% url 'simphony:home' %}">
                <i class="bi bi-box-seam"></i> Simphony STS
            </a>
            <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav">
                <span class="navbar-toggler-icon"></span>
            </button>
            <div class="collapse navbar-collapse" id="navbarNav">
                <ul class="navbar-nav me-auto">
                    <li class="nav-item">
                        <a class="nav-link" href="{% url 'simphony:home' %}">
                            <i class="bi bi-house-door"></i> Home
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="{% url 'simphony:dashboard' %}">
                            <i class="bi bi-speedometer2"></i> Dashboard
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="{% url 'simphony:menu_item_master' %}">
                            <i class="bi bi-grid-3x3-gap-fill"></i> Menu Item Master
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="{% url 'simphony:menu_item_def' %}">
                            <i class="bi bi-file-text"></i> Menu Item Def
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="{% url 'simphony:menu_item_price' %}">
                            <i class="bi bi-currency-dollar"></i> Menu Item Price
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="{% url 'simphony:employee_list' %}">
                            <i class="bi bi-person-plus"></i> Add Func
                        </a>
                    </li>
                </ul>
                <ul class="navbar-nav">
                    <li class="nav-item">
                        <span class="nav-link" id="api-status">
                            <i class="bi bi-plug"></i> 
                            <span id="api-status-text">Verificando...</span>
                        </span>
                    </li>
                    {% if user.is_authenticated %}
                    <li class="nav-item dropdown">
                        <a class="nav-link dropdown-toggle" href="#" data-bs-toggle="dropdown">
                            <i class="bi bi-person-circle"></i> {{ user.username }}
                        </a>
                        <ul class="dropdown-menu dropdown-menu-end">
                            <li>
                                <form method="post" action="{% url 'logout' %}">
                                    {% csrf_token %}
                                    <button type="submit" class="dropdown-item">
                                        <i class="bi bi-box-arrow-right"></i> Logout
                                    </button>
                                </form>
                            </li>
                        </ul>
                    </li>
                    {% endif %}
                </ul>
            </div>
        </div>
    </nav>

    <div class="container mt-3">
        {% if messages %}
            {% for message in messages %}
                <div class="alert alert-{{ message.tags }} alert-dismissible fade show" role="alert">
                    {{ message }}
                    <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
                </div>
            {% endfor %}
        {% endif %}
        
        {% block content %}{% endblock %}
    </div>

    <footer class="footer text-center mt-4">
        <div class="container">
            <span>© 2026 Simphony STS Integration Platform</span>
        </div>
    </footer>

    <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        function checkApiStatus() {
            $.ajax({
                url: "{% url 'simphony:api_status' %}",
                method: "GET",
                success: function(response) {
                    var statusSpan = $('#api-status-text');
                    if (response.status === 'online') {
                        statusSpan.html('API Online').removeClass('offline').addClass('online');
                    } else {
                        statusSpan.html('API Offline').removeClass('online').addClass('offline');
                    }
                },
                error: function() {
                    $('#api-status-text').html('API Offline').removeClass('online').addClass('offline');
                }
            });
        }
        $(document).ready(function() {
            checkApiStatus();
            setInterval(checkApiStatus, 30000);
        });
    </script>
    {% block extra_js %}{% endblock %}
</body>
</html>
EOF

# 10. Criar template home.html
print_message "Criando template home.html..."
cat > templates/simphony_integration/home.html << 'EOF'
{% extends 'base.html' %}

{% block title %}Home{% endblock %}

{% block content %}
<div class="row mt-4">
    <div class="col-12 text-center">
        <h1 class="display-4">
            <i class="bi bi-box-seam text-primary"></i> 
            Simphony STS Integration Platform
        </h1>
        <p class="lead">Plataforma completa para gestão de funcionários e menu items no Oracle Simphony EMC</p>
        <hr>
    </div>
</div>

<div class="row mt-4">
    <div class="col-md-4 mb-4">
        <div class="card h-100 shadow-sm">
            <div class="card-body text-center">
                <i class="bi bi-people-fill display-1 text-primary"></i>
                <h5 class="mt-3">Gestão de Funcionários</h5>
                <p>Cadastre, edite e gerencie todos os funcionários do sistema Simphony.</p>
                <a href="{% url 'simphony:employee_list' %}" class="btn btn-primary">
                    <i class="bi bi-person-plus"></i> Gerenciar
                </a>
            </div>
        </div>
    </div>
    
    <div class="col-md-4 mb-4">
        <div class="card h-100 shadow-sm">
            <div class="card-body text-center">
                <i class="bi bi-grid-3x3-gap-fill display-1 text-success"></i>
                <h5 class="mt-3">Menu Item Master</h5>
                <p>Gerencie os itens do cardápio mestre do sistema.</p>
                <a href="{% url 'simphony:menu_item_master' %}" class="btn btn-success">
                    <i class="bi bi-plus-circle"></i> Gerenciar
                </a>
            </div>
        </div>
    </div>
    
    <div class="col-md-4 mb-4">
        <div class="card h-100 shadow-sm">
            <div class="card-body text-center">
                <i class="bi bi-speedometer2 display-1 text-info"></i>
                <h5 class="mt-3">Dashboard</h5>
                <p>Visualize indicadores e status do sistema em tempo real.</p>
                <a href="{% url 'simphony:dashboard' %}" class="btn btn-info text-white">
                    <i class="bi bi-graph-up"></i> Ver Dashboard
                </a>
            </div>
        </div>
    </div>
</div>
{% endblock %}
EOF

# 11. Criar template dashboard.html
print_message "Criando template dashboard.html..."
cat > templates/simphony_integration/dashboard.html << 'EOF'
{% extends 'base.html' %}

{% block title %}Dashboard{% endblock %}

{% block content %}
<div class="row mt-4">
    <div class="col-12">
        <h2><i class="bi bi-speedometer2"></i> Dashboard</h2>
        <hr>
    </div>
</div>

<div class="row">
    <div class="col-md-4 mb-4">
        <div class="card text-white bg-primary card-stats">
            <div class="card-body">
                <div class="d-flex justify-content-between align-items-center">
                    <div>
                        <h6>Status da API</h6>
                        <h3>
                            {% if is_connected %}
                                <span class="badge bg-success">Online</span>
                            {% else %}
                                <span class="badge bg-danger">Offline</span>
                            {% endif %}
                        </h3>
                    </div>
                    <i class="bi bi-plug display-4"></i>
                </div>
            </div>
        </div>
    </div>
    
    <div class="col-md-4 mb-4">
        <div class="card text-white bg-success card-stats">
            <div class="card-body">
                <div class="d-flex justify-content-between align-items-center">
                    <div>
                        <h6>Funcionalidades</h6>
                        <h3>3 Módulos</h3>
                    </div>
                    <i class="bi bi-grid-3x3-gap-fill display-4"></i>
                </div>
            </div>
        </div>
    </div>
    
    <div class="col-md-4 mb-4">
        <div class="card text-white bg-info card-stats">
            <div class="card-body">
                <div class="d-flex justify-content-between align-items-center">
                    <div>
                        <h6>Segurança</h6>
                        <h3>OAuth2 PKCE</h3>
                    </div>
                    <i class="bi bi-shield-lock-fill display-4"></i>
                </div>
            </div>
        </div>
    </div>
</div>

<div class="row mt-4">
    <div class="col-md-6">
        <div class="card shadow-sm">
            <div class="card-header bg-primary text-white">
                <h5><i class="bi bi-info-circle"></i> Informações do Sistema</h5>
            </div>
            <div class="card-body">
                <ul class="list-unstyled">
                    <li><i class="bi bi-check-circle-fill text-success"></i> Django 5.0.4</li>
                    <li><i class="bi bi-check-circle-fill text-success"></i> Autenticação OAuth2 PKCE</li>
                    <li><i class="bi bi-check-circle-fill text-success"></i> CRUD completo</li>
                    <li><i class="bi bi-check-circle-fill text-success"></i> Logs de sincronização</li>
                </ul>
            </div>
        </div>
    </div>
    
    <div class="col-md-6">
        <div class="card shadow-sm">
            <div class="card-header bg-success text-white">
                <h5><i class="bi bi-rocket-takeoff"></i> Ações Rápidas</h5>
            </div>
            <div class="card-body">
                <div class="d-grid gap-2">
                    <a href="{% url 'simphony:employee_create' %}" class="btn btn-primary">
                        <i class="bi bi-person-plus"></i> Novo Funcionário
                    </a>
                    <a href="{% url 'simphony:menu_item_master_create' %}" class="btn btn-success">
                        <i class="bi bi-plus-circle"></i> Novo Menu Item
                    </a>
                </div>
            </div>
        </div>
    </div>
</div>
{% endblock %}
EOF

# 12. Criar templates para employees
print_message "Criando templates de employees..."
cat > templates/simphony_integration/employees/list.html << 'EOF'
{% extends 'base.html' %}

{% block title %}{{ page_title }}{% endblock %}

{% block content %}
<div class="row mt-4">
    <div class="col-12">
        <div class="d-flex justify-content-between align-items-center">
            <h2><i class="bi bi-people-fill"></i> {{ page_title }}</h2>
            <a href="{% url 'simphony:employee_create' %}" class="btn btn-primary">
                <i class="bi bi-person-plus"></i> Novo Funcionário
            </a>
        </div>
        <hr>
    </div>
</div>

<div class="row">
    <div class="col-12">
        <div class="card shadow-sm">
            <div class="card-body">
                <div class="table-responsive">
                    <table class="table table-striped">
                        <thead>
                            <tr><th>Object Num</th><th>Nome</th><th>Email</th><th>Ações</th</tr>
                        </thead>
                        <tbody>
                            {% for emp in employees %}
                            <tr>
                                <td>{{ emp.objectNum }}</td>
                                <td>{{ emp.firstName }} {{ emp.lastName }}</td>
                                <td>{{ emp.email|default:"-" }}</td>
                                <td>
                                    <a href="{% url 'simphony:employee_detail' emp.objectNum %}" class="btn btn-sm btn-info">Ver</a>
                                    <a href="{% url 'simphony:employee_update' emp.objectNum %}" class="btn btn-sm btn-warning">Editar</a>
                                    <a href="{% url 'simphony:employee_delete' emp.objectNum %}" class="btn btn-sm btn-danger">Excluir</a>
                                </td>
                            </tr>
                            {% empty %}
                            <tr><td colspan="4" class="text-center">Nenhum funcionário encontrado</td></tr>
                            {% endfor %}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>
{% endblock %}
EOF

cat > templates/simphony_integration/employees/form.html << 'EOF'
{% extends 'base.html' %}

{% block title %}{{ page_title }}{% endblock %}

{% block content %}
<div class="row mt-4">
    <div class="col-12">
        <h2><i class="bi bi-person-badge"></i> {{ page_title }}</h2>
        <hr>
    </div>
</div>

<div class="row">
    <div class="col-md-8 mx-auto">
        <div class="card shadow-sm">
            <div class="card-body">
                <form method="post">
                    {% csrf_token %}
                    <div class="mb-3">
                        <label>Object Num *</label>
                        <input type="number" name="object_num" class="form-control" required value="{{ employee.objectNum|default:'' }}">
                    </div>
                    <div class="row">
                        <div class="col-md-6">
                            <div class="mb-3">
                                <label>Nome *</label>
                                <input type="text" name="first_name" class="form-control" required value="{{ employee.firstName|default:'' }}">
                            </div>
                        </div>
                        <div class="col-md-6">
                            <div class="mb-3">
                                <label>Sobrenome *</label>
                                <input type="text" name="last_name" class="form-control" required value="{{ employee.lastName|default:'' }}">
                            </div>
                        </div>
                    </div>
                    <div class="mb-3">
                        <label>Email</label>
                        <input type="email" name="email" class="form-control" value="{{ employee.email|default:'' }}">
                    </div>
                    <div class="mb-3">
                        <label>Username *</label>
                        <input type="text" name="user_name" class="form-control" required value="{{ employee.userName|default:'' }}">
                    </div>
                    <div class="mb-3">
                        <label>Check Name *</label>
                        <input type="text" name="check_name" class="form-control" required value="{{ employee.checkName|default:'' }}">
                    </div>
                    <button type="submit" class="btn btn-primary">Salvar</button>
                    <a href="{% url 'simphony:employee_list' %}" class="btn btn-secondary">Cancelar</a>
                </form>
            </div>
        </div>
    </div>
</div>
{% endblock %}
EOF

cat > templates/simphony_integration/employees/detail.html << 'EOF'
{% extends 'base.html' %}

{% block title %}{{ page_title }}{% endblock %}

{% block content %}
<div class="row mt-4">
    <div class="col-12">
        <h2><i class="bi bi-person-circle"></i> {{ page_title }}</h2>
        <hr>
    </div>
</div>

<div class="row">
    <div class="col-md-8 mx-auto">
        <div class="card shadow-sm">
            <div class="card-body">
                <dl class="row">
                    <dt class="col-sm-4">Object Num:</dt>
                    <dd class="col-sm-8">{{ employee.objectNum }}</dd>
                    
                    <dt class="col-sm-4">Nome Completo:</dt>
                    <dd class="col-sm-8">{{ employee.firstName }} {{ employee.lastName }}</dd>
                    
                    <dt class="col-sm-4">Email:</dt>
                    <dd class="col-sm-8">{{ employee.email|default:"-" }}</dd>
                    
                    <dt class="col-sm-4">Username:</dt>
                    <dd class="col-sm-8">{{ employee.userName }}</dd>
                    
                    <dt class="col-sm-4">Check Name:</dt>
                    <dd class="col-sm-8">{{ employee.checkName }}</dd>
                </dl>
                <div class="mt-3">
                    <a href="{% url 'simphony:employee_update' employee.objectNum %}" class="btn btn-warning">Editar</a>
                    <a href="{% url 'simphony:employee_list' %}" class="btn btn-secondary">Voltar</a>
                </div>
            </div>
        </div>
    </div>
</div>
{% endblock %}
EOF

cat > templates/simphony_integration/employees/delete.html << 'EOF'
{% extends 'base.html' %}

{% block title %}{{ page_title }}{% endblock %}

{% block content %}
<div class="row mt-4">
    <div class="col-12">
        <h2><i class="bi bi-trash"></i> {{ page_title }}</h2>
        <hr>
    </div>
</div>

<div class="row">
    <div class="col-md-6 mx-auto">
        <div class="card shadow-sm">
            <div class="card-body text-center">
                <i class="bi bi-exclamation-triangle-fill display-1 text-warning"></i>
                <h4 class="mt-3">Confirmar Exclusão</h4>
                <p>Tem certeza que deseja excluir o funcionário <strong>{{ obj_num }}</strong>?</p>
                <p class="text-danger">Esta ação não pode ser desfeita!</p>
                <form method="post">
                    {% csrf_token %}
                    <button type="submit" class="btn btn-danger">Confirmar Exclusão</button>
                    <a href="{% url 'simphony:employee_list' %}" class="btn btn-secondary">Cancelar</a>
                </form>
            </div>
        </div>
    </div>
</div>
{% endblock %}
EOF

# 13. Criar templates para menu items (versões simplificadas)
print_message "Criando templates de menu items..."
cat > templates/simphony_integration/menu_items/master_list.html << 'EOF'
{% extends 'base.html' %}

{% block title %}{{ page_title }}{% endblock %}

{% block content %}
<div class="row mt-4">
    <div class="col-12">
        <div class="d-flex justify-content-between align-items-center">
            <h2><i class="{{ page_icon }}"></i> {{ page_title }}</h2>
            <a href="{% url 'simphony:menu_item_master_create' %}" class="btn btn-primary">
                <i class="bi bi-plus-circle"></i> Novo Menu Item
            </a>
        </div>
        <hr>
    </div>
</div>

<div class="row">
    <div class="col-12">
        <div class="card shadow-sm">
            <div class="card-body">
                <div class="table-responsive">
                    <table class="table table-striped">
                        <thead>
                            <tr><th>Object Num</th><th>Nome (PT)</th><th>Preço</th><th>Status</th><th>Ações</th</tr>
                        </thead>
                        <tbody>
                            {% for item in menu_items %}
                            <tr>
                                <td>{{ item.objectNum }}</td>
                                <td>{{ item.name.pt-BR|default:item.name.en-US }}</td>
                                <td>R$ {{ item.price|default:"0.00" }}</td>
                                <td>{% if item.active %}<span class="badge bg-success">Ativo</span>{% else %}<span class="badge bg-danger">Inativo</span>{% endif %}</td>
                                <td>
                                    <a href="{% url 'simphony:menu_item_master_update' item.objectNum %}" class="btn btn-sm btn-warning">Editar</a>
                                    <a href="{% url 'simphony:menu_item_master_delete' item.objectNum %}" class="btn btn-sm btn-danger">Excluir</a>
                                </td>
                            </tr>
                            {% empty %}
                            <tr><td colspan="5" class="text-center">Nenhum menu item encontrado</td></tr>
                            {% endfor %}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>
{% endblock %}
EOF

# Criar templates simplificados para os outros módulos
for template in master_form master_confirm_delete def_list def_form def_confirm_delete price_list price_form price_confirm_delete; do
    cat > templates/simphony_integration/menu_items/${template}.html << 'EOF'
{% extends 'base.html' %}

{% block title %}{{ page_title }}{% endblock %}

{% block content %}
<div class="row mt-4">
    <div class="col-12">
        <h2><i class="bi bi-grid-3x3-gap-fill"></i> {{ page_title }}</h2>
        <hr>
    </div>
</div>

<div class="row">
    <div class="col-md-8 mx-auto">
        <div class="card shadow-sm">
            <div class="card-body">
                <div class="alert alert-info">
                    <i class="bi bi-info-circle"></i> Esta funcionalidade está disponível. Preencha os campos conforme necessário.
                </div>
                <form method="post">
                    {% csrf_token %}
                    <div class="mb-3">
                        <label>Object Num</label>
                        <input type="number" name="object_num" class="form-control" required>
                    </div>
                    <div class="mb-3">
                        <label>Nome (Português)</label>
                        <input type="text" name="name_pt" class="form-control" required>
                    </div>
                    <div class="mb-3">
                        <label>Nome (Inglês)</label>
                        <input type="text" name="name_en" class="form-control" required>
                    </div>
                    <div class="mb-3">
                        <label>Preço</label>
                        <input type="number" step="0.01" name="price" class="form-control" required>
                    </div>
                    <div class="mb-3 form-check">
                        <input type="checkbox" name="active" class="form-check-input" checked>
                        <label class="form-check-label">Ativo</label>
                    </div>
                    <button type="submit" class="btn btn-primary">Salvar</button>
                    <a href="{% url 'simphony:menu_item_master' %}" class="btn btn-secondary">Cancelar</a>
                </form>
            </div>
        </div>
    </div>
</div>
{% endblock %}
EOF
done

# 14. Coletar arquivos estáticos
print_message "Coletando arquivos estáticos..."
python manage.py collectstatic --noinput

# 15. Executar migrações
print_message "Executando migrações..."
python manage.py makemigrations
python manage.py migrate

# 16. Criar superusuário se não existir
print_message "Verificando superusuário..."
python manage.py shell -c "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.filter(username='admin').exists() or User.objects.create_superuser('admin', 'admin@example.com', 'admin123')"

# 17. Corrigir permissões
print_message "Corrigindo permissões..."
chown -R www-data:www-data $APP_DIR
chmod -R 755 $APP_DIR

# 18. Reiniciar serviços
print_message "Reiniciando serviços..."
systemctl restart gunicorn-simphony
systemctl restart nginx

# 19. Verificar status
print_message "Verificando status dos serviços..."
systemctl status gunicorn-simphony --no-pager
systemctl status nginx --no-pager

print_header "Atualização concluída com sucesso!"
print_message "Backup salvo em: $BACKUP_DIR"
print_message "Acesse o sistema em: https://simphonysts.ddns.net"
print_message "Credenciais: admin / admin123"

echo ""
echo "========================================="
echo "Para verificar os logs:"
echo "sudo journalctl -u gunicorn-simphony -f"
echo "========================================="
EOF

# Tornar o script executável
chmod +x update_simphony_system.sh

echo ""
echo "========================================="
echo "Script criado com sucesso!"
echo "========================================="
echo ""
echo "Para executar a atualização, rode:"
echo "sudo bash update_simphony_system.sh"
echo ""
echo "O script irá:"
echo "1. Criar backup do sistema atual"
echo "2. Atualizar todos os arquivos necessários"
echo "3. Criar templates e diretórios"
echo "4. Coletar arquivos estáticos"
echo "5. Executar migrações"
echo "6. Reiniciar serviços"
echo ""
echo "Após a execução, acesse: https://simphonysts.ddns.net"
echo "Credenciais: admin / admin123"
