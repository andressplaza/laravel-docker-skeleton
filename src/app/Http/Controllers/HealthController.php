<?php

namespace App\Http\Controllers;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Redis;
use Illuminate\Support\Facades\Cache;
use Illuminate\Http\Response;

/**
 * Health Check Controller
 * 
 * Proporciona endpoints para verificar la salud de la aplicación
 * Usado por: Docker health checks, load balancers, monitoring systems
 */
class HealthController extends Controller
{
    /**
     * Liveness probe - ¿Está corriendo la aplicación?
     * 
     * @return \Illuminate\Http\Response
     */
    public function live(): Response
    {
        return response('OK', 200)
            ->header('Content-Type', 'text/plain');
    }

    /**
     * Readiness probe - ¿Está lista para recibir tráfico?
     * Verifica: Database, Redis, Storage
     * 
     * @return \Illuminate\Http\JsonResponse
     */
    public function ready()
    {
        $status = [
            'status' => 'ready',
            'checks' => [],
            'timestamp' => now()->toIso8601String(),
        ];

        // Database check
        try {
            DB::connection()->getPdo();
            $status['checks']['database'] = ['status' => 'ok'];
        } catch (\Exception $e) {
            $status['checks']['database'] = ['status' => 'error', 'message' => $e->getMessage()];
            return response()->json($status, 503); // Service Unavailable
        }

        // Redis check
        try {
            Redis::connection()->ping();
            $status['checks']['redis'] = ['status' => 'ok'];
        } catch (\Exception $e) {
            $status['checks']['redis'] = ['status' => 'warning', 'message' => $e->getMessage()];
            // No devuelve 503 porque Redis puede no ser crítico
        }

        // Cache check (uses Redis by default)
        try {
            Cache::put('health_check_' . time(), 'ok', 60);
            $status['checks']['cache'] = ['status' => 'ok'];
        } catch (\Exception $e) {
            $status['checks']['cache'] = ['status' => 'warning', 'message' => $e->getMessage()];
        }

        return response()->json($status, 200);
    }

    /**
     * Startup probe - ¿Completó la inicialización?
     * Verifica que la aplicación está lista después de un reinicio
     * 
     * @return \Illuminate\Http\JsonResponse
     */
    public function startup()
    {
        // Esta es más permisiva que readiness
        // En Kubernetes, se llama repetidamente durante el arranque
        $status = [
            'status' => 'starting_up',
            'app_name' => config('app.name'),
            'environment' => app()->environment(),
        ];

        return response()->json($status, 200);
    }

    /**
     * Detailed health report
     * Endpoint más verboso para monitoreo detallado
     * 
     * @return \Illuminate\Http\JsonResponse
     */
    public function report()
    {
        if (!$this->isAuthorized()) {
            return response()->json(['error' => 'Unauthorized'], 401);
        }

        $report = [
            'app' => [
                'name' => config('app.name'),
                'environment' => app()->environment(),
                'debug' => config('app.debug'),
                'version' => '1.0.0', // Cambiar según tu versión
            ],
            'checks' => [
                'database' => $this->checkDatabase(),
                'redis' => $this->checkRedis(),
                'cache' => $this->checkCache(),
                'disk_space' => $this->checkDiskSpace(),
            ],
            'uptime' => $this->getUptime(),
            'timestamp' => now()->toIso8601String(),
        ];

        return response()->json($report, 200);
    }

    /**
     * Verificar base de datos
     */
    private function checkDatabase(): array
    {
        try {
            DB::connection()->getPdo();
            $query_time = microtime(true);
            DB::select('SELECT 1');
            $query_time = (microtime(true) - $query_time) * 1000;

            return [
                'status' => 'ok',
                'query_time_ms' => round($query_time, 2),
            ];
        } catch (\Exception $e) {
            return [
                'status' => 'error',
                'message' => $e->getMessage(),
            ];
        }
    }

    /**
     * Verificar Redis
     */
    private function checkRedis(): array
    {
        try {
            Redis::connection()->ping();
            return ['status' => 'ok'];
        } catch (\Exception $e) {
            return [
                'status' => 'error',
                'message' => $e->getMessage(),
            ];
        }
    }

    /**
     * Verificar Cache
     */
    private function checkCache(): array
    {
        try {
            $key = 'health_check_' . uniqid();
            Cache::put($key, 'test', 60);
            $value = Cache::get($key);
            Cache::forget($key);

            if ($value === 'test') {
                return ['status' => 'ok'];
            }
            return ['status' => 'error', 'message' => 'Cache put/get mismatch'];
        } catch (\Exception $e) {
            return [
                'status' => 'error',
                'message' => $e->getMessage(),
            ];
        }
    }

    /**
     * Verificar espacio en disco
     */
    private function checkDiskSpace(): array
    {
        try {
            $path = storage_path();
            $total = disk_total_space($path);
            $free = disk_free_space($path);
            $used = $total - $free;
            $percent = ($used / $total) * 100;

            $status = 'ok';
            if ($percent > 90) {
                $status = 'error';
            } elseif ($percent > 75) {
                $status = 'warning';
            }

            return [
                'status' => $status,
                'total_gb' => round($total / (1024 ** 3), 2),
                'free_gb' => round($free / (1024 ** 3), 2),
                'used_percent' => round($percent, 2),
            ];
        } catch (\Exception $e) {
            return [
                'status' => 'error',
                'message' => $e->getMessage(),
            ];
        }
    }

    /**
     * Obtener uptime (simplificado)
     */
    private function getUptime(): array
    {
        // En un entorno real, podrías usar supervisord, systemd, o un archivo de estado
        return [
            'source' => 'container_restart',
            'seconds_since_start' => 'N/A in container',
        ];
    }

    /**
     * Verificar si está autorizado para ver el reporte detallado
     */
    private function isAuthorized(): bool
    {
        // En producción, usar headers o tokens
        $token = request()->header('X-Health-Token');
        $expected_token = config('services.health_token');

        return $token === $expected_token || app()->environment('local');
    }
}
