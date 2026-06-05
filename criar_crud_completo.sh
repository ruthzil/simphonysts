#!/bin/bash

echo "========================================="
echo "🔧 CRIANDO CRUD COMPLETO"
echo "========================================="

cd /opt/simphony
source venv/bin/activate

# ============================================
# 1. Atualizar models.py
# ============================================
echo ""
echo "📦 1. Atualizando models.py..."

cat > /opt/simphony/simphony_integration/models.py << 'MODELS_EOF'
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
MODELS_EOF

echo "✅ models.py atualizado!"

# ============================================
# 2. Criar services.py completo com CRUD
# ============================================
echo ""
echo "🔧 2. Criando services.py com CRUD completo..."

cat > /opt/simphony/simphony_integration/services.py << 'SERVICES_EOF'
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
    
    def _make_request(self, method, endpoint, data=None, params=None):
        """Fazer requisição autenticada para a API"""
        token = self.get_access_token()
        if not token:
            return {'success': False, 'error': 'Não foi possível obter token'}
        
        headers = {
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
        
        url = f"{self.ccapi_url}{endpoint}"
        
        try:
            if method == 'GET':
                response = requests.get(url, headers=headers, params=params, timeout=30)
            else:
                response = requests.post(url, headers=headers, json=data, timeout=30)
            
            if response.status_code in [200, 201]:
                return {'success': True, 'data': response.json()}
            else:
                return {'success': False, 'error': f'Erro {response.status_code}: {response.text}'}
        except Exception as e:
            return {'success': False, 'error': str(e)}
    
    # ========== EMPLOYEES CRUD ==========
    
    def get_employees(self, hier_unit_id=None):
        """Listar funcionários"""
        endpoint = "/employees/getEmployees"
        data = {
            "includeAll": "detailed"
        }
        if hier_unit_id:
            data["hierUnitId"] = hier_unit_id
        
        result = self._make_request('POST', endpoint, data=data)
        if result.get('success'):
            employees = result['data'].get('items', [])
            return {'success': True, 'employees': employees, 'count': len(employees)}
        return result
    
    def get_employee(self, object_num):
        """Obter um funcionário específico"""
        endpoint = "/employees/getEmployees"
        data = {
            "includeAll": "detailed",
            "searchCriteria": f"where equals(objectNum, {object_num})"
        }
        result = self._make_request('POST', endpoint, data=data)
        if result.get('success'):
            items = result['data'].get('items', [])
            if items:
                return {'success': True, 'employee': items[0]}
        return {'success': False, 'error': 'Funcionário não encontrado'}
    
    def create_employee(self, employee_data):
        """Criar novo funcionário"""
        endpoint = "/employees/employees"
        return self._make_request('POST', endpoint, data=employee_data)
    
    def update_employee(self, employee_data):
        """Atualizar funcionário"""
        endpoint = "/employees/updateEmployees"
        return self._make_request('POST', endpoint, data=employee_data)
    
    def delete_employee(self, object_num):
        """Excluir funcionário"""
        endpoint = "/employees/deleteEmployees"
        data = {"objectNum": object_num}
        return self._make_request('POST', endpoint, data=data)
    
    # ========== MENU ITEMS CRUD ==========
    
    def get_menu_items(self, hier_unit_id=None):
        """Listar itens do menu"""
        endpoint = "/menuItems/getMenuItems"
        data = {"includeAll": "detailed"}
        if hier_unit_id:
            data["hierUnitId"] = hier_unit_id
        
        result = self._make_request('POST', endpoint, data=data)
        if result.get('success'):
            items = result['data'].get('items', [])
            return {'success': True, 'menu_items': items, 'count': len(items)}
        return result
    
    def get_menu_item(self, object_num):
        """Obter um item específico"""
        endpoint = "/menuItems/getMenuItems"
        data = {
            "includeAll": "detailed",
            "searchCriteria": f"where equals(objectNum, {object_num})"
        }
        result = self._make_request('POST', endpoint, data=data)
        if result.get('success'):
            items = result['data'].get('items', [])
            if items:
                return {'success': True, 'menu_item': items[0]}
        return {'success': False, 'error': 'Item não encontrado'}
    
    def create_menu_item(self, item_data):
        """Criar novo item do menu"""
        endpoint = "/menuItems/menuItems"
        return self._make_request('POST', endpoint, data=item_data)
    
    def update_menu_item(self, item_data):
        """Atualizar item do menu"""
        endpoint = "/menuItems/updateMenuItems"
        return self._make_request('POST', endpoint, data=item_data)
    
    def delete_menu_item(self, object_num):
        """Excluir item do menu"""
        endpoint = "/menuItems/deleteMenuItems"
        data = {"objectNum": object_num}
        return self._make_request('POST', endpoint, data=data)
    
    # ========== HIERARCHY ==========
    
    def get_hierarchy(self):
        """Obter hierarquia completa (Enterprise, Locations, Zones)"""
        endpoint = "/hierarchy/getHierarchy"
        data = {"includeAll": "detailed"}
        result = self._make_request('POST', endpoint, data=data)
        if result.get('success'):
            return {'success': True, 'hierarchy': result['data']}
        return result
    
    def get_locations(self):
        """Listar locations"""
        endpoint = "/hierarchy/getLocations"
        result = self._make_request('POST', endpoint, data={})
        if result.get('success'):
            locations = result['data'].get('items', [])
            return {'success': True, 'locations': locations}
        return result
    
    def get_revenue_centers(self, loc_hier_unit_id=None):
        """Listar revenue centers (zones)"""
        endpoint = "/hierarchy/getRevenueCenters"
        data = {"includeAll": "detailed"}
        if loc_hier_unit_id:
            data["locHierUnitId"] = loc_hier_unit_id
        
        result = self._make_request('POST', endpoint, data=data)
        if result.get('success'):
            rvcs = result['data'].get('items', [])
            return {'success': True, 'revenue_centers': rvcs}
        return result
    
    # ========== MENU ITEM CLASSES ==========
    
    def get_menu_item_classes(self):
        """Listar classes de menu items"""
        endpoint = "/menuItems/getMenuItemClasses"
        data = {"include": ""}
        result = self._make_request('POST', endpoint, data=data)
        if result.get('success'):
            classes = result['data'].get('items', [])
            return {'success': True, 'classes': classes}
        return result
    
    # ========== EMPLOYEE CLASSES ==========
    
    def get_employee_classes(self):
        """Listar classes de funcionários"""
        endpoint = "/employees/getClasses"
        data = {"includeAll": "detailed"}
        result = self._make_request('POST', endpoint, data=data)
        if result.get('success'):
            classes = result['data'].get('items', [])
            return {'success': True, 'classes': classes}
        return result
    
    # ========== ROLES ==========
    
    def get_roles(self):
        """Listar roles/papéis"""
        endpoint = "/employees/getRoles"
        data = {"includeAll": "detailed"}
        result = self._make_request('POST', endpoint, data=data)
        if result.get('success'):
            roles = result['data'].get('items', [])
            return {'success': True, 'roles': roles}
        return result
    
    def test_connection(self):
        """Testar conexão com a API"""
        token = self.get_access_token()
        if token:
            return {'success': True, 'message': 'Autenticado com sucesso'}
        return {'success': False, 'message': 'Falha na autenticação'}
SERVICES_EOF

echo "✅ services.py atualizado!"

# ============================================
# 3. Criar views.py completo com CRUD
# ============================================
echo ""
echo "📊 3. Criando views.py com CRUD..."

cat > /opt/simphony/simphony_integration/views.py << 'VIEWS_EOF'
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.http import JsonResponse
from django.conf import settings
from .services import SimphonyAPIService
from .models import MenuItemLog, SyncLog
import json

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
    
    # Contagens
    employees_result = api_service.get_employees()
    menu_result = api_service.get_menu_items()
    
    context = {
        'title': 'Dashboard',
        'user': request.user,
        'api_status': api_status,
        'employee_count': employees_result.get('count', 0) if employees_result.get('success') else 0,
        'menu_count': menu_result.get('count', 0) if menu_result.get('success') else 0,
    }
    return render(request, 'simphony_integration/dashboard.html', context)

# ========== EMPLOYEES CRUD VIEWS ==========

@login_required
def employee_list(request):
    """Listar todos os funcionários"""
    api_service = SimphonyAPIService()
    
    # Filtros
    hier_unit_id = request.GET.get('hier_unit_id')
    search = request.GET.get('search', '')
    
    result = api_service.get_employees(hier_unit_id=hier_unit_id)
    
    # Obter hierarquia para filtros
    hierarchy = api_service.get_hierarchy()
    locations = api_service.get_locations()
    
    context = {
        'title': 'Funcionários',
        'result': result,
        'hierarchy': hierarchy.get('hierarchy', {}) if hierarchy.get('success') else {},
        'locations': locations.get('locations', []) if locations.get('success') else [],
        'search': search,
        'selected_hier_unit': hier_unit_id,
    }
    return render(request, 'simphony_integration/employees/list.html', context)

@login_required
def employee_detail(request, object_num):
    """Visualizar detalhes de um funcionário"""
    api_service = SimphonyAPIService()
    result = api_service.get_employee(object_num)
    
    context = {
        'title': 'Detalhes do Funcionário',
        'result': result,
    }
    return render(request, 'simphony_integration/employees/detail.html', context)

@login_required
def employee_create(request):
    """Formulário para criar funcionário"""
    api_service = SimphonyAPIService()
    
    if request.method == 'POST':
        # Construir dados do funcionário
        employee_data = {
            'objectNum': int(request.POST.get('object_num')),
            'firstName': request.POST.get('first_name'),
            'lastName': request.POST.get('last_name'),
            'checkName': request.POST.get('check_name', ''),
            'email': request.POST.get('email'),
            'languageObjNum': int(request.POST.get('language_obj_num', 1)),
            'userName': request.POST.get('username'),
        }
        
        # Adicionar roles se especificadas
        role_obj_num = request.POST.get('role_obj_num')
        hier_unit_id = request.POST.get('hier_unit_id')
        if role_obj_num and hier_unit_id:
            employee_data['roles'] = [{
                'hierUnitId': int(hier_unit_id),
                'roleObjNum': int(role_obj_num)
            }]
        
        # Adicionar propriedades
        property_hier_unit = request.POST.get('property_hier_unit_id')
        emp_class = request.POST.get('emp_class_obj_num')
        if property_hier_unit and emp_class:
            employee_data['properties'] = [{
                'propertyHierUnitId': int(property_hier_unit),
                'empClassObjNum': int(emp_class)
            }]
        
        result = api_service.create_employee(employee_data)
        
        if result.get('success'):
            messages.success(request, f"Funcionário {employee_data['firstName']} {employee_data['lastName']} criado com sucesso!")
            return redirect('simphony_integration:employee_list')
        else:
            messages.error(request, f"Erro ao criar funcionário: {result.get('error')}")
    
    # Dados para o formulário
    locations = api_service.get_locations()
    roles = api_service.get_roles()
    emp_classes = api_service.get_employee_classes()
    languages = [{'id': 1, 'name': 'English'}, {'id': 2, 'name': 'Português'}, {'id': 3, 'name': 'Español'}]
    
    context = {
        'title': 'Novo Funcionário',
        'locations': locations.get('locations', []) if locations.get('success') else [],
        'roles': roles.get('roles', []) if roles.get('success') else [],
        'emp_classes': emp_classes.get('classes', []) if emp_classes.get('success') else [],
        'languages': languages,
    }
    return render(request, 'simphony_integration/employees/form.html', context)

@login_required
def employee_update(request, object_num):
    """Formulário para atualizar funcionário"""
    api_service = SimphonyAPIService()
    
    if request.method == 'POST':
        employee_data = {
            'objectNum': object_num,
            'firstName': request.POST.get('first_name'),
            'lastName': request.POST.get('last_name'),
            'checkName': request.POST.get('check_name', ''),
            'email': request.POST.get('email'),
        }
        
        result = api_service.update_employee(employee_data)
        
        if result.get('success'):
            messages.success(request, f"Funcionário atualizado com sucesso!")
            return redirect('simphony_integration:employee_detail', object_num=object_num)
        else:
            messages.error(request, f"Erro ao atualizar: {result.get('error')}")
    
    # Obter dados atuais
    result = api_service.get_employee(object_num)
    employee = result.get('employee', {}) if result.get('success') else {}
    
    context = {
        'title': 'Editar Funcionário',
        'employee': employee,
        'object_num': object_num,
    }
    return render(request, 'simphony_integration/employees/form.html', context)

@login_required
def employee_delete(request, object_num):
    """Excluir funcionário"""
    api_service = SimphonyAPIService()
    
    if request.method == 'POST':
        result = api_service.delete_employee(object_num)
        
        if result.get('success'):
            messages.success(request, "Funcionário excluído com sucesso!")
        else:
            messages.error(request, f"Erro ao excluir: {result.get('error')}")
        
        return redirect('simphony_integration:employee_list')
    
    result = api_service.get_employee(object_num)
    employee = result.get('employee', {}) if result.get('success') else {}
    
    context = {
        'title': 'Excluir Funcionário',
        'employee': employee,
        'object_num': object_num,
    }
    return render(request, 'simphony_integration/employees/delete.html', context)

# ========== MENU ITEMS CRUD VIEWS ==========

@login_required
def menu_list(request):
    """Listar todos os itens do menu"""
    api_service = SimphonyAPIService()
    
    hier_unit_id = request.GET.get('hier_unit_id')
    search = request.GET.get('search', '')
    
    result = api_service.get_menu_items(hier_unit_id=hier_unit_id)
    
    # Filtrar por nome se houver search
    if search and result.get('success'):
        result['menu_items'] = [item for item in result['menu_items'] 
                                if search.lower() in str(item.get('name', '')).lower()]
        result['count'] = len(result['menu_items'])
    
    hierarchy = api_service.get_hierarchy()
    locations = api_service.get_locations()
    
    context = {
        'title': 'Menu Items',
        'result': result,
        'hierarchy': hierarchy.get('hierarchy', {}) if hierarchy.get('success') else {},
        'locations': locations.get('locations', []) if locations.get('success') else [],
        'search': search,
        'selected_hier_unit': hier_unit_id,
    }
    return render(request, 'simphony_integration/menu_items/list.html', context)

@login_required
def menu_detail(request, object_num):
    """Visualizar detalhes de um item do menu"""
    api_service = SimphonyAPIService()
    result = api_service.get_menu_item(object_num)
    
    context = {
        'title': 'Detalhes do Menu Item',
        'result': result,
    }
    return render(request, 'simphony_integration/menu_items/detail.html', context)

@login_required
def menu_create(request):
    """Formulário para criar item do menu"""
    api_service = SimphonyAPIService()
    
    if request.method == 'POST':
        # Construir dados do menu item
        item_data = {
            'objectNum': int(request.POST.get('object_num')),
            'name': {
                'en-US': request.POST.get('name_en'),
                'pt-BR': request.POST.get('name_pt', request.POST.get('name_en')),
            },
            'hierUnitId': int(request.POST.get('hier_unit_id')),
            'familyGroupObjectNum': int(request.POST.get('family_group_obj_num', 1)),
            'majorGroupObjectNum': int(request.POST.get('major_group_obj_num', 1)),
        }
        
        # Adicionar preço se especificado
        price = request.POST.get('price')
        if price:
            item_data['prices'] = [{
                'price': float(price),
                'prepCost': float(request.POST.get('prep_cost', 0)),
            }]
        
        result = api_service.create_menu_item(item_data)
        
        # Registrar log
        MenuItemLog.objects.create(
            nome_item=request.POST.get('name_en'),
            payload_enviado=item_data,
            resposta_api=result,
            status_code=200 if result.get('success') else 400
        )
        
        if result.get('success'):
            messages.success(request, f"Menu Item '{request.POST.get('name_en')}' criado com sucesso!")
            return redirect('simphony_integration:menu_list')
        else:
            messages.error(request, f"Erro ao criar item: {result.get('error')}")
    
    # Dados para o formulário
    locations = api_service.get_locations()
    item_classes = api_service.get_menu_item_classes()
    
    context = {
        'title': 'Novo Menu Item',
        'locations': locations.get('locations', []) if locations.get('success') else [],
        'item_classes': item_classes.get('classes', []) if item_classes.get('success') else [],
    }
    return render(request, 'simphony_integration/menu_items/form.html', context)

@login_required
def menu_update(request, object_num):
    """Formulário para atualizar item do menu"""
    api_service = SimphonyAPIService()
    
    if request.method == 'POST':
        item_data = {
            'objectNum': object_num,
            'name': {
                'en-US': request.POST.get('name_en'),
            },
            'hierUnitId': int(request.POST.get('hier_unit_id')),
        }
        
        price = request.POST.get('price')
        if price:
            item_data['prices'] = [{'price': float(price)}]
        
        result = api_service.update_menu_item(item_data)
        
        if result.get('success'):
            messages.success(request, "Menu Item atualizado com sucesso!")
            return redirect('simphony_integration:menu_detail', object_num=object_num)
        else:
            messages.error(request, f"Erro ao atualizar: {result.get('error')}")
    
    result = api_service.get_menu_item(object_num)
    menu_item = result.get('menu_item', {}) if result.get('success') else {}
    locations = api_service.get_locations()
    
    context = {
        'title': 'Editar Menu Item',
        'menu_item': menu_item,
        'locations': locations.get('locations', []) if locations.get('success') else [],
        'object_num': object_num,
    }
    return render(request, 'simphony_integration/menu_items/form.html', context)

@login_required
def menu_delete(request, object_num):
    """Excluir item do menu"""
    api_service = SimphonyAPIService()
    
    if request.method == 'POST':
        result = api_service.delete_menu_item(object_num)
        
        if result.get('success'):
            messages.success(request, "Menu Item excluído com sucesso!")
        else:
            messages.error(request, f"Erro ao excluir: {result.get('error')}")
        
        return redirect('simphony_integration:menu_list')
    
    result = api_service.get_menu_item(object_num)
    menu_item = result.get('menu_item', {}) if result.get('success') else {}
    
    context = {
        'title': 'Excluir Menu Item',
        'menu_item': menu_item,
        'object_num': object_num,
    }
    return render(request, 'simphony_integration/menu_items/delete.html', context)

# ========== SYNC & HISTORY ==========

@login_required
def sync_logs(request):
    """Visualizar logs de sincronização"""
    logs = SyncLog.objects.all().order_by('-criado_em')[:50]
    
    context = {
        'title': 'Logs de Sincronização',
        'logs': logs,
    }
    return render(request, 'simphony_integration/sync_logs.html', context)

@login_required
def menu_item_logs(request):
    """Visualizar histórico de envios de menu items"""
    logs = MenuItemLog.objects.all().order_by('-criado_em')[:50]
    
    context = {
        'title': 'Histórico de Menu Items',
        'logs': logs,
    }
    return render(request, 'simphony_integration/menu_item_logs.html', context)

# Aliases para compatibilidade
def listar_usuarios_simphony(request):
    return employee_list(request)

def listar_menu_items(request):
    return menu_list(request)

def settings_view(request):
    return render(request, 'simphony_integration/settings.html', {'title': 'Configurações'})

def settings(request):
    return settings_view(request)
VIEWS_EOF

echo "✅ views.py atualizado!"

# ============================================
# 4. Atualizar URLs
# ============================================
echo ""
echo "🔗 4. Atualizando urls.py..."

cat > /opt/simphony/simphony_integration/urls.py << 'URLS_EOF'
from django.urls import path
from . import views

app_name = 'simphony_integration'

urlpatterns = [
    # Dashboard
    path('', views.index, name='index'),
    path('dashboard/', views.dashboard, name='dashboard'),
    path('settings/', views.settings, name='settings'),
    
    # Employees CRUD
    path('employees/', views.employee_list, name='employee_list'),
    path('employees/create/', views.employee_create, name='employee_create'),
    path('employees/<int:object_num>/', views.employee_detail, name='employee_detail'),
    path('employees/<int:object_num>/update/', views.employee_update, name='employee_update'),
    path('employees/<int:object_num>/delete/', views.employee_delete, name='employee_delete'),
    
    # Menu Items CRUD
    path('menu-items/', views.menu_list, name='menu_list'),
    path('menu-items/create/', views.menu_create, name='menu_create'),
    path('menu-items/<int:object_num>/', views.menu_detail, name='menu_detail'),
    path('menu-items/<int:object_num>/update/', views.menu_update, name='menu_update'),
    path('menu-items/<int:object_num>/delete/', views.menu_delete, name='menu_delete'),
    
    # Logs
    path('sync-logs/', views.sync_logs, name='sync_logs'),
    path('menu-item-logs/', views.menu_item_logs, name='menu_item_logs'),
    
    # Aliases
    path('usuarios-simphony/', views.employee_list, name='listar_usuarios_simphony'),
    path('menu-items-simphony/', views.menu_list, name='listar_menu_items'),
]
URLS_EOF

echo "✅ urls.py atualizado!"

# ============================================
# 5. Criar templates
# ============================================
echo ""
echo "🎨 5. Criando templates..."

# Criar diretórios
mkdir -p /opt/simphony/templates/simphony_integration/employees
mkdir -p /opt/simphony/templates/simphony_integration/menu_items

# Dashboard atualizado
cat > /opt/simphony/templates/simphony_integration/dashboard.html << 'DASHBOARD_EOF'
{% extends 'base.html' %}
{% block title %}Dashboard - Simphony STS{% endblock %}
{% block content %}
<h1 class="mb-4"><i class="bi bi-speedometer2"></i> Dashboard</h1>

<div class="row">
    <div class="col-md-3">
        <div class="card text-white bg-primary mb-3">
            <div class="card-header">Status da API</div>
            <div class="card-body">
                <h5 class="card-title">{{ api_status }}</h5>
                <p class="card-text">API Simphony está {% if api_status == 'Conectado' %}respondendo{% else %}offline{% endif %}.</p>
            </div>
        </div>
    </div>
    <div class="col-md-3">
        <div class="card text-white bg-success mb-3">
            <div class="card-header">Funcionários</div>
            <div class="card-body">
                <h5 class="card-title">{{ employee_count }}</h5>
                <p class="card-text">Funcionários cadastrados</p>
                <a href="{% url 'simphony_integration:employee_list' %}" class="text-white">Gerenciar →</a>
            </div>
        </div>
    </div>
    <div class="col-md-3">
        <div class="card text-white bg-info mb-3">
            <div class="card-header">Menu Items</div>
            <div class="card-body">
                <h5 class="card-title">{{ menu_count }}</h5>
                <p class="card-text">Itens no menu</p>
                <a href="{% url 'simphony_integration:menu_list' %}" class="text-white">Gerenciar →</a>
            </div>
        </div>
    </div>
    <div class="col-md-3">
        <div class="card text-white bg-warning mb-3">
            <div class="card-header">Ações Rápidas</div>
            <div class="card-body">
                <a href="{% url 'simphony_integration:employee_create' %}" class="btn btn-light btn-sm w-100 mb-2">+ Novo Funcionário</a>
                <a href="{% url 'simphony_integration:menu_create' %}" class="btn btn-light btn-sm w-100 mb-2">+ Novo Menu Item</a>
                <a href="{% url 'simphony_integration:sync_logs' %}" class="btn btn-light btn-sm w-100">📋 Ver Logs</a>
            </div>
        </div>
    </div>
</div>
{% endblock %}
DASHBOARD_EOF

# Template de lista de funcionários
cat > /opt/simphony/templates/simphony_integration/employees/list.html << 'EMPLOYEE_LIST_EOF'
{% extends 'base.html' %}
{% block title %}Funcionários - Simphony{% endblock %}
{% block content %}
<div class="d-flex justify-content-between align-items-center mb-4">
    <h1><i class="bi bi-people"></i> Funcionários</h1>
    <a href="{% url 'simphony_integration:employee_create' %}" class="btn btn-primary">
        <i class="bi bi-person-plus"></i> Novo Funcionário
    </a>
</div>

{% if result.success %}
    <div class="alert alert-success">
        <i class="bi bi-check-circle"></i> Total de funcionários: {{ result.count }}
    </div>
    
    <div class="table-responsive">
        <table class="table table-striped table-hover">
            <thead class="table-dark">
                <tr>
                    <th>ID</th>
                    <th>Nome</th>
                    <th>Email</th>
                    <th>Username</th>
                    <th>Ações</th>
                </tr>
            </thead>
            <tbody>
                {% for emp in result.employees %}
                <tr>
                    <td>{{ emp.objectNum }}</td>
                    <td>{{ emp.firstName }} {{ emp.lastName }}</td>
                    <td>{{ emp.email|default:"N/A" }}</td>
                    <td>{{ emp.userName|default:"N/A" }}</td>
                    <td>
                        <a href="{% url 'simphony_integration:employee_detail' emp.objectNum %}" class="btn btn-sm btn-info" title="Ver">
                            <i class="bi bi-eye"></i>
                        </a>
                        <a href="{% url 'simphony_integration:employee_update' emp.objectNum %}" class="btn btn-sm btn-warning" title="Editar">
                            <i class="bi bi-pencil"></i>
                        </a>
                        <a href="{% url 'simphony_integration:employee_delete' emp.objectNum %}" class="btn btn-sm btn-danger" title="Excluir">
                            <i class="bi bi-trash"></i>
                        </a>
                    </td>
                </tr>
                {% empty %}
                <tr><td colspan="5" class="text-center">Nenhum funcionário encontrado</td></tr>
                {% endfor %}
            </tbody>
        </table>
    </div>
{% else %}
    <div class="alert alert-danger">
        <i class="bi bi-exclamation-triangle"></i> Erro: {{ result.error }}
    </div>
{% endif %}
{% endblock %}
EMPLOYEE_LIST_EOF

# Template de formulário de funcionário
cat > /opt/simphony/templates/simphony_integration/employees/form.html << 'EMPLOYEE_FORM_EOF'
{% extends 'base.html' %}
{% block title %}{{ title }}{% endblock %}
{% block content %}
<h1 class="mb-4"><i class="bi bi-person"></i> {{ title }}</h1>

<div class="card">
    <div class="card-body">
        <form method="post">
            {% csrf_token %}
            
            <div class="row">
                <div class="col-md-6 mb-3">
                    <label class="form-label">Object Num (ID) *</label>
                    <input type="number" class="form-control" name="object_num" 
                           value="{{ employee.objectNum|default:'' }}" required>
                </div>
                <div class="col-md-6 mb-3">
                    <label class="form-label">Username *</label>
                    <input type="text" class="form-control" name="username" 
                           value="{{ employee.userName|default:'' }}" required>
                </div>
            </div>
            
            <div class="row">
                <div class="col-md-6 mb-3">
                    <label class="form-label">Primeiro Nome *</label>
                    <input type="text" class="form-control" name="first_name" 
                           value="{{ employee.firstName|default:'' }}" required>
                </div>
                <div class="col-md-6 mb-3">
                    <label class="form-label">Sobrenome *</label>
                    <input type="text" class="form-control" name="last_name" 
                           value="{{ employee.lastName|default:'' }}" required>
                </div>
            </div>
            
            <div class="row">
                <div class="col-md-6 mb-3">
                    <label class="form-label">Email *</label>
                    <input type="email" class="form-control" name="email" 
                           value="{{ employee.email|default:'' }}" required>
                </div>
                <div class="col-md-6 mb-3">
                    <label class="form-label">Check Name</label>
                    <input type="text" class="form-control" name="check_name" 
                           value="{{ employee.checkName|default:'' }}">
                </div>
            </div>
            
            <div class="row">
                <div class="col-md-6 mb-3">
                    <label class="form-label">Location (Hier Unit ID)</label>
                    <select class="form-select" name="hier_unit_id">
                        <option value="">Selecione...</option>
                        {% for loc in locations %}
                        <option value="{{ loc.hierUnitId }}">{{ loc.name }}</option>
                        {% endfor %}
                    </select>
                </div>
                <div class="col-md-6 mb-3">
                    <label class="form-label">Role</label>
                    <select class="form-select" name="role_obj_num">
                        <option value="">Selecione...</option>
                        {% for role in roles %}
                        <option value="{{ role.objectNum }}">{{ role.name }}</option>
                        {% endfor %}
                    </select>
                </div>
            </div>
            
            <div class="row">
                <div class="col-md-6 mb-3">
                    <label class="form-label">Property Hier Unit ID</label>
                    <input type="number" class="form-control" name="property_hier_unit_id">
                </div>
                <div class="col-md-6 mb-3">
                    <label class="form-label">Employee Class</label>
                    <select class="form-select" name="emp_class_obj_num">
                        <option value="">Selecione...</option>
                        {% for cls in emp_classes %}
                        <option value="{{ cls.objectNum }}">{{ cls.className }}</option>
                        {% endfor %}
                    </select>
                </div>
            </div>
            
            <div class="row">
                <div class="col-md-6 mb-3">
                    <label class="form-label">Idioma</label>
                    <select class="form-select" name="language_obj_num">
                        {% for lang in languages %}
                        <option value="{{ lang.id }}">{{ lang.name }}</option>
                        {% endfor %}
                    </select>
                </div>
            </div>
            
            <div class="mt-3">
                <button type="submit" class="btn btn-primary">
                    <i class="bi bi-save"></i> Salvar
                </button>
                <a href="{% url 'simphony_integration:employee_list' %}" class="btn btn-secondary">
                    <i class="bi bi-x-circle"></i> Cancelar
                </a>
            </div>
        </form>
    </div>
</div>
{% endblock %}
EMPLOYEE_FORM_EOF

# Template de detalhes do funcionário
cat > /opt/simphony/templates/simphony_integration/employees/detail.html << 'EMPLOYEE_DETAIL_EOF'
{% extends 'base.html' %}
{% block title %}{{ title }}{% endblock %}
{% block content %}
<div class="d-flex justify-content-between align-items-center mb-4">
    <h1><i class="bi bi-person-badge"></i> {{ title }}</h1>
    <div>
        <a href="{% url 'simphony_integration:employee_update' result.employee.objectNum %}" class="btn btn-warning">
            <i class="bi bi-pencil"></i> Editar
        </a>
        <a href="{% url 'simphony_integration:employee_list' %}" class="btn btn-secondary">
            <i class="bi bi-arrow-left"></i> Voltar
        </a>
    </div>
</div>

{% if result.success %}
<div class="card">
    <div class="card-body">
        <table class="table table-bordered">
            <tr><th width="200">Object Num</th><td>{{ result.employee.objectNum }}</td></tr>
            <tr><th>Nome</th><td>{{ result.employee.firstName }} {{ result.employee.lastName }}</td></tr>
            <tr><th>Check Name</th><td>{{ result.employee.checkName|default:"N/A" }}</td></tr>
            <tr><th>Email</th><td>{{ result.employee.email|default:"N/A" }}</td></tr>
            <tr><th>Username</th><td>{{ result.employee.userName|default:"N/A" }}</td></tr>
            <tr><th>Language</th><td>{{ result.employee.languageObjNum }}</td></tr>
            <tr><th>Status</th><td>{% if result.employee.active %}<span class="badge bg-success">Ativo</span>{% else %}<span class="badge bg-secondary">Inativo</span>{% endif %}</td></tr>
        </table>
    </div>
</div>
{% else %}
<div class="alert alert-danger">{{ result.error }}</div>
{% endif %}
{% endblock %}
EMPLOYEE_DETAIL_EOF

# Template de exclusão de funcionário
cat > /opt/simphony/templates/simphony_integration/employees/delete.html << 'EMPLOYEE_DELETE_EOF'
{% extends 'base.html' %}
{% block title %}{{ title }}{% endblock %}
{% block content %}
<h1 class="mb-4"><i class="bi bi-exclamation-triangle text-danger"></i> {{ title }}</h1>

<div class="card">
    <div class="card-body">
        <p class="lead">Tem certeza que deseja excluir o funcionário abaixo?</p>
        
        <table class="table table-bordered">
            <tr><th width="200">ID</th><td>{{ employee.objectNum }}</td></tr>
            <tr><th>Nome</th><td>{{ employee.firstName }} {{ employee.lastName }}</td></tr>
            <tr><th>Email</th><td>{{ employee.email|default:"N/A" }}</td></tr>
        </table>
        
        <form method="post">
            {% csrf_token %}
            <button type="submit" class="btn btn-danger">
                <i class="bi bi-trash"></i> Confirmar Exclusão
            </button>
            <a href="{% url 'simphony_integration:employee_list' %}" class="btn btn-secondary">
                Cancelar
            </a>
        </form>
    </div>
</div>
{% endblock %}
EMPLOYEE_DELETE_EOF

# Template de lista de menu items
cat > /opt/simphony/templates/simphony_integration/menu_items/list.html << 'MENU_LIST_EOF'
{% extends 'base.html' %}
{% block title %}Menu Items - Simphony{% endblock %}
{% block content %}
<div class="d-flex justify-content-between align-items-center mb-4">
    <h1><i class="bi bi-menu-button"></i> Menu Items</h1>
    <a href="{% url 'simphony_integration:menu_create' %}" class="btn btn-primary">
        <i class="bi bi-plus-circle"></i> Novo Menu Item
    </a>
</div>

{% if result.success %}
    <div class="alert alert-success">
        <i class="bi bi-check-circle"></i> Total de itens: {{ result.count }}
    </div>
    
    <div class="table-responsive">
        <table class="table table-striped table-hover">
            <thead class="table-dark">
                <tr>
                    <th>ID</th>
                    <th>Nome</th>
                    <th>Preço</th>
                    <th>Hier Unit</th>
                    <th>Ações</th>
                </tr>
            </thead>
            <tbody>
                {% for item in result.menu_items %}
                <tr>
                    <td>{{ item.objectNum }}</td>
                    <td>{{ item.name.en_US|default:item.name }}</td>
                    <td>R$ {{ item.price|floatformat:2 }}</td>
                    <td>{{ item.hierUnitId }}</td>
                    <td>
                        <a href="{% url 'simphony_integration:menu_detail' item.objectNum %}" class="btn btn-sm btn-info" title="Ver">
                            <i class="bi bi-eye"></i>
                        </a>
                        <a href="{% url 'simphony_integration:menu_update' item.objectNum %}" class="btn btn-sm btn-warning" title="Editar">
                            <i class="bi bi-pencil"></i>
                        </a>
                        <a href="{% url 'simphony_integration:menu_delete' item.objectNum %}" class="btn btn-sm btn-danger" title="Excluir">
                            <i class="bi bi-trash"></i>
                        </a>
                    </td>
                </tr>
                {% empty %}
                <tr><td colspan="5" class="text-center">Nenhum item encontrado</td></tr>
                {% endfor %}
            </tbody>
        </table>
    </div>
{% else %}
    <div class="alert alert-danger">
        <i class="bi bi-exclamation-triangle"></i> Erro: {{ result.error }}
    </div>
{% endif %}
{% endblock %}
MENU_LIST_EOF

# Template de formulário de menu item
cat > /opt/simphony/templates/simphony_integration/menu_items/form.html << 'MENU_FORM_EOF'
{% extends 'base.html' %}
{% block title %}{{ title }}{% endblock %}
{% block content %}
<h1 class="mb-4"><i class="bi bi-menu-button"></i> {{ title }}</h1>

<div class="card">
    <div class="card-body">
        <form method="post">
            {% csrf_token %}
            
            <div class="row">
                <div class="col-md-6 mb-3">
                    <label class="form-label">Object Num (ID) *</label>
                    <input type="number" class="form-control" name="object_num" 
                           value="{{ menu_item.objectNum|default:'' }}" required>
                </div>
                <div class="col-md-6 mb-3">
                    <label class="form-label">Hier Unit ID *</label>
                    <select class="form-select" name="hier_unit_id" required>
                        <option value="">Selecione...</option>
                        {% for loc in locations %}
                        <option value="{{ loc.hierUnitId }}" {% if menu_item.hierUnitId == loc.hierUnitId %}selected{% endif %}>
                            {{ loc.name }}
                        </option>
                        {% endfor %}
                    </select>
                </div>
            </div>
            
            <div class="row">
                <div class="col-md-6 mb-3">
                    <label class="form-label">Nome (English) *</label>
                    <input type="text" class="form-control" name="name_en" 
                           value="{{ menu_item.name.en_US|default:'' }}" required>
                </div>
                <div class="col-md-6 mb-3">
                    <label class="form-label">Nome (Português)</label>
                    <input type="text" class="form-control" name="name_pt" 
                           value="{{ menu_item.name.pt_BR|default:'' }}">
                </div>
            </div>
            
            <div class="row">
                <div class="col-md-4 mb-3">
                    <label class="form-label">Preço (R$)</label>
                    <input type="number" step="0.01" class="form-control" name="price" 
                           value="{{ menu_item.price|default:'' }}">
                </div>
                <div class="col-md-4 mb-3">
                    <label class="form-label">Custo de Preparo (R$)</label>
                    <input type="number" step="0.01" class="form-control" name="prep_cost" value="0">
                </div>
                <div class="col-md-4 mb-3">
                    <label class="form-label">Family Group</label>
                    <input type="number" class="form-control" name="family_group_obj_num" value="1">
                </div>
            </div>
            
            <div class="row">
                <div class="col-md-6 mb-3">
                    <label class="form-label">Major Group</label>
                    <input type="number" class="form-control" name="major_group_obj_num" value="1">
                </div>
                <div class="col-md-6 mb-3">
                    <label class="form-label">Menu Item Class</label>
                    <select class="form-select" name="item_class_obj_num">
                        <option value="">Selecione...</option>
                        {% for cls in item_classes %}
                        <option value="{{ cls.objectNum }}">{{ cls.name }}</option>
                        {% endfor %}
                    </select>
                </div>
            </div>
            
            <div class="mt-3">
                <button type="submit" class="btn btn-primary">
                    <i class="bi bi-save"></i> Salvar
                </button>
                <a href="{% url 'simphony_integration:menu_list' %}" class="btn btn-secondary">
                    <i class="bi bi-x-circle"></i> Cancelar
                </a>
            </div>
        </form>
    </div>
</div>
{% endblock %}
MENU_FORM_EOF

# Template de detalhes do menu item
cat > /opt/simphony/templates/simphony_integration/menu_items/detail.html << 'MENU_DETAIL_EOF'
{% extends 'base.html' %}
{% block title %}{{ title }}{% endblock %}
{% block content %}
<div class="d-flex justify-content-between align-items-center mb-4">
    <h1><i class="bi bi-menu-button"></i> {{ title }}</h1>
    <div>
        <a href="{% url 'simphony_integration:menu_update' result.menu_item.objectNum %}" class="btn btn-warning">
            <i class="bi bi-pencil"></i> Editar
        </a>
        <a href="{% url 'simphony_integration:menu_list' %}" class="btn btn-secondary">
            <i class="bi bi-arrow-left"></i> Voltar
        </a>
    </div>
</div>

{% if result.success %}
<div class="card">
    <div class="card-body">
        <table class="table table-bordered">
            <tr><th width="200">Object Num</th><td>{{ result.menu_item.objectNum }}</td></tr>
            <tr><th>Nome (EN)</th><td>{{ result.menu_item.name.en_US|default:result.menu_item.name }}</td></tr>
            <tr><th>Preço</th><td>R$ {{ result.menu_item.price|floatformat:2 }}</td></tr>
            <tr><th>Hier Unit ID</th><td>{{ result.menu_item.hierUnitId }}</td></tr>
            <tr><th>Family Group</th><td>{{ result.menu_item.familyGroupObjectNum }}</td></tr>
            <tr><th>Major Group</th><td>{{ result.menu_item.majorGroupObjectNum }}</td></tr>
        </table>
    </div>
</div>
{% else %}
<div class="alert alert-danger">{{ result.error }}</div>
{% endif %}
{% endblock %}
MENU_DETAIL_EOF

# Template de exclusão de menu item
cat > /opt/simphony/templates/simphony_integration/menu_items/delete.html << 'MENU_DELETE_EOF'
{% extends 'base.html' %}
{% block title %}{{ title }}{% endblock %}
{% block content %}
<h1 class="mb-4"><i class="bi bi-exclamation-triangle text-danger"></i> {{ title }}</h1>

<div class="card">
    <div class="card-body">
        <p class="lead">Tem certeza que deseja excluir este menu item?</p>
        
        <table class="table table-bordered">
            <tr><th width="200">ID</th><td>{{ menu_item.objectNum }}</td></tr>
            <tr><th>Nome</th><td>{{ menu_item.name.en_US|default:menu_item.name }}</td></tr>
            <tr><th>Preço</th><td>R$ {{ menu_item.price|floatformat:2 }}</td></tr>
        </table>
        
        <form method="post">
            {% csrf_token %}
            <button type="submit" class="btn btn-danger">
                <i class="bi bi-trash"></i> Confirmar Exclusão
            </button>
            <a href="{% url 'simphony_integration:menu_list' %}" class="btn btn-secondary">
                Cancelar
            </a>
        </form>
    </div>
</div>
{% endblock %}
MENU_DELETE_EOF

# Template de logs
cat > /opt/simphony/templates/simphony_integration/sync_logs.html << 'SYNC_LOGS_EOF'
{% extends 'base.html' %}
{% block title %}Logs de Sincronização{% endblock %}
{% block content %}
<h1 class="mb-4"><i class="bi bi-journal-text"></i> Logs de Sincronização</h1>

<div class="table-responsive">
    <table class="table table-striped table-hover">
        <thead class="table-dark">
            <tr>
                <th>Data/Hora</th>
                <th>Tipo</th>
                <th>Status</th>
                <th>Registros</th>
                <th>Erro</th>
            </tr>
        </thead>
        <tbody>
            {% for log in logs %}
            <tr>
                <td>{{ log.criado_em|date:"d/m/Y H:i:s" }}</td>
                <td>{{ log.tipo }}</td>
                <td>
                    {% if log.status == 'success' %}
                    <span class="badge bg-success">Sucesso</span>
                    {% else %}
                    <span class="badge bg-danger">Erro</span>
                    {% endif %}
                </td>
                <td>{{ log.registros_sincronizados }}</td>
                <td>{{ log.erro|truncatechars:50 }}</td>
            </tr>
            {% empty %}
            <tr><td colspan="5" class="text-center">Nenhum log encontrado</td></tr>
            {% endfor %}
        </tbody>
    </table>
</div>
{% endblock %}
SYNC_LOGS_EOF

# Template de histórico de menu items
cat > /opt/simphony/templates/simphony_integration/menu_item_logs.html << 'MENU_LOGS_EOF'
{% extends 'base.html' %}
{% block title %}Histórico de Menu Items{% endblock %}
{% block content %}
<h1 class="mb-4"><i class="bi bi-clock-history"></i> Histórico de Menu Items</h1>

<div class="table-responsive">
    <table class="table table-striped table-hover">
        <thead class="table-dark">
            <tr>
                <th>Data/Hora</th>
                <th>Item</th>
                <th>Simphony ID</th>
                <th>Status</th>
            </tr>
        </thead>
        <tbody>
            {% for log in logs %}
            <tr>
                <td>{{ log.criado_em|date:"d/m/Y H:i:s" }}</td>
                <td>{{ log.nome_item }}</td>
                <td>{{ log.simphony_id|default:"N/A" }}</td>
                <td>
                    {% if log.status_code == 200 or log.status_code == 201 %}
                    <span class="badge bg-success">Sucesso</span>
                    {% else %}
                    <span class="badge bg-danger">Erro {{ log.status_code }}</span>
                    {% endif %}
                </td>
            </tr>
            {% empty %}
            <tr><td colspan="4" class="text-center">Nenhum histórico encontrado</td></tr>
            {% endfor %}
        </tbody>
    </table>
</div>
{% endblock %}
MENU_LOGS_EOF

echo "✅ Templates criados!"

# ============================================
# 6. Executar migrações e reiniciar
# ============================================
echo ""
echo "🔄 6. Executando migrações..."

python manage.py makemigrations simphony_integration
python manage.py migrate

echo ""
echo "🔄 7. Reiniciando serviços..."

sudo systemctl restart gunicorn-simphony
sudo systemctl restart nginx

echo ""
echo "========================================="
echo "✅✅✅ CRUD COMPLETO CRIADO COM SUCESSO! ✅✅✅"
echo "========================================="
echo ""
echo "🌐 Acesse: https://simphonysts.ddns.net/simphony/dashboard/"
echo ""
echo "📊 Funcionalidades disponíveis:"
echo "   • Dashboard com contadores"
echo "   • CRUD completo de Funcionários"
echo "   • CRUD completo de Menu Items"
echo "   • Suporte a níveis hierárquicos (Enterprise, Locations, Zones)"
echo "   • Logs de sincronização"
echo "   • Histórico de envios"
echo "========================================="
