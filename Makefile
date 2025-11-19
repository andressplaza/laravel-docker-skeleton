install:
	docker compose run --rm php composer create-project laravel/laravel /var/www/html "$(version)"

up:
	docker compose up -d

down:
	docker compose down -v

bash:
	docker compose exec php bash

phpstan:
	docker compose exec php vendor/bin/phpstan analyse

phpcbf:
	docker compose exec php vendor/bin/phpcbf

phpunit:
	docker compose exec php vendor/bin/phpunit

