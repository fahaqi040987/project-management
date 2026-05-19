<?php

namespace App\Filament\Widgets;

use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\Filter;
use Filament\Forms\Components\DatePicker;
use Carbon\Carbon;
use Filament\Tables\Filters\SelectFilter;
use Filament\Actions\Action;
use App\Models\TicketHistory;
use Filament\Tables;
use Filament\Tables\Table;
use Filament\Widgets\TableWidget as BaseWidget;
use BezhanSalleh\FilamentShield\Traits\HasWidgetShield;

class RecentActivityTable extends BaseWidget
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

        return $user?->can(static::getPermissionName()) ?? false;
    }

    protected static ?string $heading = 'Recent Activities';
    
    protected int | string | array $columnSpan = [
        'md' => 2,
        'xl' => 1,
    ];
    
    protected static ?int $sort = 7;

    public function table(Table $table): Table
    {
        return $table
            ->query(
                TicketHistory::query()
                    ->with(['ticket.project', 'user', 'status'])
                    ->when(!auth()->user()->hasRole('super_admin'), function ($query) {
                        $query->whereHas('ticket.project.members', function ($subQuery) {
                            $subQuery->where('user_id', auth()->id());
                        });
                    })
                    ->latest()
            )
            ->columns([
                TextColumn::make('activity_summary')
                    ->label('Activity')
                    ->state(function (TicketHistory $record): string {
                        $ticketName = $record->ticket->name ?? 'Unknown ticket';
                        $trimmedName = strlen($ticketName) > 40 ? substr($ticketName, 0, 40) . '...' : $ticketName;
                        $userName = $record->user->name ?? 'Unknown user';
                        return "<span class='text-primary-600 font-medium'>{$userName}</span> changed \"{$trimmedName}\"";
                    })
                    ->description(function (TicketHistory $record): string {
                        $isToday = $record->created_at->isToday();
                        $time = $isToday 
                            ? $record->created_at->format('H:i')
                            : $record->created_at->format('M d, H:i');
                        $project = $record->ticket->project->name ?? 'No Project';
                        $uuid = $record->ticket->uuid ?? '';
                        return "{$time} • {$uuid} • {$project}";
                    })
                    ->html()
                    ->searchable(['users.name', 'tickets.name', 'tickets.uuid'])
                    ->weight('medium'),
                TextColumn::make('status.name')
                    ->label('Status')
                    ->badge()
                    ->alignEnd()
                    ->color(fn (TicketHistory $record): string => match($record->status->name ?? '') {
                        'To Do', 'Backlog' => 'gray',
                        'In Progress', 'Doing' => 'warning', 
                        'Review', 'Testing' => 'info',
                        'Done', 'Completed' => 'success',
                        'Cancelled', 'Blocked' => 'danger',
                        default => 'primary',
                    }),
            ])
            ->defaultSort('created_at', 'desc')
            ->filters([
                Filter::make('date_range')
                    ->schema([
                        DatePicker::make('start_date')
                            ->label('Start Date')
                            ->default(today()),
                        DatePicker::make('end_date')
                            ->label('End Date')
                            ->default(today()),
                    ])
                    ->query(function ($query, array $data) {
                        return $query
                            ->when($data['start_date'], function ($query, $date) {
                                $query->whereDate('created_at', '>=', $date);
                            })
                            ->when($data['end_date'], function ($query, $date) {
                                $query->whereDate('created_at', '<=', $date);
                            });
                    })
                    ->indicateUsing(function (array $data): array {
                        $indicators = [];
                        if ($data['start_date'] ?? null) {
                            $indicators[] = 'From: ' . Carbon::parse($data['start_date'])->format('M d, Y');
                        }
                        if ($data['end_date'] ?? null) {
                            $indicators[] = 'To: ' . Carbon::parse($data['end_date'])->format('M d, Y');
                        }
                        return $indicators;
                    }),

                Filter::make('today')
                    ->label('Today Only')
                    ->query(fn ($query) => $query->whereDate('created_at', today()))
                    ->toggle(),

                SelectFilter::make('user')
                    ->relationship('user', 'name')
                    ->searchable()
                    ->preload(),
            ])
            ->filtersFormColumns(2)
            ->recordActions([
                Action::make('view')
                    ->label('')
                    ->icon('heroicon-o-arrow-top-right-on-square')
                    ->size('sm')
                    ->tooltip('Open Ticket')
                    ->url(fn (TicketHistory $record): string => 
                        route('filament.admin.resources.tickets.view', $record->ticket)
                    )
                    ->openUrlInNewTab()
            ])
            ->recordUrl(fn (TicketHistory $record) => 
                route('filament.admin.resources.tickets.view', $record->ticket)
            )
            ->paginated([5, 25, 50])
            ->poll('30s')
            ->striped()
            ->emptyStateHeading('No Activity Found')
            ->emptyStateDescription('No ticket activities found for the selected period.')
            ->emptyStateIcon('heroicon-o-clock');
    }
}