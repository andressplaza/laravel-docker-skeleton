<?php

use App\Http\Controllers\HealthController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// ================================
// Health Check Endpoints
// ================================
Route::prefix('health')->group(function () {
    // Liveness probe - simple ping
    Route::get('/live', [HealthController::class, 'live'])
        ->name('health.live');

    // Readiness probe - dependencies check
    Route::get('/ready', [HealthController::class, 'ready'])
        ->name('health.ready');

    // Startup probe - initialization check
    Route::get('/startup', [HealthController::class, 'startup'])
        ->name('health.startup');

    // Detailed health report (requires authorization)
    Route::get('/report', [HealthController::class, 'report'])
        ->name('health.report');
});
