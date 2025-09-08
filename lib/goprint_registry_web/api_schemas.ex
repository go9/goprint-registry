defmodule GoprintRegistryWeb.ApiSchemas do
  alias OpenApiSpex.Schema
  
  defmodule PrintJobRequest do
    require OpenApiSpex
    
    OpenApiSpex.schema(%{
      title: "Print Job Request",
      description: "Request to create a print job",
      type: :object,
      properties: %{
        client_id: %Schema{type: :string, format: :uuid, description: "UUID of the client/printer"},
        printer_id: %Schema{type: :string, description: "Identifier of the specific printer"},
        data_base64: %Schema{type: :string, description: "Base64 encoded file content"},
        mime: %Schema{type: :string, description: "MIME type of the file", example: "application/pdf"},
        filename: %Schema{type: :string, description: "Name of the file", example: "document.pdf"},
        options: %Schema{
          type: :object,
          description: "Additional print options",
          properties: %{
            document_name: %Schema{type: :string, description: "Display name for the print job"},
            page_size: %Schema{type: :string, enum: ["A4", "Letter", "Legal"], default: "A4"},
            copies: %Schema{type: :integer, minimum: 1, default: 1},
            color: %Schema{type: :boolean, default: true},
            duplex: %Schema{type: :boolean, default: false}
          }
        }
      },
      required: [:client_id, :printer_id, :data_base64, :mime],
      example: %{
        "client_id" => "123e4567-e89b-12d3-a456-426614174000",
        "printer_id" => "office-printer-1",
        "data_base64" => "JVBERi0xLjQKJeLjz9M...",
        "mime" => "application/pdf",
        "filename" => "report.pdf",
        "options" => %{
          "document_name" => "Q3 Report",
          "copies" => 2,
          "color" => true
        }
      }
    })
  end

  defmodule TestPrintRequest do
    require OpenApiSpex
    
    OpenApiSpex.schema(%{
      title: "Test Print Request",
      description: "Request to send a test print",
      type: :object,
      properties: %{
        client_id: %Schema{type: :string, format: :uuid, description: "UUID of the client/printer"},
        printer_id: %Schema{type: :string, description: "Identifier of the specific printer"}
      },
      required: [:client_id, :printer_id],
      example: %{
        "client_id" => "123e4567-e89b-12d3-a456-426614174000",
        "printer_id" => "office-printer-1"
      }
    })
  end

  defmodule PrintJobResponse do
    require OpenApiSpex
    
    OpenApiSpex.schema(%{
      title: "Print Job Response",
      description: "Response after creating a print job",
      type: :object,
      properties: %{
        success: %Schema{type: :boolean},
        job_id: %Schema{type: :string, description: "Unique identifier for the print job"},
        status: %Schema{type: :string, enum: ["queued", "sent", "printing", "completed", "failed"]},
        message: %Schema{type: :string, description: "Optional status message"}
      },
      required: [:success, :job_id, :status],
      example: %{
        "success" => true,
        "job_id" => "706a5fb8e4ccbdc117f23c1afd93b239970a7e",
        "status" => "queued"
      }
    })
  end

  defmodule ErrorResponse do
    require OpenApiSpex
    
    OpenApiSpex.schema(%{
      title: "Error Response",
      description: "Standard error response",
      type: :object,
      properties: %{
        success: %Schema{type: :boolean, default: false},
        error: %Schema{type: :string, description: "Error code"},
        message: %Schema{type: :string, description: "Human-readable error message"},
        details: %Schema{type: :object, description: "Additional error details", nullable: true}
      },
      required: [:success, :error],
      example: %{
        "success" => false,
        "error" => "unauthenticated",
        "message" => "Invalid or missing API key"
      }
    })
  end

  defmodule StatusResponse do
    require OpenApiSpex
    
    OpenApiSpex.schema(%{
      title: "Status Response",
      description: "API status response",
      type: :object,
      properties: %{
        status: %Schema{type: :string, enum: ["ok", "degraded", "down"]},
        version: %Schema{type: :string},
        timestamp: %Schema{type: :string, format: :"date-time"}
      },
      required: [:status, :version, :timestamp],
      example: %{
        "status" => "ok",
        "version" => "1.0.0",
        "timestamp" => "2024-01-08T12:00:00Z"
      }
    })
  end
end