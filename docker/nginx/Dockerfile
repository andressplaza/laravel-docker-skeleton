# ================================
# NGINX Base Image
# ================================
FROM nginx:alpine

ARG ENV=development

LABEL maintainer="Laravel Docker Skeleton"
LABEL environment="${ENV}"

# ================================
# Copiar configuración según entorno
# ================================
COPY default.conf /etc/nginx/conf.d/default.conf

# Copiar configuración de producción si existe
RUN if [ "$ENV" = "production" ] && [ -f "default.conf.prod" ]; then \
        cp /etc/nginx/conf.d/default.conf.prod /etc/nginx/conf.d/default.conf; \
    fi

# ================================
# Health Check
# ================================
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/health || exit 1

# ================================
# Exposar puertos
# ================================
EXPOSE 80 443

