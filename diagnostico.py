#!/usr/bin/env python
import os
import sys
import django

sys.path.append('/opt/simphony/setup')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'setup.settings')
django.setup()

from django.conf import settings

print("=" * 50)
print("DIAGNÓSTICO DO DJANGO")
print("=" * 50)

print(f"DEBUG: {settings.DEBUG}")
print(f"ALLOWED_HOSTS: {settings.ALLOWED_HOSTS}")
print(f"SECRET_KEY: {settings.SECRET_KEY[:20]}...")
print(f"INSTALLED_APPS: {len(settings.INSTALLED_APPS)} apps")
print(f"ROOT_URLCONF: {settings.ROOT_URLCONF}")

