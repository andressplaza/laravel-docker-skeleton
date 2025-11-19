#!/bin/bash  
set -e  
  
echo "Copiando archivos de configuración..."  
cp .env.docker.example .env.docker  
cp src/.env.example src/.env  
  
echo "Iniciando servicios Docker..."  
docker compose up -d  
  
echo "Esperando a que los servicios estén listos..."  
sleep 10  
  
echo "Instalando dependencias de Laravel..."  
docker compose exec php composer install  
  
echo "Generando clave de aplicación..."  
docker compose exec php php artisan key:generate  
  
echo "Ejecutando migraciones..."  
docker compose exec php php artisan migrate  
  
echo "Compilando assets frontend..."  
cd src && npm install && npm run build && cd ..  
  
echo "¡Setup completado! Accede a http://localhost:8080"