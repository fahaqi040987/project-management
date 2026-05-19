<?php

namespace App\Filament\Widgets;

use App\Models\User;
use Filament\Widgets\ChartWidget;
use BezhanSalleh\FilamentShield\Traits\HasWidgetShield;

class UserStatisticsChart extends ChartWidget
{
    use HasWidgetShield;

    public static function canView(): bool
    {
        $user = auth()->user();
        $isSuperAdmin = $user && (
            (method_exists($user, 'hasRole') && $user->hasRole('super_admin')) || 
            (isset($user->role) && $user->role === 'super_admin')
        );

        if ($isSuperAdmin) {
            return true;
        }

        return $user?->can('widget_' . class_basename(static::class)) ?? false;
    }
    
    protected ?string $heading = 'User Statistics Chart';
    
    protected int | string | array $columnSpan = [
        'md' => 2,
        'xl' => 1,
    ];
    
    protected static ?int $sort = 3;
    
    protected ?string $maxHeight = '300px';
    
    protected ?string $pollingInterval = '30s';
    
    protected function getData(): array
    {
        $users = User::query()
            ->when(!auth()->user()->hasRole('super_admin'), function ($query) {
                $query->where('id', auth()->id());
            })
            ->withCount([
                'projects as total_projects',
                'assignedTickets as total_assigned_tickets'
            ])
            ->orderBy('name')
            ->get();
        
        $labels = $users->pluck('name')->toArray();
        $projectsData = $users->pluck('total_projects')->toArray();
        $ticketsData = $users->pluck('total_assigned_tickets')->toArray();
        
        return [
            'datasets' => [
                [
                    'label' => 'Total Projects',
                    'data' => $projectsData,
                    'backgroundColor' => '#3B82F6',
                    'borderColor' => '#3B82F6',
                    'borderWidth' => 1,
                ],
                [
                    'label' => 'Total Assigned Tickets',
                    'data' => $ticketsData,
                    'backgroundColor' => '#10B981',
                    'borderColor' => '#10B981',
                    'borderWidth' => 1,
                ],
            ],
            'labels' => $labels,
        ];
    }
    
    protected function getType(): string
    {
        return 'bar';
    }
    
    protected function getOptions(): array
    {
        return [
            'plugins' => [
                'legend' => [
                    'display' => true,
                    'position' => 'top',
                ],
            ],
            'scales' => [
                'y' => [
                    'beginAtZero' => true,
                    'ticks' => [
                        'stepSize' => 1,
                    ],
                ],
            ],
            'responsive' => true,
            'maintainAspectRatio' => false,
        ];
    }
}