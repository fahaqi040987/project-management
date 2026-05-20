<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Carbon\Carbon;

class Project extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'description',
        'ticket_prefix',
        'color',
        'start_date',
        'end_date',
        'pinned_date',
    ];

    protected $casts = [
        'start_date' => 'date',
        'end_date' => 'date',
        'pinned_date' => 'datetime',
    ];

    public function getIsPinnedAttribute(): bool
    {
        return !is_null($this->pinned_date);
    }

    public function pin(): void
    {
        $this->update(['pinned_date' => now()]);
    }

    public function unpin(): void
    {
        $this->update(['pinned_date' => null]);
    }

    public function ticketStatuses(): HasMany
    {
        return $this->hasMany(TicketStatus::class);
    }

    public function tickets(): HasMany
    {
        return $this->hasMany(Ticket::class);
    }

    public function members(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'project_members')
            ->withTimestamps();
    }

    public function users(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'project_members')
            ->withTimestamps();
    }

    public function epics(): HasMany
    {
        return $this->hasMany(Epic::class);
    }

    public function ticketCategories(): HasMany
    {
        return $this->hasMany(TicketCategory::class);
    }

    public function notes(): HasMany
    {
        return $this->hasMany(ProjectNote::class);
    }

    public function getRemainingDaysAttribute()
    {
        if (!$this->end_date) {
            return null;
        }

        $today = Carbon::today();
        $endDate = Carbon::parse($this->end_date);

        if ($today->gt($endDate)) {
            return 0;
        }

        return $today->diffInDays($endDate);
    }
    
    public function getProgressPercentageAttribute(): float
    {
        $totalTickets = $this->tickets()->count();
        
        if ($totalTickets === 0) {
            return 0.0;
        }
        
        $completedTickets = $this->tickets()
            ->whereHas('status', function ($query) {
                $query->where('is_completed', true);
            })
            ->count();
        
        return round(($completedTickets / $totalTickets) * 100, 1);
    }
    
    public function externalAccess(): HasOne
    {
        return $this->hasOne(ExternalAccess::class);
    }
    
    public function generateExternalAccess()
    {
        $this->externalAccess()?->delete();
    
        return ExternalAccess::generateForProject($this->id);
    }
}
