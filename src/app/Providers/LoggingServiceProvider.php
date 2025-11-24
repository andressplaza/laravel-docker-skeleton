<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Facades\Log;
use Monolog\Formatter\JsonFormatter;
use Monolog\Processor\ProcessIdProcessor;
use Monolog\Processor\UidProcessor;

/**
 * Logging Service Provider
 *
 * Configura logging estructurado con JSON en producción
 * Complementa la configuración en config/logging.php
 */
class LoggingServiceProvider extends ServiceProvider
{
    /**
     * Register services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap services.
     */
    public function boot(): void
    {
        // En producción, usar JSON logging en stderr para Docker
        if (app()->environment('production')) {
            Log::setDefaultDriver('json_stderr');
        }
    }
}
