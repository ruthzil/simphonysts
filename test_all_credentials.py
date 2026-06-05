import os
import sys
import django
import requests

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'setup.settings')
sys.path.append('/opt/simphony')
django.setup()

from simphony_integration.services import SimphonyAPIService

def test_credentials(name, username, password, client_id="VFRNLmE5ZDMyY2ExLTJjMmYtNGUyNS04NDI2LWQ0ZTk5ZTFkMzVkNg"):
    print(f"\n{'='*60}")
    print(f"TESTANDO: {name}")
    print(f"Username: {username}")
    print(f"Client ID: {client_id[:30]}...")
    print('='*60)
    
    # Salvar configurações originais
    from django.conf import settings
    old_username = settings.USERNAME
    old_password = settings.PASSWORD
    old_client_id = settings.CLIENT_ID
    
    try:
        # Temporariamente atualizar settings
        settings.USERNAME = username
        settings.PASSWORD = password
        settings.CLIENT_ID = client_id
        
        api = SimphonyAPIService()
        
        print("\n1. Obtendo token...")
        token = api.get_access_token()
        
        if not token:
            print("❌ Falha ao obter token")
            return False
        
        print(f"✅ Token obtido: {token[:50]}...")
        
        print("\n2. Testando CCAPI (/employees/getEmployees)...")
        headers = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
        url = f"{api.ccapi_url}/employees/getEmployees"
        
        try:
            response = requests.post(url, headers=headers, json={"includeAll": "detailed"}, timeout=30)
            print(f"Status: {response.status_code}")
            
            if response.status_code == 200:
                print("✅ SUCESSO! CCAPI funcionando!")
                data = response.json()
                employees = data.get('items', [])
                print(f"Total funcionários: {len(employees)}")
                return True
            else:
                print(f"❌ Erro CCAPI: {response.status_code}")
                print(f"   Mensagem: {response.text[:150]}")
                
                # Testar STS API
                print("\n3. Testando STS API...")
                sts_url = f"{api.sts_api_url}/v1/enterprises"
                sts_response = requests.get(sts_url, headers=headers, timeout=10)
                print(f"STS Status: {sts_response.status_code}")
                
                if sts_response.status_code == 200:
                    print("✅ STS API funcionando!")
                    return True
                else:
                    print("❌ STS API também falhou")
                    return False
        except Exception as e:
            print(f"❌ Exceção: {e}")
            return False
            
    except Exception as e:
        print(f"❌ Erro geral: {e}")
        return False
    finally:
        # Restaurar configurações
        settings.USERNAME = old_username
        settings.PASSWORD = old_password
        settings.CLIENT_ID = old_client_id

# Testar todas as combinações
print("INICIANDO TESTES DE CREDENCIAIS")
print("=" * 60)

# 1. API/CCAPI
test_credentials("API/CCAPI", "zone1", "Suporte@!2026")

# 2. EMC
test_credentials("EMC", "zone", "Tropicalia@@2026")

# 3. R&A (STS)
test_credentials("R&A STS", "ZONE", "Suporte!@#2026")

print("\n" + "=" * 60)
print("TESTES CONCLUÍDOS")
print("=" * 60)
