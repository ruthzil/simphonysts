#!/usr/bin/env python
import os
import sys
import django

# Configurar Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'setup.settings')
sys.path.append('/opt/simphony')
django.setup()

from simphony_integration.services import SimphonyAPIService

def test_api():
    print("=" * 50)
    print("Testando API Simphony")
    print("=" * 50)
    
    api = SimphonyAPIService()
    
    # Testar conexão
    print("\n1. Testando conexão...")
    connected = api.test_connection()
    print(f"   Conectado: {connected}")
    
    if not connected:
        print("   ERRO: Não foi possível conectar à API")
        return
    
    # Buscar funcionários
    print("\n2. Buscando funcionários...")
    employees = api.get_employees()
    if employees:
        print(f"   Encontrados {len(employees)} funcionários")
        for emp in employees[:5]:
            print(f"   - ID {emp.get('objectNum')}: {emp.get('firstName')} {emp.get('lastName')}")
    else:
        print("   Nenhum funcionário encontrado")
    
    # Testar update no funcionário 5
    print("\n3. Testando update do funcionário 5...")
    result = api.update_employee(5, {
        'firstName': 'João',
        'lastName': 'Silva Teste',
        'checkName': 'J.TESTE',
        'email': 'joao.teste@email.com',
        'userName': 'jteste'
    })
    
    if result:
        print(f"   ✅ Update realizado! Resposta: {result}")
    else:
        print("   ❌ Falha no update - verifique se o funcionário 5 existe")
    
    # Testar criação de novo funcionário
    print("\n4. Testando criação de funcionário...")
    new_employee = {
        'objectNum': 9999,
        'firstName': 'Teste',
        'lastName': 'Criacao',
        'checkName': 'T.CRIACAO',
        'email': 'teste@criacao.com',
        'userName': 'tcriacao',
        'languageObjNum': 1
    }
    
    result = api.create_employee(new_employee)
    if result:
        print(f"   ✅ Funcionário criado! Resposta: {result}")
    else:
        print("   ❌ Falha na criação (pode já existir ou falta permissão)")

if __name__ == '__main__':
    test_api()
