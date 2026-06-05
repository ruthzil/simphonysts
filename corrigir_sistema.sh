#!/bin/bash

echo "========================================="
echo "🔧 CORRIGINDO SISTEMA SIMPHONY"
echo "========================================="

cd /opt/simphony
source venv/bin/activate

# 1. Adicionar django_extensions ao settings.py
echo ""
echo "📦 1. Adicionando django_extensions ao INSTALLED_APPS..."
sed -i "/'corsheaders',/a \ \ \ \ 'django_extensions'," /opt/simphony/setup/settings.py

# 2. Criar view de cadastro
echo ""
echo "📝 2. Criando view de cadastro..."
cat >> /opt/simphony/simphony_integration/views.py << 'VIEW_EOF'

# View de Cadastro
def cadastrar(request):
    """View para cadastro de novos usuários/configurações"""
    from django.shortcuts import render, redirect
    from django.contrib import messages
    from django.contrib.auth.models import User
    from .models import IntegrationConfig  # Se existir
    
    if request.method == 'POST':
        # Processar formulário de cadastro
        username = request.POST.get('username')
        email = request.POST.get('email')
        password = request.POST.get('password')
        
        if username and email and password:
            # Criar usuário
            if not User.objects.filter(username=username).exists():
                user = User.objects.create_user(
                    username=username,
                    email=email,
                    password=password
                )
                messages.success(request, f'Usuário {username} cadastrado com sucesso!')
                return redirect('simphony_integration:dashboard')
            else:
                messages.error(request, 'Nome de usuário já existe!')
        else:
            messages.error(request, 'Todos os campos são obrigatórios!')
    
    return render(request, 'simphony_integration/cadastrar.html')

# View para listar usuários
def listar_usuarios(request):
    """View para listar usuários cadastrados"""
    from django.shortcuts import render
    from django.contrib.auth.models import User
    
    usuarios = User.objects.all()
    return render(request, 'simphony_integration/listar_usuarios.html', {
        'usuarios': usuarios
    })
VIEW_EOF

echo "✅ Views criadas!"

# 3. Adicionar URLs para cadastro
echo ""
echo "🔗 3. Adicionando URLs de cadastro..."
cat > /opt/simphony/simphony_integration/urls.py << 'URLS_EOF'
"""
URL configuration for simphony_integration app.
"""
from django.urls import path
from . import views

app_name = 'simphony_integration'

urlpatterns = [
    # Página principal do app
    path('', views.index, name='index'),

    # Dashboard
    path('dashboard/', views.dashboard, name='dashboard'),

    # Configurações
    path('settings/', views.settings, name='settings'),

    # Cadastro
    path('cadastrar/', views.cadastrar, name='cadastrar'),
    path('usuarios/', views.listar_usuarios, name='listar_usuarios'),

    # API endpoints
    path('api/integration/', views.api_integration, name='api_integration'),
]
URLS_EOF

echo "✅ URLs configuradas!"

# 4. Criar template para cadastro
echo ""
echo "🎨 4. Criando template de cadastro..."
cat > /opt/simphony/templates/simphony_integration/cadastrar.html << 'TEMPLATE_EOF'
{% extends 'base.html' %}

{% block title %}Cadastrar Usuário - Simphony{% endblock %}

{% block content %}
<div class="container mt-5">
    <div class="row justify-content-center">
        <div class="col-md-6">
            <div class="card shadow">
                <div class="card-header bg-primary text-white">
                    <h3 class="mb-0">
                        <i class="bi bi-person-plus"></i> Cadastrar Novo Usuário
                    </h3>
                </div>
                <div class="card-body">
                    {% if messages %}
                        {% for message in messages %}
                            <div class="alert alert-{{ message.tags }} alert-dismissible fade show" role="alert">
                                {{ message }}
                                <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
                            </div>
                        {% endfor %}
                    {% endif %}

                    <form method="post" action="{% url 'simphony_integration:cadastrar' %}">
                        {% csrf_token %}
                        
                        <div class="mb-3">
                            <label for="username" class="form-label">
                                <i class="bi bi-person"></i> Nome de Usuário
                            </label>
                            <input type="text" 
                                   class="form-control" 
                                   id="username" 
                                   name="username" 
                                   required 
                                   placeholder="Digite o nome de usuário">
                        </div>

                        <div class="mb-3">
                            <label for="email" class="form-label">
                                <i class="bi bi-envelope"></i> E-mail
                            </label>
                            <input type="email" 
                                   class="form-control" 
                                   id="email" 
                                   name="email" 
                                   required 
                                   placeholder="usuario@exemplo.com">
                        </div>

                        <div class="mb-3">
                            <label for="password" class="form-label">
                                <i class="bi bi-lock"></i> Senha
                            </label>
                            <input type="password" 
                                   class="form-control" 
                                   id="password" 
                                   name="password" 
                                   required 
                                   placeholder="Digite a senha">
                        </div>

                        <div class="mb-3">
                            <label for="confirm_password" class="form-label">
                                <i class="bi bi-lock-fill"></i> Confirmar Senha
                            </label>
                            <input type="password" 
                                   class="form-control" 
                                   id="confirm_password" 
                                   name="confirm_password" 
                                   required 
                                   placeholder="Confirme a senha">
                        </div>

                        <div class="d-grid gap-2">
                            <button type="submit" class="btn btn-primary btn-lg">
                                <i class="bi bi-check-circle"></i> Cadastrar
                            </button>
                            <a href="{% url 'simphony_integration:dashboard' %}" class="btn btn-secondary">
                                <i class="bi bi-arrow-left"></i> Voltar
                            </a>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    </div>
</div>

<script>
// Validação simples de senha
document.querySelector('form').addEventListener('submit', function(e) {
    const password = document.getElementById('password').value;
    const confirm = document.getElementById('confirm_password').value;
    
    if (password !== confirm) {
        e.preventDefault();
        alert('As senhas não coincidem!');
    }
});
</script>
{% endblock %}
TEMPLATE_EOF

# 5. Criar template para listar usuários
echo ""
echo "📋 5. Criando template de lista de usuários..."
cat > /opt/simphony/templates/simphony_integration/listar_usuarios.html << 'LISTA_EOF'
{% extends 'base.html' %}

{% block title %}Usuários Cadastrados - Simphony{% endblock %}

{% block content %}
<div class="container mt-4">
    <div class="d-flex justify-content-between align-items-center mb-4">
        <h2><i class="bi bi-people"></i> Usuários Cadastrados</h2>
        <a href="{% url 'simphony_integration:cadastrar' %}" class="btn btn-primary">
            <i class="bi bi-person-plus"></i> Novo Usuário
        </a>
    </div>

    <div class="card shadow">
        <div class="card-body">
            <div class="table-responsive">
                <table class="table table-hover">
                    <thead class="table-dark">
                        <tr>
                            <th>ID</th>
                            <th>Usuário</th>
                            <th>E-mail</th>
                            <th>Superusuário</th>
                            <th>Ativo</th>
                            <th>Data de Cadastro</th>
                        </tr>
                    </thead>
                    <tbody>
                        {% for usuario in usuarios %}
                        <tr>
                            <td>{{ usuario.id }}</td>
                            <td>
                                <i class="bi bi-person-circle"></i> 
                                {{ usuario.username }}
                            </td>
                            <td>
                                <i class="bi bi-envelope"></i> 
                                {{ usuario.email }}
                            </td>
                            <td>
                                {% if usuario.is_superuser %}
                                    <span class="badge bg-danger">Sim</span>
                                {% else %}
                                    <span class="badge bg-secondary">Não</span>
                                {% endif %}
                            </td>
                            <td>
                                {% if usuario.is_active %}
                                    <span class="badge bg-success">Ativo</span>
                                {% else %}
                                    <span class="badge bg-warning">Inativo</span>
                                {% endif %}
                            </td>
                            <td>{{ usuario.date_joined|date:"d/m/Y H:i" }}</td>
                        </tr>
                        {% empty %}
                        <tr>
                            <td colspan="6" class="text-center py-4">
                                <i class="bi bi-info-circle"></i> 
                                Nenhum usuário cadastrado ainda.
                                <br>
                                <a href="{% url 'simphony_integration:cadastrar' %}" class="btn btn-sm btn-primary mt-2">
                                    Cadastrar primeiro usuário
                                </a>
                            </td>
                        </tr>
                        {% endfor %}
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>
{% endblock %}
LISTA_EOF

# 6. Atualizar base.html para incluir Bootstrap Icons
echo ""
echo "🎨 6. Atualizando base.html..."
if ! grep -q "bootstrap-icons" /opt/simphony/templates/base.html; then
    sed -i '/<\/head>/i \    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">' /opt/simphony/templates/base.html
fi

# 7. Adicionar links no dashboard
echo ""
echo "📊 7. Atualizando dashboard.html..."
if [ -f /opt/simphony/templates/simphony_integration/dashboard.html ]; then
    if ! grep -q "cadastrar" /opt/simphony/templates/simphony_integration/dashboard.html; then
        sed -i '/{% block content %}/a \
<div class="alert alert-info mt-3">\
    <i class="bi bi-person-plus"></i> \
    <a href="{% url '\''simphony_integration:cadastrar'\'' %}" class="alert-link">Cadastrar novo usuário</a>\
    <br>\
    <i class="bi bi-people"></i> \
    <a href="{% url '\''simphony_integration:listar_usuarios'\'' %}" class="alert-link">Ver usuários cadastrados</a>\
</div>' /opt/simphony/templates/simphony_integration/dashboard.html
    fi
fi

# 8. Reiniciar serviços
echo ""
echo "🔄 8. Reiniciando Gunicorn..."
sudo systemctl restart gunicorn-simphony

echo ""
echo "========================================="
echo "✅ CORREÇÃO CONCLUÍDA COM SUCESSO!"
echo "========================================="
echo ""
echo "📌 URLs disponíveis agora:"
echo "   • /simphony/cadastrar/     - Cadastro de usuários"
echo "   • /simphony/usuarios/      - Lista de usuários"
echo "   • /simphony/dashboard/     - Dashboard"
echo "   • /simphony/settings/      - Configurações"
echo "   • /admin/                  - Admin Django"
echo ""
echo "🧪 Para testar no shell:"
echo "   python manage.py shell"
echo "   >>> from django.test import Client"
echo "   >>> c = Client()"
echo "   >>> response = c.get('/simphony/cadastrar/')"
echo "   >>> print(response.status_code)  # Deve retornar 200"
echo ""
echo "🌐 Acesse no navegador:"
echo "   http://simphonysts.ddns.net/simphony/cadastrar/"
echo "========================================="

