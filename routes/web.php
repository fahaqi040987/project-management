<?php

use Illuminate\Support\Facades\Route;
use App\Livewire\ExternalLogin;
use App\Livewire\ExternalDashboard;
use App\Http\Controllers\Auth\GoogleController;
use App\Livewire\SubmitTicket;

Route::get('/', function () {
    return view('welcome');
});

// Public Ticket Submission Route
Route::get('/submit-ticket', SubmitTicket::class)->name('submit-ticket');

// Google Authentication Routes
Route::get('auth/google', [GoogleController::class, 'redirectToGoogle'])->name('auth.google');
Route::get('auth/google/callback', [GoogleController::class, 'handleGoogleCallback'])->name('auth.google.callback');

// External Dashboard Routes
Route::prefix('external')->name('external.')->group(function () {
    Route::get('/{token}', ExternalLogin::class)->name('login');
    Route::get('/{token}/dashboard', ExternalDashboard::class)->name('dashboard');
});
