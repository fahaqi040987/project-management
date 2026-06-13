# Testing Guide - DewaKoding Project Management

Complete testing guide for the DewaKoding Project Management system using Pest, Laravel, and Filament testing frameworks.

## Table of Contents

- [Testing Overview](#testing-overview)
- [Testing Setup](#testing-setup)
- [Running Tests](#running-tests)
- [Test Structure](#test-structure)
- [Writing Tests](#writing-tests)
- [Feature Testing](#feature-testing)
- [Unit Testing](#unit-testing)
- [Browser Testing](#browser-testing)
- [Testing Best Practices](#testing-best-practices)
- [Troubleshooting](#troubleshooting)

---

## Testing Overview

### Testing Stack

**DewaKoding Project Management uses:**

- **Pest** - Modern PHP testing framework
- **Laravel 12** - Application framework with built-in testing support
- **Filament Testing** - Admin panel testing utilities
- **SQLite** - In-memory database for tests
- **Refresh Database** - Database reset between tests

### Test Types

```
tests/
├── Feature/          # Application feature tests
│   ├── Auth/         # Authentication tests
│   ├── Projects/     # Project management tests
│   ├── Tickets/      # Ticket management tests
│   └── Users/        # User management tests
├── Unit/             # Unit tests for individual components
│   ├── Models/       # Model tests
│   ├── Services/     # Service class tests
│   └── Helpers/      # Helper function tests
└── Pest.php          # Pest configuration file
```

### Test Statistics

- **Total Test Files:** 15+ files
- **Test Categories:** Feature, Unit, Browser
- **Coverage Areas:** Auth, Projects, Tickets, Users, API
- **Test Runtime:** ~2-5 minutes for full suite

---

## Testing Setup

### Prerequisites

**1. Docker Container Running:**
```bash
docker compose ps
```

**2. Application Environment:**
```bash
# Ensure testing environment is configured
docker exec laravel_app php artisan tinker --execute="
echo 'Environment: ' . app()->environment();
echo PHP_EOL;
echo 'Testing DB: ' . config('database.default');
"
```

### Initial Setup

**1. Install Testing Dependencies:**
```bash
docker exec laravel_app composer install --dev
```

**2. Configure Test Database:**
```bash
# Check phpunit.xml configuration
docker exec laravel_app cat /var/www/phpunit.xml | grep -A5 "env"
```

**3. Run Test Setup:**
```bash
docker exec laravel_app php artisan test --setup
```

---

## Running Tests

### Basic Test Commands

```bash
# Run all tests
docker exec laravel_app ./vendor/bin/pest

# Run specific test file
docker exec laravel_app ./vendor/bin/pest tests/Feature/ProjectTest.php

# Run specific test method
docker exec laravel_app ./vendor/bin/pest --filter=test_user_can_create_project

# Run with detailed output
docker exec laravel_app ./vendor/bin/pest --verbose

# Run with stop on failure
docker exec laravel_app ./vendor/bin/pest --stop-on-failure
```

### Test Execution Examples

**Run All Tests:**
```bash
docker exec laravel_app ./vendor/bin/pest
```

**Run Feature Tests Only:**
```bash
docker exec laravel_app ./vendor/bin/pest tests/Feature
```

**Run Unit Tests Only:**
```bash
docker exec laravel_app ./vendor/bin/pest tests/Unit
```

**Run Tests with Coverage:**
```bash
docker exec laravel_app ./vendor/bin/pest --coverage
```

**Parallel Test Execution:**
```bash
docker exec laravel_app ./vendor/bin/pest --parallel
```

---

## Test Structure

### Directory Structure

```
tests/
├── Feature/
│   ├── Auth/
│   │   ├── LoginTest.php
│   │   ├── RegistrationTest.php
│   │   └── GoogleAuthTest.php
│   ├── Projects/
│   │   ├── CreateProjectTest.php
│   │   ├── UpdateProjectTest.php
│   │   └── DeleteProjectTest.php
│   ├── Tickets/
│   │   ├── CreateTicketTest.php
│   │   ├── UpdateTicketTest.php
│   │   └── TicketAssignmentTest.php
│   └── Users/
│       ├── UserManagementTest.php
│       └── RoleAssignmentTest.php
├── Unit/
│   ├── Models/
│   │   ├── ProjectTest.php
│   │   ├── TicketTest.php
│   │   └── UserTest.php
│   └── Services/
│       ├── NotificationServiceTest.php
│       └── ProjectServiceTest.php
├── Pests.php          # Pest configuration
└── TestCase.php       # Base test class
```

### Test File Template

```php
<?php

use App\Models\User;
use Illuminate\Support\Facades\Auth;

// Test suite description
uses()->group('auth')->in('Feature/Auth');

beforeEach(function () {
    // Setup before each test
    $this->user = User::factory()->create();
});

afterEach(function () {
    // Cleanup after each test
    $this->user->delete();
});

it('can authenticate user', function () {
    // Test implementation
    expect(auth()->check())->toBeFalse();
    
    Auth::login($this->user);
    
    expect(auth()->check())->toBeTrue();
    expect(auth()->user()->id)->toBe($this->user->id);
});
```

---

## Writing Tests

### Basic Test Structure

**1. Test Description:**
```php
it('does something specific', function () {
    // Arrange
    $data = ['key' => 'value'];
    
    // Act
    $result = performAction($data);
    
    // Assert
    expect($result)->toBe('expected');
});
```

**2. Test with Data Providers:**
```php
test('validates email addresses', function ($email, $isValid) {
    $validator = Validator::make(['email' => $email], [
        'email' => 'required|email'
    ]);
    
    expect($validator->passes())->toBe($isValid);
})->with([
    ['user@example.com', true],
    ['invalid-email', false],
    ['user@', false],
]);
```

**3. Test with Factories:**
```php
it('creates project with valid data', function () {
    $user = User::factory()->create();
    $projectData = Project::factory()->raw();
    
    $project = $user->projects()->create($projectData);
    
    expect($project)->toBeInstanceOf(Project::class)
        ->and($project->name)->toBe($projectData['name']);
});
```

### Authentication Tests

**Login Test Example:**
```php
<?php

use App\Models\User;

test('user can login with valid credentials', function () {
    $user = User::factory()->create([
        'email' => 'test@example.com',
        'password' => bcrypt('password123')
    ]);
    
    $response = $this->post('/admin/login', [
        'email' => 'test@example.com',
        'password' => 'password123'
    ]);
    
    $response->assertStatus(302);
    $this->assertAuthenticated();
});
```

**Logout Test Example:**
```php
test('user can logout', function () {
    $user = User::factory()->create();
    
    $response = $this->actingAs($user)
        ->post('/admin/logout');
    
    $response->assertStatus(302);
    $this->assertGuest();
});
```

### Project Management Tests

**Create Project Test:**
```php
<?php

use App\Models\User;
use App\Models\Project;

test('authenticated user can create project', function () {
    $user = User::factory()->create();
    $user->assignRole('Super Admin');
    
    $projectData = [
        'name' => 'Test Project',
        'description' => 'Test Description',
        'prefix' => 'TEST'
    ];
    
    $response = $this->actingAs($user)
        ->post(route('projects.store'), $projectData);
    
    $response->assertStatus(302);
    
    $this->assertDatabaseHas('projects', [
        'name' => 'Test Project',
        'prefix' => 'TEST'
    ]);
});
```

**Update Project Test:**
```php
test('user can update their project', function () {
    $user = User::factory()->create();
    $project = Project::factory()->create();
    $project->members()->attach($user->id);
    
    $response = $this->actingAs($user)
        ->put(route('projects.update', $project), [
            'name' => 'Updated Project Name',
            'description' => 'Updated Description'
        ]);
    
    $response->assertStatus(302);
    
    expect($project->fresh()->name)->toBe('Updated Project Name');
});
```

### Ticket Management Tests

**Create Ticket Test:**
```php
<?php

use App\Models\User;
use App\Models\Project;
use App\Models\Ticket;

test('project member can create ticket', function () {
    $user = User::factory()->create();
    $project = Project::factory()->create();
    $project->members()->attach($user->id);
    $status = \App\Models\TicketStatus::factory()->create([
        'project_id' => $project->id
    ]);
    
    $ticketData = [
        'name' => 'Test Ticket',
        'description' => 'Test Description',
        'status_id' => $status->id
    ];
    
    $response = $this->actingAs($user)
        ->post(route('tickets.store', $project), $ticketData);
    
    $response->assertStatus(302);
    
    $this->assertDatabaseHas('tickets', [
        'name' => 'Test Ticket',
        'project_id' => $project->id
    ]);
});
```

**Ticket Assignment Test:**
```php
test('user can be assigned to ticket', function () {
    $user = User::factory()->create();
    $project = Project::factory()->create();
    $ticket = Ticket::factory()->create([
        'project_id' => $project->id
    ]);
    
    $response = $this->actingAs($project->owner)
        ->post(route('tickets.assign', $ticket), [
            'user_ids' => [$user->id]
        ]);
    
    $response->assertStatus(302);
    
    expect($ticket->users->contains($user))->toBeTrue();
});
```

---

## Feature Testing

### HTTP Request Testing

**GET Request Test:**
```php
test('user can view projects list', function () {
    $user = User::factory()->create();
    
    $response = $this->actingAs($user)
        ->get(route('projects.index'));
    
    $response->assertStatus(200)
        ->assertViewIs('projects.index')
        ->assertSee('Projects');
});
```

**POST Request Test:**
```php
test('user can store new project', function () {
    $user = User::factory()->create();
    
    $response = $this->actingAs($user)
        ->post(route('projects.store'), [
            'name' => 'New Project',
            'prefix' => 'NEW'
        ]);
    
    $response->assertRedirect(route('projects.index'));
});
```

**PUT Request Test:**
```php
test('user can update project', function () {
    $user = User::factory()->create();
    $project = Project::factory()->create(['user_id' => $user->id]);
    
    $response = $this->actingAs($user)
        ->put(route('projects.update', $project), [
            'name' => 'Updated Name'
        ]);
    
    $response->assertRedirect();
});
```

**DELETE Request Test:**
```php
test('user can delete project', function () {
    $user = User::factory()->create();
    $project = Project::factory()->create(['user_id' => $user->id]);
    
    $response = $this->actingAs($user)
        ->delete(route('projects.destroy', $project));
    
    $response->assertRedirect();
    $this->assertSoftDeleted('projects', ['id' => $project->id]);
});
```

### Authorization Testing

**Permission Check Test:**
```php
test('unauthorized user cannot access admin panel', function () {
    $user = User::factory()->create();
    
    $response = $this->actingAs($user)
        ->get('/admin');
    
    $response->assertStatus(403);
});
```

**Role-based Access Test:**
```php
test('super admin can access user management', function () {
    $superAdmin = User::factory()->create();
    $superAdmin->assignRole('Super Admin');
    
    $response = $this->actingAs($superAdmin)
        ->get(route('users.index'));
    
    $response->assertStatus(200);
});
```

### Database Testing

**Database Has Assertion:**
```php
test('creates project in database', function () {
    $user = User::factory()->create();
    
    $user->projects()->create([
        'name' => 'Test Project',
        'prefix' => 'TEST'
    ]);
    
    $this->assertDatabaseHas('projects', [
        'name' => 'Test Project'
    ]);
});
```

**Database Missing Assertion:**
```php
test('deletes project from database', function () {
    $project = Project::factory()->create();
    
    $project->delete();
    
    $this->assertDatabaseMissing('projects', [
        'id' => $project->id
    ]);
});
```

**Soft Delete Test:**
```php
test('soft deletes project', function () {
    $project = Project::factory()->create();
    
    $project->delete();
    
    $this->assertSoftDeleted('projects', [
        'id' => $project->id
    ]);
});
```

---

## Unit Testing

### Model Testing

**Model Relationships Test:**
```php
<?php

use App\Models\Project;
use App\Models\User;
use App\Models\Ticket;

test('project has many tickets', function () {
    $project = Project::factory()->create();
    $tickets = Ticket::factory()->count(3)->create([
        'project_id' => $project->id
    ]);
    
    expect($project->tickets)->toHaveCount(3);
    expect($project->tickets->first()->id)->toBe($tickets->first()->id);
});
```

**Model Attributes Test:**
```php
test('project fills attributes correctly', function () {
    $project = Project::factory()->create([
        'name' => 'Test Project',
        'prefix' => 'TEST'
    ]);
    
    expect($project->name)->toBe('Test Project');
    expect($project->prefix)->toBe('TEST');
});
```

**Model Scopes Test:**
```php
test('project scope filters by user', function () {
    $user = User::factory()->create();
    $userProject = Project::factory()->create(['user_id' => $user->id]);
    $otherProject = Project::factory()->create();
    
    $userProjects = Project::whereUserId($user->id)->get();
    
    expect($userProjects)->toHaveCount(1);
    expect($userProjects->first()->id)->toBe($userProject->id);
});
```

### Service Testing

**Notification Service Test:**
```php
<?php

use App\Services\NotificationService;
use App\Models\User;
use App\Models\Project;

test('sends project assignment notification', function () {
    $user = User::factory()->create();
    $project = Project::factory()->create();
    $service = new NotificationService();
    
    Notification::fake();
    
    $service->notifyProjectAssignment($user, $project);
    
    Notification::assertSentTo($user, ProjectAssignedNotification::class);
});
```

**Business Logic Test:**
```php
test('generates unique ticket identifier', function () {
    $project = Project::factory()->create(['prefix' => 'PROJ']);
    
    $ticket = Ticket::factory()->create([
        'project_id' => $project->id
    ]);
    
    expect($ticket->uuid)->toStartWith('PROJ-');
    expect(strlen($ticket->uuid))->toBeGreaterThan(8);
});
```

---

## Browser Testing

### Dusk Browser Tests

**Setup Dusk:**
```bash
docker exec laravel_app php artisan dusk:install
docker exec laravel_app php artisan dusk:make-dashboard-test
```

**Login Test Example:**
```php
<?php

use App\Models\User;

test('user can login via browser', function () {
    $user = User::factory()->create([
        'email' => 'test@example.com',
        'password' => bcrypt('password123')
    ]);
    
    $this->browse(function ($browser) use ($user) {
        $browser->visit('/admin/login')
            ->type('email', $user->email)
            ->type('password', 'password123')
            ->press('Login')
            ->assertPathIs('/admin')
            ->assertSee($user->name);
    });
});
```

**Project Creation Test:**
```php
test('user can create project via admin panel', function () {
    $user = User::factory()->create();
    $user->assignRole('Super Admin');
    
    $this->browse(function ($browser) use ($user) {
        $browser->loginAs($user)
            ->visit('/admin/projects/create')
            ->type('name', 'Browser Test Project')
            ->type('prefix', 'BTEST')
            ->press('Create')
            ->assertPathIs('/admin/projects')
            ->assertSee('Browser Test Project');
    });
});
```

---

## Testing Best Practices

### Test Organization

**1. Arrange-Act-Assert Pattern:**
```php
test('user can update project', function () {
    // Arrange
    $user = User::factory()->create();
    $project = Project::factory()->create(['user_id' => $user->id]);
    
    // Act
    $response = $this->actingAs($user)->put(route('projects.update', $project), [
        'name' => 'Updated Project'
    ]);
    
    // Assert
    $response->assertRedirect();
    expect($project->fresh()->name)->toBe('Updated Project');
});
```

**2. Descriptive Test Names:**
```php
// ❌ Bad
test('test1', function () {});

// ✅ Good
test('authenticated user can create project with valid data', function () {});
```

**3. Single Responsibility:**
```php
// ❌ Bad - testing multiple things
test('project management works', function () {
    $this->createProject();
    $this->updateProject();
    $this->deleteProject();
});

// ✅ Good - separate tests
test('user can create project', function () {});
test('user can update project', function () {});
test('user can delete project', function () {});
```

### Test Data Management

**1. Use Factories:**
```php
// ❌ Bad - manual creation
$user = new User();
$user->name = 'John Doe';
$user->email = 'john@example.com';
$user->password = bcrypt('password');
$user->save();

// ✅ Good - factory
$user = User::factory()->create();
```

**2. Use Data Providers:**
```php
test('validates project prefix format', function ($prefix, $isValid) {
    $response = $this->post(route('projects.store'), [
        'name' => 'Test Project',
        'prefix' => $prefix
    ]);
    
    $isValid 
        ? $response->assertSessionHasNoErrors()
        : $response->assertSessionHasErrors();
})->with([
    ['PROJ', true],
    ['proj', false],
    ['P1', false],
    ['PROJECT123', true],
]);
```

**3. Clean Up Test Data:**
```php
afterEach(function () {
    // Clean up database
    Database::rollback();
});
```

### Performance Optimization

**1. Use In-Memory Database:**
```php
// phpunit.xml
<env name="DB_CONNECTION" value="sqlite"/>
<env name="DB_DATABASE" value=":memory:"/>
```

**2. Run Tests in Parallel:**
```bash
docker exec laravel_app ./vendor/bin/pest --parallel
```

**3. Use RefreshDatabase Trait:**
```php
uses(App\Database\RefreshDatabase::class);

test('runs in clean database', function () {
    // Each test gets fresh database
});
```

### Mocking and Faking

**1. Fake External Services:**
```php
use Illuminate\Support\Facades\Notification;
use App\Notifications\ProjectAssignedNotification;

test('sends notification when user assigned to project', function () {
    Notification::fake();
    
    $user = User::factory()->create();
    $project = Project::factory()->create();
    
    $project->members()->attach($user->id);
    
    Notification::assertSentTo($user, ProjectAssignedNotification::class);
});
```

**2. Mock Time:**
```php
use Carbon\Carbon;
use Illuminate\Support\Facades\Date;

test('filters projects by creation date', function () {
    Date::setTestNow(Carbon::parse('2025-01-01'));
    
    $project = Project::factory()->create();
    
    expect($project->created_at->format('Y-m-d'))->toBe('2025-01-01');
});
```

---

## Troubleshooting

### Common Test Failures

#### Issue 1: Database Connection Error

**Symptoms:** Tests fail with database connection errors

**Solutions:**
```bash
# Check test database configuration
docker exec laravel_app cat /var/www/phpunit.xml | grep -A5 "DB_"

# Ensure migrations are run for test database
docker exec laravel_app php artisan migrate --env=testing

# Clear test cache
docker exec laravel_app php artisan cache:clear --env=testing
```

#### Issue 2: Factory Not Found

**Symptoms:** Error about missing factory

**Solutions:**
```bash
# Ensure factories are generated
docker exec laravel_app php artisan tinker --execute="
User::factory()->create();
echo 'Factory works';
"
```

#### Issue 3: Authentication Failures

**Symptoms:** Auth tests fail unexpectedly

**Solutions:**
```php
// Explicitly set authentication guard
test('user can access protected route', function () {
    $user = User::factory()->create();
    
    $this->actingAs($user, 'web')
        ->get('/admin')
        ->assertStatus(200);
});
```

#### Issue 4: Route Not Found

**Symptoms:** Tests fail with 404 errors

**Solutions:**
```bash
# Clear route cache
docker exec laravel_app php artisan route:clear

# Verify routes exist
docker exec laravel_app php artisan route:list | grep projects
```

### Debug Mode Testing

**Enable Detailed Errors:**
```bash
docker exec laravel_app ./vendor/bin/pest --verbose --debug
```

**Run Single Test with Debug:**
```bash
docker exec laravel_app ./vendor/bin/pest --filter=test_specific_name --fail-on-risky --show-warnings
```

### Test Performance Issues

**Slow Tests Diagnosis:**
```bash
# Run with timing
docker exec laravel_app ./vendor/bin/pest --profile

# Identify slow tests
docker exec laravel_app ./vendor/bin/pest --slowest-threshold=500
```

---

## Quick Reference

### Essential Commands

```bash
# Run all tests
docker exec laravel_app ./vendor/bin/pest

# Run specific test file
docker exec laravel_app ./vendor/bin/pest tests/Feature/ProjectTest.php

# Run specific test
docker exec laravel_app ./vendor/bin/pest --filter=test_name

# Run with coverage
docker exec laravel_app ./vendor/bin/pest --coverage

# Run in parallel
docker exec laravel_app ./vendor/bin/pest --parallel

# Stop on first failure
docker exec laravel_app ./vendor/bin/pest --stop-on-failure

# Verbose output
docker exec laravel_app ./vendor/bin/pest --verbose
```

### Test Templates

**Basic Feature Test:**
```php
<?php

use App\Models\User;

test('description here', function () {
    // Arrange
    $user = User::factory()->create();
    
    // Act
    $response = $this->actingAs($user)->get('/route');
    
    // Assert
    $response->assertStatus(200);
});
```

**Basic Unit Test:**
```php
<?php

use App\Models\Project;

test('description here', function () {
    $project = Project::factory()->create();
    
    expect($project->name)->toBeString();
    expect($project->prefix)->toHaveLength(4);
});
```

---

## Advanced Topics

### Test Parallelization

**Configure Parallel Testing:**
```bash
docker exec laravel_app ./vendor/bin/pest --parallel --processes=4
```

### Test Coverage

**Generate Coverage Report:**
```bash
docker exec laravel_app ./vendor/bin/pest --coverage --coverage-html=coverage
```

### Continuous Integration

**CI/CD Integration:**
```yaml
# .github/workflows/tests.yml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Tests
        run: docker exec laravel_app ./vendor/bin/pest
```

---

*Last Updated: 2025-06-13*
*Document Version: 1.0*