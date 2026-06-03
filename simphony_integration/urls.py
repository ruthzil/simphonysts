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
