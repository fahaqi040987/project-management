<?php

namespace App\Filament\Pages;

use App\Models\Project;
use Filament\Pages\Page;
use Illuminate\Support\Facades\Auth;
use Carbon\Carbon;

class ProjectTimeline extends Page
{
    protected string $view = 'filament.pages.project-timeline';
    protected static ?string $navigationLabel = 'Project Timeline';
    protected static string | \BackedEnum | null $navigationIcon = 'heroicon-o-calendar-days';
    protected static string | \UnitEnum | null $navigationGroup = 'Project Management';
    protected static ?int $navigationSort = 3;
    protected static ?string $slug = 'project-timeline';
    
    public array $counts = [];
    public array $ganttData = ['data' => [], 'links' => []];
    
    public function mount(): void
    {
        $this->loadData();
    }
    
    public function loadData(): void
    {
        $this->counts = $this->getViewData();
        $this->ganttData = $this->getGanttData();
    }
    
    public function getProjects()
    {
        $query = Project::query()
            ->whereNotNull('start_date')
            ->whereNotNull('end_date')
            ->orderBy('start_date');
        
        $userIsSuperAdmin = auth()->user() && (
            (method_exists(auth()->user(), 'hasRole') && auth()->user()->hasRole('super_admin'))
            || (isset(auth()->user()->role) && auth()->user()->role === 'super_admin')
        );

        if (!$userIsSuperAdmin) {
            $query->whereHas('members', function ($query) {
                $query->where('users.id', auth()->id());
            });
        }
        
        return $query->get();
    }
    
    public function getGanttData(): array
    {
        $projects = $this->getProjects();
        
        if ($projects->isEmpty()) {
            return ['data' => [], 'links' => []];
        }
        
        $ganttTasks = [];
        
        foreach ($projects as $project) {
            $startDate = Carbon::parse($project->start_date);
            $endDate = Carbon::parse($project->end_date);
            $totalDays = $startDate->diffInDays($endDate) + 1;
            $pastDays = min($totalDays, max(0, $startDate->diffInDays(Carbon::now()) + 1));
            $progress = $totalDays > 0 ? min(1.0, $pastDays / $totalDays) : 0;
            
            // Determine status and color
            $now = Carbon::now();
            $isOverdue = $now->gt($endDate);
            $isNearDeadline = !$isOverdue && $now->diffInDays($endDate) <= 7;
            $isNearlyComplete = $progress >= 0.8;
            
            if ($isOverdue) {
                $status = 'Overdue';
                $color = '#ef4444';
            } elseif ($isNearlyComplete) {
                $status = 'Nearly Complete';
                $color = '#10b981';
            } elseif ($isNearDeadline) {
                $status = 'Approaching Deadline';
                $color = '#f59e0b';
            } else {
                $status = 'In Progress';
                $color = '#3b82f6';
            }
            
            $ganttTasks[] = [
                'id' => $project->id,
                'text' => $project->name,
                'start_date' => $startDate->format('d-m-Y H:i'),
                'end_date' => $endDate->format('d-m-Y H:i'),
                'duration' => $totalDays,
                'progress' => $progress,
                'status' => $status,
                'color' => $color,
                'is_overdue' => $isOverdue
            ];
        }
        
        return [
            'data' => $ganttTasks,
            'links' => []
        ];
    }
    
    public function getViewData(): array
    {
        $allQuery = Project::query()
            ->whereNotNull('start_date')
            ->whereNotNull('end_date');
        
        // Apply role-based filtering
        $userIsSuperAdmin = auth()->user() && (
            (method_exists(auth()->user(), 'hasRole') && auth()->user()->hasRole('super_admin'))
            || (isset(auth()->user()->role) && auth()->user()->role === 'super_admin')
        );

        if (!$userIsSuperAdmin) {
            $allQuery->whereHas('members', function ($query) {
                $query->where('users.id', auth()->id());
            });
        }
        
        return [
            'all' => $allQuery->count(),
        ];
    }
}