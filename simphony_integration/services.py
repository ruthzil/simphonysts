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
        # Operation User ID padrão
        self.default_op_user_id = self.username
        self._op_user_cache = {}
    
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
        if not token:
            token = self.get_access_token()
        return {
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
    
    def _get_op_user_id_for_employee(self, obj_num):
        """Obtém o opUserId correto para um funcionário específico"""
        # Verificar cache
        if obj_num in self._op_user_cache:
            return self._op_user_cache[obj_num]
        
        # Buscar funcionário
        employee = self.get_employee(obj_num)
        if employee and 'opUserId' in employee:
            op_user_id = employee['opUserId']
            self._op_user_cache[obj_num] = op_user_id
            return op_user_id
        
        return self.default_op_user_id
    
    def test_connection(self):
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
    
    def get_active_employees(self, hier_unit_id=None):
        """Listar apenas funcionários ativos (não excluídos)"""
        employees = self.get_employees(hier_unit_id)
        if employees:
            return [emp for emp in employees if not emp.get("isDeleted", False)]
        return None

    def get_employees(self, hier_unit_id=None):
        endpoint = "/employees/getEmployees"
        data = {"includeAll": "detailed"}
        if hier_unit_id:
            data["hierUnitId"] = hier_unit_id
        
        result = self._make_request('POST', endpoint, data=data)
        if result:
            return result.get('items', [])
        return None
    
    def get_employee(self, obj_num):
        employees = self.get_employees()
        if employees:
            for emp in employees:
                if emp.get('objectNum') == obj_num:
                    return emp
        return None
    
    def create_employee(self, employee_data):
        endpoint = "/employees/employees"
        # Para criação, usar o opUserId padrão
        employee_data['opUserId'] = self.default_op_user_id
        return self._make_request('POST', endpoint, data=employee_data)
    


    def update_employee(self, obj_num, employee_data):
        """Atualizar funcionário preservando todos os campos existentes"""
        endpoint = "/employees/updateEmployees"
        
        # Buscar dados atuais completos
        current = self.get_employee(obj_num)
        if not current:
            print(f"Funcionário {obj_num} não encontrado")
            return None
        
        # Criar payload com todos os campos atuais
        payload = {
            "objectNum": int(obj_num),
            "opUserId": current.get('opUserId'),
        }
        
        # Preservar todos os campos existentes
        for campo in ['firstName', 'lastName', 'checkName', 'userName', 'email',
                      'languageObjNum', 'payrollId', 'middleName', 'pin',
                      'level', 'group', 'infoLine1', 'infoLine2', 'infoLine3', 'infoLine4']:
            if campo in current and current[campo] is not None:
                payload[campo] = current[campo]
        
        # Preservar estruturas complexas
        if 'roles' in current and current['roles']:
            payload['roles'] = current['roles']
        if 'properties' in current and current['properties']:
            payload['properties'] = current['properties']
        if 'emcVisibility' in current and current['emcVisibility']:
            payload['emcVisibility'] = current['emcVisibility']
        
        # Aplicar apenas as alterações solicitadas
        for campo, valor in employee_data.items():
            if valor is not None:
                payload[campo] = valor
        
        return self._make_request('POST', endpoint, data=payload)

    def delete_employee(self, obj_num):
        endpoint = "/employees/deleteEmployees"
        op_user_id = self._get_op_user_id_for_employee(obj_num)
        data = {
            "objectNum": obj_num,
            "opUserId": op_user_id
        }
        return self._make_request('POST', endpoint, data=data)
    
    # Outros métodos (menu items, etc.) mantidos similares
    def get_menu_items(self, hier_unit_id=None):
        endpoint = "/menuItems/getMenuItems"
        data = {"includeAll": "detailed"}
        if hier_unit_id:
            data["hierUnitId"] = hier_unit_id
        result = self._make_request('POST', endpoint, data=data)
        if result:
            return result.get('items', [])
        return None
    
    def create_menu_item(self, item_data):
        endpoint = "/menuItems/menuItems"
        item_data['opUserId'] = self.default_op_user_id
        return self._make_request('POST', endpoint, data=item_data)
    
    def update_menu_item(self, obj_num, item_data):
        endpoint = "/menuItems/updateMenuItems"
        item_data['objectNum'] = obj_num
        item_data['opUserId'] = self.default_op_user_id
        return self._make_request('POST', endpoint, data=item_data)
    
    def delete_menu_item(self, obj_num):
        endpoint = "/menuItems/deleteMenuItems"
        data = {
            "objectNum": obj_num,
            "opUserId": self.default_op_user_id
        }
        return self._make_request('POST', endpoint, data=data)
    
    def get_hierarchy(self):
        endpoint = "/hierarchy/getHierarchy"
        return self._make_request('POST', endpoint, data={})
    
    def get_roles(self):
        endpoint = "/employees/getRoles"
        result = self._make_request('POST', endpoint, data={})
        if result:
            return result.get('items', [])
        return None
