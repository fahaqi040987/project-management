# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DewaKoding Project Management — a Laravel 12 + Filament 4 application for project and ticket management with Kanban boards, timelines, epics, role-based access, and a client-facing external portal.

## Tech Stack

- PHP 8.2+, Laravel 12, Filament 4 (admin panel)
- Livewire 3 for dynamic components (external portal, comments)
- MySQL 8.0, Tailwind CSS 4.x, Vite 6
- Pest for testing, Laravel Pint for code styling
- Docker Compose for production (PHP-FPM, Nginx, MySQL, queue worker, Cloudflare Tunnel)

## Development Commands

```bash
# Initial setup
composer install && npm install
cp .env.example .env && php artisan key:generate
php artisan migrate

# Create an admin user
php artisan make:filament-user

# Run dev server (serves app, queue, logs, and Vite concurrently)
composer run dev

# Run Octane (FrankenPHP) instead of artisan serve
composer run octane-dev

# Frontend only
npm run dev      # watch
npm run build    # production build

# Code formatting
./vendor/bin/pint

# Tests
./vendor/bin/pest                    # all tests
./vendor/bin/pest --filter=TestName  # single test
./vendor/bin/pest tests/Feature      # feature tests only
./vendor/bin/pest tests/Unit         # unit tests only
```

## Architecture

### Admin Panel (Filament)

All admin UI lives in `app/Filament/`. The admin panel is mounted at `/admin`.

**Resources** (`app/Filament/Resources/`) — CRUD interfaces for: Projects, Tickets, Users, Roles, TicketPriorities, TicketComments, Notifications. Each resource has a `Pages/` directory with List/Create/Edit/View pages.

**Custom Pages** (`app/Filament/Pages/`):
- `ProjectBoard.php` — Kanban-style drag-and-drop board
- `ProjectTimeline.php`, `TicketTimeline.php` — Gantt/timeline views
- `Leaderboard.php`, `UserContributions.php` — performance tracking
- `EpicsOverview.php` — epic management
- `SystemSettings.php` — global settings

**Widgets** (`app/Filament/Widgets/`) — Dashboard stats, charts, recent activity.

**Actions** (`app/Filament/Actions/`) — Reusable import/export ticket actions (CSV via Maatwebsite Excel).

### Models & Relationships (`app/Models/`)

Core models: `Project`, `Ticket`, `User`, `Epic`, `TicketStatus`, `TicketPriority`, `TicketComment`, `TicketHistory`, `ExternalAccess`, `Notification`, `Setting`, `ProjectNote`.

Tickets use project-specific prefixes + random strings for identifiers (e.g., `PROJ-abc123`). Tickets have many-to-many user assignments via `ticket_users` pivot. Each project has its own set of custom `TicketStatus` and `TicketPriority` entries.

### Authorization

Filament Shield (`bezhansalleh/filament-shield`) provides role-based access. Policies in `app/Policies/` control resource-level access. Shield generates permissions per resource.

### Event System

`app/Events/` — `ProjectMemberAttached`, `ProjectMemberDetached`
`app/Listeners/` — Send email notifications on project assignment/removal via `NotificationService`.

### External Portal

Non-admin client access via `app/Livewire/ExternalDashboard.php` and `ExternalLogin.php`. Routes under `/external/{token}`. Projects generate `ExternalAccess` tokens with optional password protection for read-only client views.

### Routes (`routes/`)

- `web.php` — Google OAuth login, external portal routes. All admin routes handled by Filament.
- `console.php` — Artisan command registrations.

### Authentication

Google OAuth via Laravel Socialite (`app/Http/Controllers/Auth/GoogleController.php`). Standard credential login also supported.

## Key Patterns

- Ticket identifiers: generated as `{project_prefix}{random_string}` in `Ticket` model
- Ticket statuses are per-project, not global — each project defines its own workflow
- Ticket comments and histories track all changes for audit
- Notifications are stored in DB (`notifications` table) and optionally sent via email
- Settings are key-value pairs scoped to users (`Setting` model)
- External access tokens are auto-generated for each project with optional passwords

## Deployment

Docker Compose setup with services: app (PHP-FPM), nginx, db (MySQL), queue-worker, cloudflared, phpmyadmin. Entrypoint script at `docker/entrypoint.sh` runs migrations and caches config on startup. Production env template at `.env.production.example`. See `DEPLOY.md` for full deployment instructions.
