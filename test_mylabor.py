#!/usr/bin/env python
"""Script para testar a API MyLabor do Oracle Simphony"""

import requests
import sys
import os

# Adicionar o diretório do Django ao path
sys.path.insert(0, '/opt/simphony')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'setup.settings')

import django
django.setup()
from django.conf import settings

# Headers SOAP
headers = {
    'Content-Type': 'text/xml; charset=utf-8',
    'SOAPAction': '""'
}

url = "https://us07-omra.oracleindustry.com/ws/mylabor"

# SOAP com WS-Security UsernameToken
soap_body = f"""<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Header>
    <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd" soap:mustUnderstand="1">
      <wsse:UsernameToken>
        <wsse:Username>ZONE1</wsse:Username>
        <wsse:Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText">{settings.PASSWORD}</wsse:Password>
      </wsse:UsernameToken>
    </wsse:Security>
  </soap:Header>
  <soap:Body>
    <getEmployeeClockStatuses xmlns="http://net.mymicros/mylabor">
      <updatedSince>2020-01-01T00:00:00</updatedSince>
    </getEmployeeClockStatuses>
  </soap:Body>
</soap:Envelope>"""

print("🔍 Chamando getEmployeeClockStatuses...")
resp = requests.post(url, data=soap_body, headers=headers, timeout=30)
print(f"Status: {resp.status_code}")
print(f"Resposta:\n{resp.text[:2000]}")

# Testar também getLocationList
soap_body2 = f"""<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Header>
    <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd" soap:mustUnderstand="1">
      <wsse:UsernameToken>
        <wsse:Username>ZONE1</wsse:Username>
        <wsse:Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText">{settings.PASSWORD}</wsse:Password>
      </wsse:UsernameToken>
    </wsse:Security>
  </soap:Header>
  <soap:Body>
    <getLocationList xmlns="http://net.mymicros/mylabor"/>
  </soap:Body>
</soap:Envelope>"""

print("\n\n🔍 Chamando getLocationList...")
resp = requests.post(url, data=soap_body2, headers=headers, timeout=30)
print(f"Status: {resp.status_code}")
print(f"Resposta:\n{resp.text[:2000]}")

# Testar getUpdatedEmployees
soap_body3 = f"""<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Header>
    <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd" soap:mustUnderstand="1">
      <wsse:UsernameToken>
        <wsse:Username>ZONE1</wsse:Username>
        <wsse:Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText">{settings.PASSWORD}</wsse:Password>
      </wsse:UsernameToken>
    </wsse:Security>
  </soap:Header>
  <soap:Body>
    <getUpdatedEmployees xmlns="http://net.mymicros/mylabor">
      <updatedSince>2020-01-01T00:00:00</updatedSince>
    </getUpdatedEmployees>
  </soap:Body>
</soap:Envelope>"""

print("\n\n🔍 Chamando getUpdatedEmployees...")
resp = requests.post(url, data=soap_body3, headers=headers, timeout=30)
print(f"Status: {resp.status_code}")
print(f"Resposta:\n{resp.text[:2000]}")
