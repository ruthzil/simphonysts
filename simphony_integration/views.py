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
