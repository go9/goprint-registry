defmodule GoprintRegistry.PrintJobs.PrintJob do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "print_jobs" do
    field :job_id, :string
    field :printer_id, :string
    field :content, :string
    field :paper_size, :string
    field :options, :map, default: %{}
    
    # Server-side status
    field :status, :string, default: "pending"
    field :status_details, :string
    
    # Client-side status
    field :client_status, :string
    field :client_status_details, :string
    field :client_status_updated_at, :utc_datetime
    
    belongs_to :client, GoprintRegistry.Clients.Client, type: :binary_id
    belongs_to :user, GoprintRegistry.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(print_job, attrs) do
    print_job
    |> cast(attrs, [:job_id, :printer_id, :content, :paper_size, :options, :status, 
                     :status_details, :client_id, :user_id])
    |> validate_required([:job_id, :printer_id, :content, :client_id, :user_id])
    |> validate_inclusion(:status, ["pending", "sent", "acknowledged", "completed", "failed"])
    |> unique_constraint(:job_id)
  end

  def status_changeset(print_job, attrs) do
    print_job
    |> cast(attrs, [:status, :status_details])
    |> validate_inclusion(:status, ["pending", "sent", "acknowledged", "completed", "failed"])
  end

  def client_status_changeset(print_job, attrs) do
    print_job
    |> cast(attrs, [:client_status, :client_status_details, :client_status_updated_at])
    |> validate_inclusion(:client_status, ["queued", "printing", "printed", "error"])
  end
end