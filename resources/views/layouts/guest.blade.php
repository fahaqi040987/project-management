<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="csrf-token" content="{{ csrf_token() }}">

    <title>{{ $title ?? 'Submit Ticket' }}</title>

    <!-- Fonts -->
    <link rel="preconnect" href="https://fonts.bunny.net">
    <link href="https://fonts.bunny.net/css?family=inter:400,500,600&display=swap" rel="stylesheet" />

    <!-- Tailwind CSS -->
    <script src="https://cdn.tailwindcss.com"></script>

    <!-- Filament Styles -->
    @filamentStyles
    @livewireStyles

    <style>
        body {
            font-family: 'Inter', sans-serif;
            background-color: #f3f4f6;
        }
        /* Custom Filament overrides for public page */
        .fi-main { padding: 0 !important; }
    </style>
</head>
<body class="antialiased text-gray-900">
    <div class="min-h-screen flex flex-col items-center pt-6 sm:pt-12 bg-gray-50">
        <div class="w-full sm:max-w-3xl mt-6 px-6 py-8 bg-white shadow-md overflow-hidden sm:rounded-lg">
            
            <div class="mb-8 text-center">
                <h1 class="text-3xl font-bold text-gray-900 mb-2">Submit a Ticket</h1>
                <p class="text-gray-600">Need help or want to request a feature? Fill out the form below.</p>
            </div>

            {{ $slot }}
            
        </div>
        
        <div class="mt-8 text-center text-sm text-gray-500 pb-12">
            <a href="/" class="hover:text-blue-600 transition-colors">&larr; Back to Home</a>
        </div>
    </div>

    @filamentScripts
    @livewireScripts
</body>
</html>
