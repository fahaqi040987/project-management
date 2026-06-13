# User Management Guide - DewaKoding Project Management

Complete guide for creating users, assigning roles, and managing permissions in the DewaKoding Project Management system.

## Table of Contents

- [System Overview](#system-overview)
- [User Roles & Permissions](#user-roles--permissions)
- [Creating New Users](#creating-new-users)
- [Assigning Roles & Permissions](#assigning-roles--permissions)
- [Managing Users via Admin Panel](#managing-users-via-admin-panel)
- [Command Reference](#command-reference)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

---

## System Overview

### Authentication & Authorization

The DewaKoding Project Management system uses:

- **Laravel 12** for user authentication
- **Filament Shield** for role-based access control (RBAC)
- **Spatie Laravel Permission** for permission management
- **Google OAuth** for optional social login

### Access Levels

1. **Super Admin** - Full system access
2. **Custom Roles** - Limited access based on permissions
3. **Project Members** - Access to specific projects only

---

## User Roles & Permissions

### Available Roles

#### 1. Super Admin
**Access Level:** Full system access

**Permissions (49 total):**
- ✅ All Project permissions (create, read, update, delete)
- ✅ All Ticket permissions (create, read, update, delete)  
- ✅ All User permissions (create, read, update, delete)
- ✅ All System permissions (settings, roles, notifications)
- ✅ Access to all admin resources
- ✅ Manage other users and roles

**Use Case:** System administrators, owners

#### 2. Project Manager (Custom Role)
**Access Level:** Project and ticket management

**Permissions (8 total):**
- ✅ view_any_project, view_project, create_project, update_project
- ✅ view_any_ticket, view_ticket, create_ticket, update_ticket
- ❌ Cannot delete projects/tickets
- ❌ Cannot manage users
- ❌ Cannot access system settings

**Use Case:** Team leads, project managers

#### 3. Regular User
**Access Level:** Basic access

**Permissions:**
- ✅ View assigned projects
- ✅ Update assigned tickets
- ❌ Cannot create projects
- ❌ Cannot manage other users

**Use Case:** Team members, developers

### Permission Structure

```
Super Admin (49 permissions)
├── Project Permissions (7)
│   ├── view_any_project
│   ├── view_project  
│   ├── create_project
│   ├── update_project
│   ├── delete_project
│   ├── restore_any_project
│   └── force_delete_any_project
├── Ticket Permissions (7)
│   ├── view_any_ticket
│   ├── view_ticket
│   ├── create_ticket
│   ├── update_ticket
│   ├── delete_ticket
│   ├── restore_any_ticket
│   └── force_delete_any_ticket
├── User Permissions (7)
│   ├── view_any_user
│   ├── view_user
│   ├── create_user
│   ├── update_user
│   ├── delete_user
│   ├── restore_any_user
│   └── force_delete_any_user
├── TicketComment Permissions (7)
├── TicketPriority Permissions (7)
├── Notification Permissions (7)
└── Role Permissions (7)
```

---

## Creating New Users

### Method 1: Artisan Command (Recommended)

**Prerequisites:** Docker container running

```bash
# Basic usage with all parameters
docker exec laravel_app php artisan make:filament-user \
  --name="John Doe" \
  --email="john.doe@example.com" \
  --password="SecurePassword123"

# Interactive mode (will prompt for input)
docker exec laravel_app php artisan make:filament-user

# Silent mode (no output)
docker exec laravel_app php artisan make:filament-user \
  --name="Jane Doe" \
  --email="jane@example.com" \
  --password="SecurePassword123" \
  --silent
```

**Example:**
```bash
docker exec laravel_app php artisan make:filament-user \
  --name="Admin User" \
  --email="admin@example.com" \
  --password="password123"
```

**Output:**
```
   INFO  Success! admin@example.com may now log in at http://localhost:8000/admin/login.
```

### Method 2: Admin Panel Interface

**Prerequisites:** Admin login required

1. **Login to Admin Panel**
   - URL: `http://localhost:8000/admin/login`
   - Use existing admin credentials

2. **Navigate to Users Section**
   - Click "Users" in the sidebar
   - Click "Create User" button

3. **Fill User Information**
   - **Name:** Full name of the user
   - **Email:** Unique email address
   - **Password:** Minimum 8 characters
   - **Role:** Select appropriate role (optional)

4. **Save User**
   - Click "Save" button
   - User is created immediately

### Method 3: Tinker (Advanced)

**Use Case:** Bulk creation, custom logic

```bash
docker exec laravel_app php artisan tinker
```

**Single User Creation:**
```php
$user = \App\Models\User::create([
    'name' => 'John Doe',
    'email' => 'john@example.com',
    'password' => bcrypt('SecurePassword123')
]);

echo "User created: {$user->name} ({$user->email})";
```

**Bulk User Creation:**
```php
$users = [
    ['name' => 'Alice Smith', 'email' => 'alice@example.com', 'password' => 'password123'],
    ['name' => 'Bob Johnson', 'email' => 'bob@example.com', 'password' => 'password123'],
    ['name' => 'Carol White', 'email' => 'carol@example.com', 'password' => 'password123'],
];

foreach ($users as $userData) {
    \App\Models\User::firstOrCreate(
        ['email' => $userData['email']],
        [
            'name' => $userData['name'],
            'password' => bcrypt($userData['password'])
        ]
    );
}

echo "Created " . count($users) . " users";
```

---

## Assigning Roles & Permissions

### Assigning Super Admin Role

**Method 1: Using Tinker**
```bash
docker exec laravel_app php artisan tinker --execute="
\$user = \App\Models\User::where('email', 'user@example.com')->first();
\$user->assignRole('Super Admin');
echo 'Super Admin role assigned to ' . \$user->name;
"
```

**Method 2: Using Admin Panel**
1. Navigate to Users section
2. Find the user
3. Click "Edit"
4. Select "Super Admin" role
5. Save changes

### Assigning Custom Roles

**Using Tinker:**
```bash
docker exec laravel_app php artisan tinker --execute="
\$user = \App\Models\User::where('email', 'pm@example.com')->first();
\$projectManager = \Spatie\Permission\Models::Role::where('name', 'Project Manager')->first();
\$user->assignRole(\$projectManager);
echo 'Project Manager role assigned';
"
```

### Assigning Specific Permissions

**Direct Permission Assignment:**
```bash
docker exec laravel_app php artisan tinker --execute="
\$user = \App\Models\User::where('email', 'user@example.com')->first();

// Assign specific permissions
\$user->givePermissionTo([
    'create_project',
    'update_project',
    'create_ticket'
]);

echo 'Permissions assigned successfully';
"
```

### Checking User Permissions

**Via Tinker:**
```bash
docker exec laravel_app php artisan tinker --execute="
\$user = \App\Models\User::where('email', 'admin@example.com')->first();

echo 'User: ' . \$user->name;
echo PHP_EOL;
echo 'Roles: ' . \$user->roles->pluck('name')->implode(', ');
echo PHP_EOL;
echo 'Can create project: ' . (\$user->can('create_project') ? 'YES' : 'NO');
echo PHP_EOL;
echo 'Can delete user: ' . (\$user->can('delete_user') ? 'YES' : 'NO');
echo PHP_EOL;
echo 'Total permissions: ' . \$user->getAllPermissions()->count();
"
```

---

## Managing Users via Admin Panel

### User Management Interface

**Access:** Admin Panel → Users

**Features:**
- **List View:** See all users in table format
- **Create User:** Add new users
- **Edit User:** Modify user details and roles
- **Delete User:** Remove users (soft delete)
- **View User:** See user details and permissions

### User Actions

**1. View User Profile**
- Click on user name in the list
- View user details, roles, and permissions
- See user's activity and projects

**2. Edit User**
- Click "Edit" button
- Modify name, email, password
- Assign or remove roles
- Add or remove specific permissions
- Save changes

**3. Delete User**
- Click "Delete" button
- Confirm deletion (soft delete)
- User can be restored later

**4. Bulk Actions**
- Select multiple users
- Apply bulk actions (delete, export, etc.)

### Role Management

**Access:** Admin Panel → Shield → Roles

**Features:**
- Create custom roles
- Assign permissions to roles
- Edit existing roles
- View role permissions

---

## Command Reference

### User Management Commands

```bash
# Create Filament user
docker exec laravel_app php artisan make:filament-user

# List all users
docker exec laravel_app php artisan tinker --execute="
\App\Models\User::all()->each(function(\$user) {
    echo \$user->name . ' (' . \$user->email . ') - Role: ' . \$user->roles->pluck('name')->implode(', ') . PHP_EOL;
});
"

# Assign Super Admin role
docker exec laravel_app php artisan tinker --execute="
\$user = \App\Models\User::where('email', 'user@example.com')->first();
\$user->assignRole('Super Admin');
"

# Remove user role
docker exec laravel_app php artisan tinker --execute="
\$user = \App\Models\User::where('email', 'user@example.com')->first();
\$user->removeRole('Super Admin');
"

# Delete user
docker exec laravel_app php artisan tinker --execute="
\$user = \App\Models\User::where('email', 'user@example.com')->first();
\$user->delete();
"
```

### Role & Permission Commands

```bash
# Generate all permissions
docker exec laravel_app php artisan shield:generate

# Create custom role
docker exec laravel_app php artisan tinker --execute="
\Spatie\Permission\Models\Role::create(['name' => 'Custom Role', 'guard_name' => 'web']);
"

# List all roles
docker exec laravel_app php artisan tinker --execute="
\Spatie\Permission\Models\Role::all()->each(function(\$role) {
    echo \$role->name . ' (' . \$role->permissions->count() . ' permissions)' . PHP_EOL;
});
"

# List all permissions
docker exec laravel_app php artisan tinker --execute="
echo 'Total Permissions: ' . \Spatie\Permission\Models\Permission::count() . PHP_EOL;
\Spatie\Permission\Models\Permission::all()->each(function(\$perm) {
    echo \$perm->name . PHP_EOL;
});
"
```

---

## Best Practices

### User Creation

**1. Use Strong Passwords**
```bash
# Minimum 8 characters with complexity
--password="SecurePass123!@#"
```

**2. Use Professional Email Format**
```bash
--email="john.doe@company.com"  # ✅ Good
--email="john123@gmail.com"     # ⚠️ Acceptable
--email="admin"                  # ❌ Invalid
```

**3. Use Descriptive Names**
```bash
--name="John Doe"           # ✅ Good
--name="John D."            # ⚠️ Acceptable  
--name="admin123"           # ❌ Unprofessional
```

### Role Assignment

**1. Principle of Least Privilege**
- Assign minimum required permissions
- Use custom roles instead of Super Admin when possible
- Regularly review user access

**2. Role Hierarchy Guidelines**
```
Super Admin         → 1-2 users maximum
Project Manager     → As needed per team
Regular User        → All team members
```

**3. Permission Assignment Best Practices**
- Use roles instead of direct permissions
- Create custom roles for specific job functions
- Document permission assignments

### Security Practices

**1. Regular Access Reviews**
```bash
# Review users with Super Admin role
docker exec laravel_app php artisan tinker --execute="
\$superAdmins = \App\Models\User::role('Super Admin')->get();
echo 'Super Admin Users (' . \$superAdmins->count() . '):' . PHP_EOL;
\$superAdmins->each(function(\$user) {
    echo '  - ' . \$user->name . ' (' . \$user->email . ')' . PHP_EOL;
});
"
```

**2. Password Updates**
- Force password changes for new users
- Implement password rotation policy
- Use secure password storage (already implemented)

**3. User Deactivation**
- Soft delete instead of hard delete
- Revoke access when users leave
- Keep audit trail of user changes

---

## Troubleshooting

### Common Issues

#### Issue 1: User Cannot Login After Creation

**Symptoms:** User created but cannot access admin panel

**Diagnosis:**
```bash
docker exec laravel_app php artisan tinker --execute="
\$user = \App\Models\User::where('email', 'user@example.com')->first();
if (\$user) {
    echo 'User exists: ' . \$user->name;
    echo PHP_EOL;
    echo 'Has role: ' . (\$user->roles->count() > 0 ? 'YES' : 'NO');
    echo PHP_EOL;
    echo 'Has permissions: ' . (\$user->getAllPermissions()->count() > 0 ? 'YES' : 'NO');
} else {
    echo 'User does not exist';
}
"
```

**Solutions:**
1. Check if user has a role assigned
2. Verify user email is correct
3. Reset user password if needed
4. Clear cache: `docker exec laravel_app php artisan config:clear`

#### Issue 2: Permission Denied Error

**Symptoms:** User gets "403 Forbidden" error

**Diagnosis:**
```bash
docker exec laravel_app php artisan tinker --execute="
\$user = \App\Models\User::where('email', 'user@example.com')->first();
echo 'Total permissions: ' . \$user->getAllPermissions()->count();
echo PHP_EOL;
echo 'Can create project: ' . (\$user->can('create_project') ? 'YES' : 'NO');
"
```

**Solutions:**
1. Assign appropriate role to user
2. Check if permissions are generated
3. Verify user is not blocked/banned
4. Clear application cache

#### Issue 3: User Creation Fails

**Symptoms:** Error when creating user

**Common Causes:**
- Email already exists
- Invalid email format
- Password too short (minimum 8 characters)
- Database connection issues

**Solutions:**
```bash
# Check if email exists
docker exec laravel_app php artisan tinker --execute="
\$exists = \App\Models\User::where('email', 'user@example.com')->exists();
echo 'Email exists: ' . (\$exists ? 'YES' : 'NO');
"

# Validate email format
docker exec laravel_app php artisan tinker --execute="
\$email = 'user@example.com';
\$valid = filter_var(\$email, FILTER_VALIDATE_EMAIL);
echo 'Email valid: ' . (\$valid !== false ? 'YES' : 'NO');
"
```

#### Issue 4: Role Not Working

**Symptoms:** Role assigned but permissions not working

**Solutions:**
```bash
# Clear all caches
docker exec laravel_app php artisan config:clear
docker exec laravel_app php artisan cache:clear
docker exec laravel_app php artisan view:clear

# Regenerate permissions
docker exec laravel_app php artisan shield:generate

# Verify role has permissions
docker exec laravel_app php artisan tinker --execute="
\$role = \Spatie\Permission\Models\Role::where('name', 'Super Admin')->first();
echo 'Role permissions count: ' . \$role->permissions->count();
"
```

### Error Messages Reference

**Error:** "User already exists"
- Solution: Use different email or update existing user

**Error:** "Password must be at least 8 characters"
- Solution: Use longer password

**Error:** "403 Forbidden"
- Solution: Assign appropriate role/permissions

**Error:** "Role not found"
- Solution: Create role first or use existing role

---

## Quick Reference Cards

### Create Super Admin
```bash
docker exec laravel_app php artisan make:filament-user \
  --name="Admin Name" \
  --email="admin@example.com" \
  --password="SecurePassword123"

docker exec laravel_app php artisan tinker --execute="
\$user = \App\Models\User::where('email', 'admin@example.com')->first();
\$user->assignRole('Super Admin');
"
```

### Create Project Manager
```bash
docker exec laravel_app php artisan make:filament-user \
  --name="PM Name" \
  --email="pm@example.com" \
  --password="SecurePassword123"

docker exec laravel_app php artisan tinker --execute="
\$user = \App\Models\User::where('email', 'pm@example.com')->first();
\$user->assignRole('Project Manager');
"
```

### Check User Status
```bash
docker exec laravel_app php artisan tinker --execute="
\$user = \App\Models\User::where('email', 'user@example.com')->first();
echo 'User: ' . \$user->name;
echo PHP_EOL;
echo 'Roles: ' . \$user->roles->pluck('name')->implode(', ');
echo PHP_EOL;
echo 'Permissions: ' . \$user->getAllPermissions()->count();
"
```

### List All Admins
```bash
docker exec laravel_app php artisan tinker --execute="
\$admins = \App\Models\User::role('Super Admin')->get();
echo 'Super Admins (' . \$admins->count() . '):' . PHP_EOL;
\$admins->each(function(\$admin) {
    echo '  - ' . \$admin->name . ' (' . \$admin->email . ')' . PHP_EOL;
});
"
```

---

## FAQ

**Q: What is the minimum password length?**
A: 8 characters. Recommended: Use uppercase, lowercase, numbers, and symbols.

**Q: Can a user have multiple roles?**
A: Yes, users can have multiple roles. Permissions from all roles are combined.

**Q: How do I remove a user's access?**
A: Either remove their role, soft delete the user, or hard delete them.

**Q: What happens when I delete a user?**
A: Users are soft deleted by default. Their data is preserved but they cannot login.

**Q: Can I create users without roles?**
A: Yes, but they won't have access to admin features until a role is assigned.

**Q: How many Super Admins should I have?**
A: Recommended: 1-2 maximum. Use custom roles for other users.

**Q: Can I customize user permissions?**
A: Yes, you can create custom roles with specific permission sets.

**Q: What if a user forgets their password?**
A: Admin can reset password via Admin Panel → Users → Edit User.

---

## Support & Additional Resources

**Documentation:**
- Laravel Documentation: https://laravel.com/docs
- Filament Documentation: https://filamentphp.com/docs
- Spatie Permission: https://spatie.be/docs/laravel-permission

**System Information:**
- PHP Version: 8.3+
- Laravel Version: 12
- Filament Version: 4.x
- Database: MariaDB 11

**For issues or questions, contact your system administrator.**

---

*Last Updated: 2025-06-13*
*Document Version: 1.0*