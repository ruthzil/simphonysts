#!/bin/bash

echo "========================================="
echo "🔧 CORREÇÃO FINAL DO SISTEMA"
echo "========================================="

cd /opt/simphony
source venv/bin/activate

# 1. Corrigir django_extensions duplicado
echo ""
echo "📦 1. Corrigindo INSTALLED_APPS..."
python << PYTHON_SCRIPT
import re

with open('/opt/simphony/setup/settings.py', 'r') as f:
    content = f.read()

# Remover duplicatas de django_extensions
lines = content.split('\n')
new_lines = []
django_extensions_found = False

for line in lines:
    if 'django_extensions' in line:
        if not django_extensions_found:
            new_lines.append(line)
            django_extensions_found = True
    else:
        new_lines.append(line)

with open('/opt/simphony/setup/settings.py', 'w') as f:
    f.write('\n'.join(new_lines))

print("✅ django_extensions corrigido!")
PYTHON_SCRIPT

# 2. Liberar porta 9200
echo ""
echo "🔌 2. Liberando porta 9200..."
sudo fuser -k 9200/tcp 2>/dev/null || echo "Porta já está livre"
sleep 2

# 3. Parar e iniciar Gunicorn corretamente
echo ""
echo "🔄 3. Reiniciando serviços..."
sudo systemctl stop gunicorn-simphony
sleep 2
sudo systemctl start gunicorn-simphony
sleep 3

# 4. Verificar status
echo ""
echo "📊 4. Verificando status..."
sudo systemctl status gunicorn-simphony --no-pager -l

# 5. Testar se o Django está funcionando
echo ""
echo "🧪 5. Testando Django..."
python manage.py check

echo ""
echo "========================================="
echo "✅ CORREÇÃO CONCLUÍDA!"
echo "========================================="

# 6. Mostrar logs recentes
echo ""
echo "📋 Últimos logs do Gunicorn:"
sudo journalctl -u gunicorn-simphony -n 10 --no-pager

