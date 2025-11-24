# Laravel Docker Skeleton - Production Ready

> Una configuración Docker profesional para Laravel con seguridad, observabilidad y escalabilidad

## 🎯 Características

### ✅ Seguridad
- ✓ Credenciales separadas por entorno (`.env`, `.env.docker`, `.env.docker.prod`)
- ✓ Variables de entorno no versionadas
- ✓ Nginx con HTTPS y security headers
- ✓ PHP sin usuario root
- ✓ Health checks integrados
- ✓ Rate limiting y protección de endpoints

### ⚡ Performance
- ✓ Multi-stage Docker builds (reducción de tamaño de imágenes)
- ✓ OPCache habilitado en producción
- ✓ Gzip compression en Nginx
- ✓ Caching de assets estáticos (1 año)
- ✓ Database connection pooling
- ✓ Redis para cache y sessions

### 📊 Observabilidad
- ✓ Logging estructurado en JSON
- ✓ Health checks (liveness, readiness, startup)
- ✓ Logs centralizados en stderr para Docker
- ✓ Health report endpoint con métricas
- ✓ Container restart policies

### 🚀 DevOps Ready
- ✓ Separación clara: `docker-compose.yml` (dev) vs `docker-compose.prod.yml` (prod)
- ✓ CI/CD completo con GitHub Actions
- ✓ Security scanning (Trivy, composer audit)
- ✓ Semantic versioning automático
- ✓ Límites de recursos configurados
- ✓ Volúmenes nombrados en producción

---

## 📋 Estructura del Proyecto

```
laravel-docker-skeleton/
├── docker/
│   ├── php/
│   │   ├── Dockerfile           # Multi-stage build
│   │   ├── custom.development.ini
│   │   └── custom.production.ini
│   ├── nginx/
│   │   ├── Dockerfile
│   │   ├── default.conf         # Desarrollo
│   │   └── default.conf.prod    # Producción
│   ├── postgres/
│   └── redis/
├── .github/workflows/
│   ├── ci.yml                   # Linting, testing, scanning
│   └── deploy.yml               # Build, push, release
├── src/                         # Código Laravel
├── docker-compose.yml           # DESARROLLO
├── docker-compose.prod.yml      # PRODUCCIÓN
├── .env.example                 # Referencia
├── .env.docker                  # Dev local (NO versionar)
├── .env.docker.prod             # Prod (use secrets)
└── .gitignore                   # Proteger .env*
```

---

## 🚀 Quick Start - Desarrollo Local

### 1️⃣ Clonar y configurar

```bash
git clone <repo>
cd laravel-docker-skeleton

# Copiar configuración de desarrollo
cp .env.docker.example .env.docker

# Asegurar permisos
chmod +x setup.sh
```

### 2️⃣ Levantar los contenedores

```bash
# Desarrollo (hot reload activado)
docker-compose up -d

# Verificar que todo está listo
docker-compose ps
docker-compose logs -f php
```

### 3️⃣ Inicializar Laravel

```bash
# Dentro del contenedor PHP
docker-compose exec php bash

# O ejecutar directamente
docker-compose exec php composer install
docker-compose exec php php artisan key:generate
docker-compose exec php php artisan migrate
```

### 4️⃣ Acceder a la aplicación

- **Web**: http://localhost:8080
- **Mailhog**: http://localhost:1025 (si configurado)
- **Vite DevServer**: http://localhost:5173

---

## 🏭 Producción - Deployment

### 1️⃣ Configurar secretos

```bash
# Crear archivo .env.docker.prod con valores reales
POSTGRES_PASSWORD=your_super_secret_password
REDIS_PASSWORD=your_redis_secret
APP_KEY=base64:xxxxx

# ⚠️ NUNCA commitear .env.docker.prod
```

### 2️⃣ Generar certificados SSL

```bash
# Let's Encrypt con Certbot
mkdir -p ./certs
certbot certonly --standalone -d yourdomain.com

# Copiar a volumen
cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem ./certs/cert.pem
cp /etc/letsencrypt/live/yourdomain.com/privkey.pem ./certs/key.pem
```

### 3️⃣ Desplegar con docker-compose

```bash
# Levantar stack de producción
docker-compose -f docker-compose.prod.yml up -d

# Ver logs
docker-compose -f docker-compose.prod.yml logs -f php

# Ejecutar migraciones
docker-compose -f docker-compose.prod.yml exec php php artisan migrate --force
```

### 4️⃣ Verificar salud

```bash
# Liveness check
curl http://localhost/health/live

# Readiness check (con dependencias)
curl http://localhost/health/ready

# Detailed report (requiere token)
curl -H "X-Health-Token: your_token" http://localhost/health/report
```

---

## 📝 Configuración por Entorno

### 🖥️ Desarrollo

**Archivo**: `.env.docker`
```bash
APP_ENV=local
APP_DEBUG=true
LOG_CHANNEL=json          # JSON logs para análisis
LOG_LEVEL=debug
SESSION_DRIVER=cookie
QUEUE_CONNECTION=redis
```

**Características**:
- Hot reload habilitado (bind mounts)
- Logs en stderr y archivos
- Debug toolbar disponible
- Mail en formato log

### 🌍 Producción

**Archivo**: `.env.docker.prod`
```bash
APP_ENV=production
APP_DEBUG=false
LOG_CHANNEL=json_stderr   # Solo stderr (Docker captura)
LOG_LEVEL=warning
SESSION_DRIVER=cookie
QUEUE_CONNECTION=redis
```

**Características**:
- Volúmenes nombrados (sin bind mounts)
- OPCache habilitado
- HTTPS obligatorio
- Health checks en todos los servicios
- Límites de CPU y memoria

---

## 🐳 Docker Images

### Multi-stage PHP Build

**Desarrollo**:
```dockerfile
# Stage 1: Builder (incluye git, unzip, dev tools)
# Stage 2: Runtime (solo librerías necesarias)
# Resultado: imagen lista para desarrollo con hot reload
```

**Producción**:
```dockerfile
# Stage 1: Builder (descarga composer packages)
# Stage 2: Runtime (solo librerías de runtime, sin dev tools)
# Resultado: imagen minimal y optimizada
```

**Tamaño típico**:
- Dev: ~650MB
- Prod: ~350MB (50% menor)

### Nginx

- **Dev**: Simple routing + PHP socket
- **Prod**: Reverse proxy + HTTPS + caching + security headers

---

## 🩺 Health Checks

La aplicación expone 4 endpoints de salud:

### 1. Liveness Probe

```bash
curl http://localhost/health/live

# Response: 200 OK
# "healthy\n"
```

**¿Qué valida?**: Solo que el servidor está corriendo.

### 2. Readiness Probe

```bash
curl http://localhost/health/ready

# Response: 200 OK (si todo está listo)
# {
#   "status": "ready",
#   "checks": {
#     "database": {"status": "ok"},
#     "redis": {"status": "ok"},
#     "cache": {"status": "ok"}
#   }
# }
```

**¿Qué valida?**: Database, Redis, Cache. Falla si alguno no está disponible.

### 3. Startup Probe

```bash
curl http://localhost/health/startup

# Response: 200 OK
```

**¿Qué valida?**: Que la app completó la inicialización (sin dependencias).

### 4. Detailed Report (requiere autorización)

```bash
curl -H "X-Health-Token: your_token" http://localhost/health/report

# Response:
# {
#   "app": {...},
#   "checks": {
#     "database": {"status": "ok", "query_time_ms": 2.5},
#     "disk_space": {"status": "ok", "used_percent": 45},
#     ...
#   }
# }
```

---

## 📊 Logging Estructurado

### Formato JSON

Todos los logs en producción se emiten en JSON:

```json
{
  "message": "User login successful",
  "context": {},
  "level": "info",
  "level_name": "INFO",
  "channel": "production",
  "datetime": "2025-11-24T10:30:00.000000+00:00",
  "extra": {
    "process_id": 1234
  }
}
```

### Captura de logs

```bash
# Ver logs en tiempo real
docker-compose -f docker-compose.prod.yml logs -f php

# Solo errores
docker-compose -f docker-compose.prod.yml logs -f php --since 1h | grep ERROR

# Exportar a archivo
docker-compose logs -f > logs.txt &
```

---

## 🔒 Seguridad

### 1. Credenciales

✅ **Buenas prácticas implementadas:**

```bash
# ✓ .env nunca versionado
# ✓ .env.example como referencia (sin valores reales)
# ✓ .env.docker.prod con placeholders
# ✓ Usar Docker secrets o CI/CD variables en producción
```

### 2. HTTPS en Producción

```bash
# nginx/default.conf.prod incluye:
# - Redirect HTTP → HTTPS
# - TLS 1.2 + 1.3
# - Strong ciphers
# - HSTS headers
```

### 3. Security Headers

```nginx
# Implementados en Nginx:
Strict-Transport-Security: max-age=31536000
X-Frame-Options: SAMEORIGIN
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
```

### 4. Rate Limiting

```nginx
# Configurado en Nginx (prod):
# - API: 10 req/s
# - Upload: 5 req/min
# - General: con burst allowance
```

---

## ⚙️ CI/CD Pipeline

### Workflows Implementados

**1. `ci.yml` - Cada push/PR**
- ✓ PHPStan (análisis estático)
- ✓ PHPCS (code style)
- ✓ Trivy (vulnerability scanning)
- ✓ Composer audit (dependency vulnerabilities)
- ✓ PHPUnit tests
- ✓ Docker build test

**2. `deploy.yml` - Main branch**
- ✓ Build Docker images
- ✓ Push a registry (GHCR)
- ✓ Create release tags
- ✓ Generate changelog

### Ejecutar localmente

```bash
# Simular CI
act -j code-quality
act -j security
act -j tests

# (Requiere https://github.com/nektos/act)
```

---

## 📈 Recursos y Límites

### Docker Compose Production

```yaml
php:
  deploy:
    resources:
      limits:
        cpus: '1'
        memory: 512M
      reservations:
        cpus: '0.5'
        memory: 256M

postgres:
  deploy:
    resources:
      limits:
        cpus: '2'
        memory: 1G

redis:
  deploy:
    resources:
      limits:
        cpus: '0.5'
        memory: 512M
```

### Optimizaciones

- **PHP**: OPCache, JIT disabled (por stabilidad)
- **Database**: Connection pooling, indexes
- **Redis**: `appendonly yes` (AOF), persistence
- **Nginx**: Gzip, cache headers, connection reuse

---

## 🛠️ Tareas Comunes

### Ejecutar comandos Artisan

```bash
# Desarrollo
docker-compose exec php php artisan migrate
docker-compose exec php php artisan tinker

# Producción
docker-compose -f docker-compose.prod.yml exec php php artisan migrate --force
```

### Acceder a la base de datos

```bash
# Desarrollo
docker-compose exec postgres psql -U laravel -d laravel

# Producción
docker-compose -f docker-compose.prod.yml exec postgres psql -U laravel_prod_user -d laravel_prod
```

### Ver logs

```bash
# Todos los servicios
docker-compose logs -f

# Solo PHP
docker-compose logs -f php

# Últimas 100 líneas
docker-compose logs --tail=100 php
```

### Rebuild images

```bash
docker-compose build --no-cache
docker-compose up -d
```

### Limpiar volúmenes

```bash
# ⚠️ Elimina todos los datos
docker-compose down -v
```

---

## 🐛 Troubleshooting

### "Connection refused" PostgreSQL

```bash
# Verificar health check
docker-compose ps postgres

# Ver logs
docker-compose logs postgres

# Reiniciar
docker-compose restart postgres
```

### PHP no compila extensiones

```bash
# Rebuild desde cero
docker-compose build --no-cache php
docker-compose up -d
```

### Permisos en storage/

```bash
# Asegurar permisos
docker-compose exec php chmod -R 775 storage
docker-compose exec php chown -R laravel:laravel storage
```

### Redis no conecta

```bash
# Verificar
docker-compose exec redis redis-cli ping

# Con contraseña (prod)
docker-compose -f docker-compose.prod.yml exec redis \
  redis-cli -a $REDIS_PASSWORD ping
```

---

## 📚 Referencias

- [Laravel Documentation](https://laravel.com/docs)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Kubernetes Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [OWASP Security](https://owasp.org/www-project-top-ten/)

---

## 📝 Checklist de Producción

Antes de ir a producción:

- [ ] Variables de entorno en `.env.docker.prod` configuradas
- [ ] Certificados SSL generados y en `./certs`
- [ ] Database backups configurados
- [ ] Health checks verificados (`/health/ready`)
- [ ] Logs centralizados en stderr
- [ ] Rate limiting activo en Nginx
- [ ] Security headers en Nginx
- [ ] Firewall configurado
- [ ] Database hardened (usuario con permisos limitados)
- [ ] Redis con contraseña fuerte
- [ ] Tests pasando (`vendor/bin/phpunit`)
- [ ] HTTPS obligatorio (redirect en Nginx)
- [ ] Monitoring y alertas activos

---

## 🤝 Contribuciones

1. Fork el proyecto
2. Crea una rama: `git checkout -b feature/amazing-feature`
3. Commit: `git commit -m 'Add amazing feature'`
4. Push: `git push origin feature/amazing-feature`
5. Open PR

**Nota**: Asegúrate de que los tests pasen:
```bash
docker-compose exec php vendor/bin/phpunit
docker-compose exec php vendor/bin/phpstan analyse
docker-compose exec php vendor/bin/phpcs
```

---

## 📄 License

MIT - Ver LICENSE para detalles.

---

## 🙏 Acknowledgments

- Laravel Framework
- Docker Community
- Monolog Logging Library
- Nginx Project

