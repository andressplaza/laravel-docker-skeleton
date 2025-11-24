# 🚀 Deployment Guide - Production Ready

## Tabla de Contenidos

1. [Pre-deployment Checklist](#pre-deployment-checklist)
2. [Preparar Ambiente](#preparar-ambiente)
3. [Deploy Local Docker](#deploy-local-docker)
4. [Deploy Kubernetes](#deploy-kubernetes)
5. [Monitoreo y Observabilidad](#monitoreo-y-observabilidad)
6. [Rollback y Recovery](#rollback-y-recovery)
7. [Troubleshooting](#troubleshooting)

---

## ✅ Pre-deployment Checklist

Antes de cualquier deployment a producción:

### Código
- [ ] Todos los tests pasen: `make lint`
- [ ] Code coverage mínimo: 80%
- [ ] No hay warnings en PHPStan nivel 6
- [ ] Code style PSR12 cumplido
- [ ] Seguridad: Composer audit sin problemas
- [ ] Git tags con versión: `v1.0.0`

### Configuración
- [ ] `.env.docker.prod` configurado con valores reales
- [ ] `APP_KEY` generado: `php artisan key:generate`
- [ ] Database credentials seguros (no hardcodeados)
- [ ] Redis password fuerte (16+ caracteres)
- [ ] CORS y CSRF properly configured

### Seguridad
- [ ] SSL certificates listos (o Let's Encrypt)
- [ ] Firewall configurado (solo puertos 80, 443)
- [ ] SSH keys para acceso (no password)
- [ ] Secrets en CI/CD variables, no en archivos
- [ ] Database con usuario limitado (no root)

### Datos
- [ ] Database backups automatizados
- [ ] Backup copy verificado
- [ ] Storage volumes backed up
- [ ] Disaster recovery plan documentado

### Monitoreo
- [ ] Health checks configurados
- [ ] Alertas activas
- [ ] Logs centralizados
- [ ] Métricas visibles en dashboard
- [ ] Oncall rotation establecida

### Performance
- [ ] Load testing realizado
- [ ] OPCache warming
- [ ] Database indexes verificados
- [ ] Caché strategy optimizada

---

## 🔧 Preparar Ambiente

### 1. Configuración de Infraestructura

```bash
# En tu servidor/cloud provider:

# 1. DNS apuntando a tu servidor
# 2. Firewall: Solo 80, 443, 22 (SSH)
# 3. SSL certificados (Let's Encrypt)
# 4. Storage para persistencia
# 5. Backups automáticos

# Requisitos:
# - Docker 24+
# - Docker Compose 2.0+
# - 4GB RAM mínimo
# - 20GB storage mínimo
# - Ubuntu 22.04 LTS recomendado
```

### 2. Generar SSL Certificates

#### Opción A: Let's Encrypt (Recomendado)

```bash
# Instalar Certbot
sudo apt-get update
sudo apt-get install -y certbot python3-certbot-nginx

# Generar certificado
sudo certbot certonly --standalone -d yourdomain.com

# Copiar a proyecto
sudo mkdir -p ./certs
sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem ./certs/cert.pem
sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem ./certs/key.pem
sudo chown $(whoami) ./certs/*
```

#### Opción B: Self-signed (Testing solo)

```bash
# ⚠️ No usar en producción
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ./certs/key.pem \
  -out ./certs/cert.pem \
  -subj "/C=US/ST=State/L=City/O=Org/CN=localhost"
```

### 3. Preparar `.env.docker.prod`

```bash
# Copiar template
cp .env.docker.prod .env.docker.prod.local

# ⚠️ NUNCA COMMITEAR .env.docker.prod.local

# Editar con valores reales
vim .env.docker.prod.local

# Variables requeridas:
# - POSTGRES_PASSWORD (16+ caracteres aleatorios)
# - REDIS_PASSWORD (16+ caracteres aleatorios)
# - APP_KEY (output de: php artisan key:generate)
# - MAIL_FROM_ADDRESS (tu email)
```

### 4. Crear Volúmenes

```bash
# Directorio para persistencia
mkdir -p ./storage/postgres_data
mkdir -p ./storage/redis_data
mkdir -p ./storage/app_storage

chmod 755 ./storage/*

# Copiar certs
mkdir -p ./certs
# (Ya deberían estar del paso anterior)
```

---

## 🐳 Deploy Local Docker

### Paso 1: Pull de Imágenes

```bash
# Build o pull imágenes
docker compose -f docker-compose.prod.yml build

# O pull del registry si están pre-buildidas
docker pull ghcr.io/myorg/laravel/php:1.0.0
docker pull ghcr.io/myorg/laravel/nginx:1.0.0
```

### Paso 2: Levantar Servicios

```bash
# Start en background
docker compose -f docker-compose.prod.yml up -d

# Esperar a que postgres inicie (5-10 segundos)
sleep 10

# Ver logs
docker compose -f docker-compose.prod.yml logs -f
```

### Paso 3: Inicializar Database

```bash
# Migraciones
docker compose -f docker-compose.prod.yml exec php \
  php artisan migrate --force

# Seeders (si aplica)
docker compose -f docker-compose.prod.yml exec php \
  php artisan db:seed --force

# Verificar
docker compose -f docker-compose.prod.yml exec php \
  php artisan db:show
```

### Paso 4: Preparar Aplicación

```bash
# Config cache (optimización)
docker compose -f docker-compose.prod.yml exec php \
  php artisan config:cache

# Route cache
docker compose -f docker-compose.prod.yml exec php \
  php artisan route:cache

# View cache
docker compose -f docker-compose.prod.yml exec php \
  php artisan view:cache

# OPCache warmup (opcional, necesita script)
docker compose -f docker-compose.prod.yml exec php \
  php artisan opcache:warm
```

### Paso 5: Verificar Salud

```bash
# Liveness check
curl http://localhost/health/live
# Esperado: 200 OK "healthy"

# Readiness check
curl http://localhost/health/ready
# Esperado: 200 OK con status "ready"

# Detailed report
curl -H "X-Health-Token: your_token" http://localhost/health/report
# Esperado: 200 OK con métricas

# HTTPS (si certificados listos)
curl https://yourdomain.com/health/live
```

### Paso 6: Configurar Reverse Proxy (Opcional)

Si usas Nginx/HAProxy como reverse proxy:

```nginx
upstream backend {
    server localhost:80 max_fails=3 fail_timeout=30s;
}

server {
    listen 80;
    server_name yourdomain.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name yourdomain.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## ☸️ Deploy Kubernetes

### 1. Preparar Imágenes

```bash
# Tag images
docker tag laravel/php:dev ghcr.io/myorg/laravel/php:1.0.0
docker tag laravel/nginx:dev ghcr.io/myorg/laravel/nginx:1.0.0

# Push a registry
docker push ghcr.io/myorg/laravel/php:1.0.0
docker push ghcr.io/myorg/laravel/nginx:1.0.0
```

### 2. Crear Kubernetes Manifests

```yaml
# k8s/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: laravel-prod

---

# k8s/secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: laravel-secrets
  namespace: laravel-prod
type: Opaque
stringData:
  postgres-password: "your_secure_password"
  redis-password: "your_redis_password"
  app-key: "base64:xxxxx"

---

# k8s/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: laravel-config
  namespace: laravel-prod
data:
  APP_ENV: "production"
  APP_DEBUG: "false"
  DB_CONNECTION: "pgsql"
  DB_HOST: "postgres"
  DB_PORT: "5432"
  DB_DATABASE: "laravel_prod"
  LOG_CHANNEL: "json_stderr"

---

# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: laravel-php
  namespace: laravel-prod
spec:
  replicas: 3
  selector:
    matchLabels:
      app: laravel-php
  template:
    metadata:
      labels:
        app: laravel-php
    spec:
      containers:
      - name: php
        image: ghcr.io/myorg/laravel/php:1.0.0
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 9000
        envFrom:
        - configMapRef:
            name: laravel-config
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: laravel-secrets
              key: postgres-password
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: laravel-secrets
              key: redis-password
        - name: APP_KEY
          valueFrom:
            secretKeyRef:
              name: laravel-secrets
              key: app-key
        livenessProbe:
          httpGet:
            path: /health/live
            port: 9000
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 9000
          initialDelaySeconds: 10
          periodSeconds: 10
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "1"
        volumeMounts:
        - name: storage
          mountPath: /var/www/html/storage
      volumes:
      - name: storage
        persistentVolumeClaim:
          claimName: laravel-storage

---

# k8s/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: laravel-php-service
  namespace: laravel-prod
spec:
  selector:
    app: laravel-php
  ports:
  - port: 9000
    targetPort: 9000
  type: ClusterIP

---

# k8s/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: laravel-ingress
  namespace: laravel-prod
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - yourdomain.com
    secretName: laravel-cert
  rules:
  - host: yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: laravel-php-service
            port:
              number: 9000
```

### 3. Deploy a Kubernetes

```bash
# Aplicar manifests
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml

# Verificar
kubectl get pods -n laravel-prod
kubectl get services -n laravel-prod
kubectl get ingress -n laravel-prod

# Ver logs
kubectl logs -n laravel-prod -l app=laravel-php -f

# Port forward para debugging
kubectl port-forward -n laravel-prod svc/laravel-php-service 9000:9000
```

---

## 📊 Monitoreo y Observabilidad

### Health Check Endpoints

```bash
# Estos endpoints estar disponibles 24/7:

# 1. Liveness (que el contenedor esté vivo)
curl http://localhost/health/live

# 2. Readiness (que acepte tráfico)
curl http://localhost/health/ready

# 3. Startup (que haya iniciado)
curl http://localhost/health/startup

# 4. Report (métricas detalladas)
curl -H "X-Health-Token: xxx" http://localhost/health/report
```

### Logs Centralizados

```bash
# Ver logs en tiempo real
docker compose -f docker-compose.prod.yml logs -f php

# Ver errores
docker compose -f docker-compose.prod.yml logs php | grep ERROR

# Exportar a archivo
docker compose -f docker-compose.prod.yml logs > logs.txt

# Con grep (búsqueda)
docker compose -f docker-compose.prod.yml logs | grep "user_id"
```

### Alertas Recomendadas

1. **Health Check Failed**
   - Si `/health/ready` devuelve 503 por más de 2 minutos
   - Acción: Página de error, escalación

2. **High Memory Usage**
   - Si PHP > 400MB (del límite 512MB)
   - Acción: Investigar memory leaks

3. **High Error Rate**
   - Si 5xx errors > 1% en 5 minutos
   - Acción: Rollback

4. **Database Down**
   - Si conexión DB falla
   - Acción: Restaurar desde backup

5. **Disk Space**
   - Si storage > 90% lleno
   - Acción: Limpiar logs, expandir storage

---

## 🔄 Rollback y Recovery

### Rollback a Versión Anterior

```bash
# 1. Identificar versión anterior
docker images | grep laravel/php

# 2. Detener deployment actual
docker compose -f docker-compose.prod.yml down

# 3. Usar versión anterior
docker compose -f docker-compose.prod.yml up -d

# 4. Verificar
make health-check  # Desde Makefile

# 5. Si falla, restaurar database
mysql -h localhost -u root < database_backup_20250101.sql
```

### Recovery Completo

```bash
# Si todo falla:

# 1. Backup estado actual
docker compose -f docker-compose.prod.yml exec postgres \
  pg_dump -U laravel_prod_user -d laravel_prod > backup_crashed.sql

# 2. Parar servicios
docker compose -f docker-compose.prod.yml down -v

# 3. Eliminar volúmenes
docker volume rm laravel_postgres_data laravel_redis_data

# 4. Restaurar volúmenes desde backup
# (que deberías tener guardado en remote storage)

# 5. Levantar nuevamente
docker compose -f docker-compose.prod.yml up -d

# 6. Verificar
make health-check
```

---

## 🐛 Troubleshooting

### Database Connection Failed

```bash
# 1. Verificar que postgres esté corriendo
docker compose -f docker-compose.prod.yml ps postgres

# 2. Ver logs de postgres
docker compose -f docker-compose.prod.yml logs postgres

# 3. Conectar directamente
docker compose -f docker-compose.prod.yml exec postgres \
  psql -U laravel_prod_user -d laravel_prod

# 4. Verificar credenciales en .env.docker.prod
grep DB_ .env.docker.prod

# 5. Reiniciar
docker compose -f docker-compose.prod.yml restart postgres
```

### Health Check Failing

```bash
# 1. Verificar que endpoint responde
curl http://localhost/health/live

# 2. Ver logs detallados
docker compose -f docker-compose.prod.yml logs php | tail -50

# 3. Ejecutar health check manualmente
docker compose -f docker-compose.prod.yml exec php \
  php artisan health:check

# 4. Verificar recursos
docker stats

# 5. Si memoria es el problema, restart
docker compose -f docker-compose.prod.yml restart php
```

### High Memory Usage

```bash
# 1. Ver consumo
docker stats

# 2. Ver procesos PHP
docker compose -f docker-compose.prod.yml exec php ps aux

# 3. Verificar memory leaks en Laravel
docker compose -f docker-compose.prod.yml exec php \
  php -r "echo memory_get_peak_usage(true) / 1024 / 1024 . ' MB';"

# 4. Si hay memory leaks, investigar:
# - Check for circular references
# - Verificar event listeners
# - Cache que no se limpia

# 5. Aumentar límite temporalmente mientras se arregla
# (En docker-compose.prod.yml)
```

### Logs No Visibles

```bash
# 1. Verificar driver de logging
docker inspect <container> | grep -A 5 "LogDriver"

# 2. Ver logs del contenedor
docker logs <container>

# 3. Verificar permisos de archivo
docker compose -f docker-compose.prod.yml exec php \
  ls -la storage/logs/

# 4. Si archivo está vacío, crear logs de prueba
docker compose -f docker-compose.prod.yml exec php \
  php artisan tinker
  # Dentro de tinker:
  Log::info('Test message')
```

---

## 📈 Post-Deploy

### 1. Smoke Testing

```bash
curl -X GET http://yourdomain.com/health/live
curl -X GET http://yourdomain.com/
curl -X GET http://yourdomain.com/api/health
```

### 2. Database Verification

```bash
# Verificar tablas
docker compose -f docker-compose.prod.yml exec php \
  php artisan db:show

# Contar registros
docker compose -f docker-compose.prod.yml exec php \
  php artisan tinker
  User::count()
```

### 3. Log Verification

```bash
# Verificar que logs se escriben en JSON
docker compose -f docker-compose.prod.yml logs php | head
# Debería ver JSON structures
```

### 4. Backup Initial

```bash
# Crear backup después de successful deploy
docker compose -f docker-compose.prod.yml exec postgres \
  pg_dump -U laravel_prod_user -d laravel_prod \
  > database_backup_post_deploy_$(date +%Y%m%d_%H%M%S).sql

# Guardar en storage remoto
```

---

## ✅ Deployment Success Criteria

- [ ] Health checks todos 200 OK
- [ ] Database migraciones completadas
- [ ] Logs visibles en formato JSON
- [ ] Usuarios pueden acceder a la app
- [ ] HTTPS funcionando con certificado válido
- [ ] Performance aceptable (< 500ms response time)
- [ ] Sin errores en logs
- [ ] Backups funcionando
- [ ] Alertas activas y notificando

---

*Este documento es una guía viva - actualizar con experiencias en producción*
