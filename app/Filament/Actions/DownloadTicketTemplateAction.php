<?php

namespace App\Filament\Actions;

use App\Exports\TicketTemplateExport;
use App\Models\Project;
use Filament\Actions\Action;
use Filament\Forms\Components\Select;
use Filament\Notifications\Notification;
use Maatwebsite\Excel\Facades\Excel;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

class DownloadTicketTemplateAction
{
    public static function make(): Action
    {
        return Action::make('download_template')
            ->label('Download Import Template')
            ->icon('heroicon-m-arrow-down-tray')
            ->color('info')
            ->schema([
                Select::make('project_id')
                    ->label('Select Project')
                    ->options(function () {
                        return Project::query()
                            ->whereHas('members', function ($query) {
                                $query->where('users.id', auth()->id());
                            })
                            ->orWhere(function ($query) {
                                if (auth()->user()->hasRole('super_admin')) {
                                    $query->whereRaw('1=1'); // Show all projects for super admin
                                }
                            })
                            ->pluck('name', 'id')
                            ->toArray();
                    })
                    ->required()
                    ->searchable(),
            ])
            ->action(function (array $data): BinaryFileResponse {
                $project = Project::findOrFail($data['project_id']);
                
                $filename = 'ticket-import-template-' . $project->name . '-' . now()->format('Y-m-d') . '.xlsx';
                $filename = preg_replace('/[^A-Za-z0-9\\-_.]/', '', $filename);
                
                Notification::make()
                    ->title('Template Downloaded')
                    ->body("Import template for project '{$project->name}' has been downloaded.")
                    ->success()
                    ->send();
                
                return Excel::download(new TicketTemplateExport($project), $filename);
            });
    }
}