import os
import sys
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'setup.settings')
sys.path.append('/opt/simphony')
django.setup()

from simphony_integration.services import SimphonyAPIService

# Forçar nova instância para renovar token
api = SimphonyAPIService()

# Limpar token existente para forçar renovação
api.access_token = None
api.token_expiry = None

print("Forçando renovação do token...")
token = api.get_access_token()

if token:
    print("✅ Token renovado com sucesso!")
    
    # Testar conexão
    if api.test_connection():
        print("✅ API conectada e funcionando!")
        
        # Buscar um funcionário para testar
        employees = api.get_employees()
        if employees:
            print(f"✅ Buscou {len(employees)} funcionários")
            print(f"   Exemplo: {employees[0].get('firstName')} {employees[0].get('lastName')}")
    else:
        print("❌ Falha na conexão após renovar token")
else:
    print("❌ Falha ao renovar token")
