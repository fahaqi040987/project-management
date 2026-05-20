<?php

namespace App\Livewire;

use Livewire\Component;
use App\Models\Project;
use App\Models\Ticket;
use App\Models\TicketCategory;
use App\Models\TicketPriority;
use App\Models\TicketStatus;
use Filament\Forms\Concerns\InteractsWithForms;
use Filament\Forms\Contracts\HasForms;
use Filament\Forms\Form;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\RichEditor;
use Filament\Forms\Components\Section;
use Filament\Forms\Components\Grid;
use Filament\Notifications\Notification;
use Filament\Forms\Get;

class SubmitTicket extends Component implements HasForms
{
    use InteractsWithForms;

    public ?array $data = [];
    public bool $isSubmitted = false;

    public function mount(): void
    {
        $this->form->fill();
    }

    public function form(Form $form): Form
    {
        return $form
            ->schema([
                Section::make('Submit a New Ticket')
                    ->description('Please provide the details of your request or issue below.')
                    ->schema([
                        Grid::make(2)
                            ->schema([
                                Select::make('project_id')
                                    ->label('Select Project')
                                    ->options(Project::query()->pluck('name', 'id'))
                                    ->required()
                                    ->searchable()
                                    ->preload()
                                    ->live()
                                    ->afterStateUpdated(function (callable $set) {
                                        $set('ticket_category_id', null);
                                    }),

                                Select::make('ticket_category_id')
                                    ->label('Category')
                                    ->options(function (Get $get) {
                                        $projectId = $get('project_id');
                                        if (!$projectId) {
                                            return [];
                                        }
                                        return TicketCategory::where('project_id', $projectId)
                                            ->pluck('name', 'id')
                                            ->toArray();
                                    })
                                    ->searchable()
                                    ->preload()
                                    ->nullable()
                                    ->hidden(fn(Get $get): bool => !$get('project_id')),
                            ]),

                        TextInput::make('name')
                            ->label('Ticket Subject / Title')
                            ->required()
                            ->maxLength(255)
                            ->placeholder('Brief summary of your request'),

                        Select::make('priority_id')
                            ->label('Priority')
                            ->options(TicketPriority::pluck('name', 'id')->toArray())
                            ->searchable()
                            ->preload()
                            ->default(function () {
                                return TicketPriority::where('name', 'Medium')->value('id') ?? 
                                       TicketPriority::first()?->id;
                            })
                            ->required(),

                        RichEditor::make('description')
                            ->label('Description')
                            ->required()
                            ->fileAttachmentsDisk('public')
                            ->fileAttachmentsDirectory('attachments')
                            ->fileAttachmentsVisibility('public')
                            ->fileAttachmentsAcceptedFileTypes(['image/png', 'image/jpeg', 'image/gif', 'image/webp', 'video/mp4'])
                            ->placeholder('Please provide detailed information about your request...'),
                    ])
            ])
            ->statePath('data');
    }

    public function create(): void
    {
        $data = $this->form->getState();

        // Cari status "Backlog" atau status dengan urutan pertama
        $status = TicketStatus::where('project_id', $data['project_id'])
            ->where(function ($query) {
                $query->where('name', 'like', '%Backlog%')
                      ->orWhere('name', 'like', '%To Do%');
            })
            ->first();

        if (!$status) {
            $status = TicketStatus::where('project_id', $data['project_id'])
                ->orderBy('sort_order', 'asc')
                ->first();
        }

        // Simpan tiket baru
        $ticket = Ticket::create([
            'project_id' => $data['project_id'],
            'ticket_status_id' => $status?->id,
            'ticket_category_id' => $data['ticket_category_id'],
            'priority_id' => $data['priority_id'],
            'name' => $data['name'],
            'description' => $data['description'],
            // created_by akan null jika guest (tidak login), atau terisi otomatis di model jika auth()->id() ada
        ]);

        Notification::make()
            ->title('Success!')
            ->body('Your ticket has been successfully submitted.')
            ->success()
            ->send();

        $this->isSubmitted = true;
    }

    public function submitAnother(): void
    {
        $this->form->fill();
        $this->isSubmitted = false;
    }

    public function render()
    {
        return view('livewire.submit-ticket')
            ->layout('layouts.guest', ['title' => 'Submit Ticket']);
    }
}
