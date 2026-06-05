#!/bin/bash

echo "========================================="
echo "Testando Sistema Simphony STS"
echo "========================================="

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Teste 1: Verificar se o Gunicorn está rodando
echo -e "\n${YELLOW}1. Verificando Gunicorn...${NC}"
if pgrep -f "gunicorn.*9200" > /dev/null; then
    echo -e "${GREEN}✓ Gunicorn está rodando na porta 9200${NC}"
else
    echo -e "${RED}✗ Gunicorn não está rodando${NC}"
fi

# Teste 2: Testar conexão local
echo -e "\n${YELLOW}2. Testando conexão com Gunicorn...${NC}"
if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:9200/ | grep -q "200\|302\|301"; then
    echo -e "${GREEN}✓ Gunicorn está respondendo${NC}"
else
    echo -e "${RED}✗ Gunicorn não está respondendo${NC}"
fi

# Teste 3: Testar API Status
echo -e "\n${YELLOW}3. Testando API Status...${NC}"
API_STATUS=$(curl -s http://127.0.0.1:9200/simphony/api-status/)
if [[ $API_STATUS == *"online"* ]] || [[ $API_STATUS == *"offline"* ]]; then
    echo -e "${GREEN}✓ API Status endpoint funcionando${NC}"
    echo "Resposta: $API_STATUS"
else
    echo -e "${RED}✗ API Status endpoint com problema${NC}"
fi

# Teste 4: Verificar Nginx
echo -e "\n${YELLOW}4. Verificando Nginx...${NC}"
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✓ Nginx está rodando${NC}"
else
    echo -e "${RED}✗ Nginx não está rodando${NC}"
fi

# Teste 5: Testar acesso via HTTPS
echo -e "\n${YELLOW}5. Testando acesso HTTPS...${NC}"
HTTPS_CODE=$(curl -s -k -o /dev/null -w "%{http_code}" https://localhost/simphony/)
if [[ $HTTPS_CODE == "200" ]] || [[ $HTTPS_CODE == "302" ]]; then
    echo -e "${GREEN}✓ HTTPS está funcionando (código $HTTPS_CODE)${NC}"
else
    echo -e "${RED}✗ HTTPS com problema (código $HTTPS_CODE)${NC}"
fi

echo -e "\n========================================="
echo "Acesse o sistema: https://simphonysts.ddns.net"
echo "Login: admin"
echo "Senha: admin123"
echo "========================================="
