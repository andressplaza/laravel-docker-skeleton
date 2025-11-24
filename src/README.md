# Laravel Application - Configuración Docker Production-Ready

> Aplicación Laravel 12 con Docker, optimizada para desarrollo y producción

## 📋 Tabla de Contenidos

- [Características](#características)
- [Variables de Entorno](#variables-de-entorno)
- [Health Checks](#health-checks)
- [Logging](#logging)
- [Performance](#performance)
- [Seguridad](#seguridad)

---

## ✨ Características

### 🏗️ Arquitectura
- ✓ Multi-stage Docker builds (dev y prod)
- ✓ Separación clara de entornos
- ✓ Volúmenes nombrados en prod (persistencia)
- ✓ Bind mounts en dev (hot reload)

### 🩺 Observabilidad
- ✓ 4 tipos de health checks (live, ready, startup, report)
- ✓ Logging JSON estructurado
- ✓ Métricas de resource usage
- ✓ Stack traces completos

### ⚡ Performance
- ✓ OPCache habilitado en prod (+30-50%)
- ✓ PHP 8.3-FPM optimizado
- ✓ Redis para cache/sessions
- ✓ Nginx con gzip compression

### 🔒 Seguridad
- ✓ Usuario no-root en PHP
- ✓ HTTPS con HSTS
- ✓ Security headers en Nginx
- ✓ Rate limiting en API
- ✓ Credenciales separadas por entorno

---

## 🔧 Variables de Entorno

### Archivo: `.env.docker` (Desarrollo)

```bash
APP_NAME="Laravel Docker Skeleton"
APP_ENV=local
APP_DEBUG=true
APP_KEY=base64:V0bnEDRjzEd/FZr/dCnL+eBuKfBCNVA1BF3H9aXNq0I=

DB_CONNECTION=pgsql
DB_HOST=postgres
DB_PORT=5432
DB_DATABASE=laravel
DB_USERNAME=laravel
DB_PASSWORD=dev_password_only_for_local_dev

REDIS_HOST=redis
REDIS_PASSWORD=dev_redis_password_only_for_local
REDIS_PORT=6379

SESSION_DRIVER=cookie
QUEUE_CONNECTION=redis
CACHE_STORE=redis
MAIL_MAILER=log

LOG_CHANNEL=stack
LOG_STACK=json,single
LOG_LEVEL=debug
```

### Archivo: `.env.docker.prod` (Producción)

```bash
APP_ENV=production
APP_DEBUG=false
APP_KEY=${APP_KEY}  # Desde CI/CD secrets

DB_CONNECTION=pgsql
DB_HOST=postgres
DB_DATABASE=laravel_prod
DB_USERNAME=laravel_prod_user
DB_PASSWORD=${POSTGRES_PASSWORD}  # Docker secret

REDIS_PASSWORD=${REDIS_PASSWORD}  # Docker secret

SESSION_DRIVER=cookie
QUEUE_CONNECTION=redis
CACHE_STORE=redis

LOG_CHANNEL=json_stderr  # Solo stderr para Docker
LOG_LEVEL=warning
```

---

## 🩺 Health Checks

### Implementación

Ubicación: `app/Http/Controllers/HealthController.php`

Rutas registradas en: `routes/web.php`

### Endpoints

#### 1. Liveness Probe
```bash
GET /health/live

Response: 200 OK
Body: "healthy\n"
```
**Uso**: ¿Está el contenedor vivo?

#### 2. Readiness Probe
```bash
GET /health/ready

Response: 200 OK (si todo está listo)
Response: 503 Service Unavailable (si falla algo)

Body: {
  "status": "ready",
  "checks": {
    "database": {"status": "ok"},
    "redis": {"status": "ok"},
    "cache": {"status": "ok"}
  }
}
```
**Uso**: ¿Puedo enviar tráfico?

#### 3. Startup Probe
```bash
GET /health/startup

Response: 200 OK
```
**Uso**: ¿Completó la inicialización?

#### 4. Detailed Report (con autorización)
```bash
GET /health/report
Headers: X-Health-Token: your_token

Response: {
  "app": {
    "name": "Laravel Docker Skeleton",
    "environment": "production",
    "debug": false,
    "version": "1.0.0"
  },
  "checks": {
    "database": {
      "status": "ok",
      "query_time_ms": 2.5
    },
    "redis": {"status": "ok"},
    "cache": {"status": "ok"},
    "disk_space": {
      "status": "ok",
      "total_gb": 100,
      "free_gb": 45.2,
      "used_percent": 54.8
    }
  },
  "uptime": {...},
  "timestamp": "2025-11-24T10:30:00+00:00"
}
```
**Uso**: Monitoreo detallado y debugging

---

## 📊 Logging

### Canales Configurados

En `config/logging.php`:

#### 1. **json** (Archivo + Producción)
- **Destino**: `storage/logs/laravel.log`
- **Formato**: JSON estructurado
- **Rotación**: Diaria (14 días)
- **Procesadores**: ProcessIdProcessor, UidProcessor

#### 2. **json_stderr** (Docker)
- **Destino**: stderr (capturado por Docker)
- **Formato**: JSON con context
- **Uso**: Producción con docker-compose
- **Ventaja**: Logs centralizados automáticamente

### Registrar Logs en Código

```php
use Illuminate\Support\Facades\Log;

// Info simple
Log::info('User logged in', ['user_id' => 123]);

// Con contexto completo
Log::channel('json')->info('API request', [
    'endpoint' => '/api/users',
    'method' => 'GET',
    'duration_ms' => 45,
]);

// Errores con exception
Log::error('Database failure', [
    'exception' => $e,
    'query' => $sql,
]);

// Debug con stack trace
try {
    something();
} catch (Exception $e) {
    Log::debug('Debug info', ['backtrace' => $e->getTrace()]);
}
```

### Formato de Log en JSON

```json
{
  "message": "User logged in",
  "context": {
    "user_id": 123
  },
  "level": 200,
  "level_name": "INFO",
  "channel": "production",
  "datetime": {
    "date": "2025-11-24T10:30:45.123456Z",
    "timezone_type": 3,
    "timezone": "UTC"
  },
  "extra": {
    "process_id": 12345,
    "uid": "a1b2c3d4"
  }
}
```

---

## ⚡ Performance

### PHP OPCache (Producción)

Configurado en `docker/php/custom.production.ini`:

```ini
opcache.enable = 1
opcache.enable_cli = 0
opcache.validate_timestamps = 0
opcache.memory_consumption = 256M
opcache.max_accelerated_files = 4000
opcache.fast_shutdown = 1
```

**Impacto**: +30-50% de performance
**Hit rate**: ~99% en estado estable

### Nginx Caching

En `docker/nginx/default.conf.prod`:

```nginx
# Assets estáticos (imágenes, JS, CSS)
location ~* \.(js|css|png|jpg|gif)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
    add_header ETag $file_mtime;
}

# Gzip compression
gzip on;
gzip_types text/plain text/css application/json application/javascript;
gzip_min_length 1000;
```

### Redis para Sessions

En `.env`:

```bash
SESSION_DRIVER=cookie   # En memoria, distribuible
CACHE_STORE=redis       # Cache rápido
QUEUE_CONNECTION=redis  # Jobs distribuidos
```

**Ventajas**:
- Sessions compartidas (load balancing)
- Caché muy rápido (in-memory)
- Persistencia con AOF

---

## 🔒 Seguridad

### 1. Protección de Credenciales

✅ **Implementado**:

```bash
# .env nunca commitear
.env
.env.*.local
.env.docker
.env.docker.prod

# .env.example como referencia (SIN valores reales)
.env.example

# .env.docker.example como template
.env.docker.example
```

**En CI/CD**: Inyectar secretos como variables de entorno

### 2. HTTPS en Producción

En `docker/nginx/default.conf.prod`:

```nginx
# Redirect HTTP → HTTPS
server {
    listen 80;
    return 301 https://$host$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2;
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
}
```

### 3. Security Headers

```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```

### 4. CSRF Protection (Automático)

Laravel genera tokens automáticamente:

```blade
<form method="POST" action="/users">
    @csrf
    <!-- Token incluido -->
</form>
```

### 5. SQL Injection Prevention

```php
// ✓ Seguro - Eloquent
User::where('email', $email)->first();

// ✓ Seguro - Raw queries con bindings
DB::select('SELECT * FROM users WHERE email = ?', [$email]);

// ❌ Vulnerable - Interpolación directa
DB::select("SELECT * FROM users WHERE email = '$email'");
```

### 6. XSS Prevention

```blade
{{-- ✓ Seguro - Escapa HTML --}}
{{ $user->name }}

{{-- ❌ Vulnerable - No escapa --}}
{!! $user->name !!}

{{-- ✓ Seguro - Blade components --}}
<x-user-card :name="$user->name" />
```

### 7. Rate Limiting

En `routes/web.php`:

```php
// Throttle: 60 requests por minuto
Route::middleware('throttle:60,1')->group(function () {
    Route::post('/api/users', [UserController::class, 'store']);
});

// Custom: 5 requests por hora para login
Route::post('/login', [AuthController::class, 'login'])
    ->middleware('throttle:5,60');
```

Nginx también protege (prod):

```nginx
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
location ~ ^/api/ {
    limit_req zone=api burst=20 nodelay;
}
```

---

## 📂 Estructura de Directorios

```
src/
├── app/
│   ├── Http/
│   │   ├── Controllers/
│   │   │   ├── HealthController.php      ← NEW: Health checks
│   │   │   └── Controller.php
│   │   └── Middleware/
│   ├── Models/
│   │   └── User.php
│   ├── Providers/
│   │   ├── AppServiceProvider.php
│   │   └── LoggingServiceProvider.php    ← NEW: JSON logging
│   └── ...
├── bootstrap/
│   ├── app.php
│   ├── providers.php                     # Registra LoggingServiceProvider
│   └── cache/
├── config/
│   ├── app.php
│   ├── auth.php
│   ├── logging.php                       # MODIFIED: JSON channels
│   ├── database.php
│   └── ...
├── database/
│   ├── migrations/
│   ├── factories/
│   └── seeders/
├── routes/
│   ├── web.php                           # MODIFIED: Health routes
│   ├── api.php
│   └── console.php
├── storage/
│   ├── logs/                             # Logs JSON
│   ├── app/
│   │   ├── private/
│   │   └── public/
│   └── framework/
│       ├── cache/
│       ├── sessions/
│       └── views/
├── tests/
│   ├── Feature/
│   ├── Unit/
│   └── TestCase.php
└── vendor/
```

---

## 🧪 Testing

### Ejecutar Tests

```bash
# Desarrollo
docker-compose exec php vendor/bin/phpunit

# Con cobertura
docker-compose exec php vendor/bin/phpunit --coverage-html=coverage

# Producción
docker-compose -f docker-compose.prod.yml exec php vendor/bin/phpunit
```

### Health Check Tests

```php
// tests/Feature/HealthTest.php
public function test_liveness_check()
{
    $response = $this->get('/health/live');
    $response->assertStatus(200);
}

public function test_readiness_check_db_down()
{
    // Mock DB failure
    $response = $this->get('/health/ready');
    $response->assertStatus(503);
}
```

---

## 🚀 Deployment

### Pre-deployment Checklist

- [ ] Tests pasando: `vendor/bin/phpunit`
- [ ] Code quality: `vendor/bin/phpstan analyse`
- [ ] Style: `vendor/bin/phpcs`
- [ ] Health check: `curl /health/ready` → 200
- [ ] Logs estructurados: Verificar formato JSON
- [ ] Variables de entorno: Setear en CI/CD secrets

### Deploy Steps

```bash
# 1. Build images
docker build -f docker/php/Dockerfile --build-arg ENV=production \
  -t myapp/php:1.0.0 .

# 2. Run migrations
docker-compose -f docker-compose.prod.yml exec php \
  php artisan migrate --force

# 3. Clear cache
docker-compose -f docker-compose.prod.yml exec php \
  php artisan cache:clear

# 4. Verify
curl https://yourdomain.com/health/ready
```

---

## 📚 Referencias

- [Laravel Docs](https://laravel.com/docs)
- [Docker Best Practices](https://docs.docker.com/develop/)
- [Kubernetes Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)


