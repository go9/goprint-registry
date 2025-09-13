defmodule GoprintRegistryWeb.ApiSpec do
  @behaviour OpenApiSpex.OpenApi

  @impl OpenApiSpex.OpenApi
  def spec do
    %OpenApiSpex.OpenApi{
      openapi: "3.0.0",
      info: %{
        title: "GoPrint Registry API",
        version: "1.0.0",
        description: """
        The GoPrint Registry API allows developers to integrate cloud printing capabilities into their applications.
        
        ## Authentication
        
        All API endpoints require authentication using Bearer tokens. You can generate API keys from your account settings.
        
        Include the token in the Authorization header:
        ```
        Authorization: Bearer your_api_key_here
        ```
        
        ## Rate Limiting
        
        API requests are rate-limited to ensure fair usage. Current limits:
        - 1000 requests per hour per API key
        - 100 concurrent connections per client
        
        ## Base URL
        
        Production: `https://goprint.dev/api`
        Development: `http://localhost:4002`
        """
      },
      servers: [
        %{url: "http://localhost:4002", description: "Development server"},
        %{url: "https://goprint.dev", description: "Production server"}
      ],
      paths: %{
        "/api/status" => %{
          "get" => %{
            tags: ["System"],
            summary: "API health check",
            description: "Check if the API is running and healthy",
            operationId: "getStatus",
            responses: %{
              "200" => %{
                description: "API is healthy",
                content: %{
                  "application/json" => %{
                    schema: %{
                      type: "object",
                      properties: %{
                        status: %{type: "string", enum: ["ok", "degraded", "down"]},
                        version: %{type: "string"},
                        timestamp: %{type: "string", format: "date-time"}
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "/api/clients" => %{
          "get" => %{
            tags: ["Clients"],
            summary: "List all clients",
            description: "Get a list of all clients associated with your account",
            operationId: "listClients",
            security: [%{"bearerAuth" => []}],
            responses: %{
              "200" => %{
                description: "List of clients",
                content: %{
                  "application/json" => %{
                    schema: %{
                      type: "array",
                      items: %{"$ref" => "#/components/schemas/Client"}
                    }
                  }
                }
              },
              "401" => %{
                description: "Unauthorized",
                content: %{
                  "application/json" => %{
                    schema: %{"$ref" => "#/components/schemas/ErrorResponse"}
                  }
                }
              }
            }
          }
        },
        "/api/clients/{client_id}" => %{
          "get" => %{
            tags: ["Clients"],
            summary: "Get client details",
            description: "Get detailed information about a specific client including status and printers",
            operationId: "getClient",
            security: [%{"bearerAuth" => []}],
            parameters: [
              %{
                name: "client_id",
                in: "path",
                required: true,
                schema: %{type: "string", format: "uuid"},
                description: "Client UUID"
              }
            ],
            responses: %{
              "200" => %{
                description: "Client details",
                content: %{
                  "application/json" => %{
                    schema: %{"$ref" => "#/components/schemas/ClientDetail"}
                  }
                }
              },
              "401" => %{
                description: "Unauthorized",
                content: %{
                  "application/json" => %{
                    schema: %{"$ref" => "#/components/schemas/ErrorResponse"}
                  }
                }
              },
              "404" => %{
                description: "Client not found",
                content: %{
                  "application/json" => %{
                    schema: %{"$ref" => "#/components/schemas/ErrorResponse"}
                  }
                }
              }
            }
          }
        },
        "/api/clients/subscribe" => %{
          "post" => %{
            tags: ["Clients"],
            summary: "Subscribe to a client",
            description: "Associate a client with your account to send print jobs to it",
            operationId: "subscribeClient",
            security: [%{"bearerAuth" => []}],
            requestBody: %{
              required: true,
              content: %{
                "application/json" => %{
                  schema: %{
                    type: "object",
                    required: ["client_id"],
                    properties: %{
                      client_id: %{type: "string", format: "uuid", description: "Client UUID to subscribe to"}
                    }
                  }
                }
              }
            },
            responses: %{
              "200" => %{
                description: "Successfully subscribed",
                content: %{
                  "application/json" => %{
                    schema: %{
                      type: "object",
                      properties: %{
                        success: %{type: "boolean"},
                        message: %{type: "string"}
                      }
                    }
                  }
                }
              },
              "401" => %{
                description: "Unauthorized",
                content: %{
                  "application/json" => %{
                    schema: %{"$ref" => "#/components/schemas/ErrorResponse"}
                  }
                }
              },
              "404" => %{
                description: "Client not found",
                content: %{
                  "application/json" => %{
                    schema: %{"$ref" => "#/components/schemas/ErrorResponse"}
                  }
                }
              }
            }
          }
        },
        "/api/clients/{client_id}/unsubscribe" => %{
          "delete" => %{
            tags: ["Clients"],
            summary: "Unsubscribe from a client",
            description: "Remove a client association from your account",
            operationId: "unsubscribeClient",
            security: [%{"bearerAuth" => []}],
            parameters: [
              %{
                name: "client_id",
                in: "path",
                required: true,
                schema: %{type: "string", format: "uuid"},
                description: "Client UUID"
              }
            ],
            responses: %{
              "200" => %{
                description: "Successfully unsubscribed",
                content: %{
                  "application/json" => %{
                    schema: %{
                      type: "object",
                      properties: %{
                        success: %{type: "boolean"},
                        message: %{type: "string"}
                      }
                    }
                  }
                }
              },
              "401" => %{
                description: "Unauthorized",
                content: %{
                  "application/json" => %{
                    schema: %{"$ref" => "#/components/schemas/ErrorResponse"}
                  }
                }
              },
              "404" => %{
                description: "Client not found",
                content: %{
                  "application/json" => %{
                    schema: %{"$ref" => "#/components/schemas/ErrorResponse"}
                  }
                }
              }
            }
          }
        },
        "/api/print_jobs" => %{
          "get" => %{
            tags: ["Print Jobs"],
            summary: "List print jobs",
            description: "Get a list of print jobs for your account",
            operationId: "listPrintJobs",
            security: [%{"bearerAuth" => []}],
            parameters: [
              %{
                name: "client_id",
                in: "query",
                required: false,
                schema: %{type: "string", format: "uuid"},
                description: "Filter by client ID"
              },
              %{
                name: "status",
                in: "query",
                required: false,
                schema: %{type: "string", enum: ["queued", "sent", "printing", "completed", "failed"]},
                description: "Filter by status"
              },
              %{
                name: "limit",
                in: "query",
                required: false,
                schema: %{type: "integer", default: 20, minimum: 1, maximum: 100},
                description: "Number of results to return"
              },
              %{
                name: "offset",
                in: "query",
                required: false,
                schema: %{type: "integer", default: 0, minimum: 0},
                description: "Number of results to skip"
              }
            ],
            responses: %{
              "200" => %{
                description: "List of print jobs",
                content: %{
                  "application/json" => %{
                    schema: %{
                      type: "object",
                      properties: %{
                        jobs: %{
                          type: "array",
                          items: %{"$ref" => "#/components/schemas/PrintJob"}
                        },
                        total: %{type: "integer"},
                        limit: %{type: "integer"},
                        offset: %{type: "integer"}
                      }
                    }
                  }
                }
              },
              "401" => %{
                description: "Unauthorized",
                content: %{
                  "application/json" => %{
                    schema: %{"$ref" => "#/components/schemas/ErrorResponse"}
                  }
                }
              }
            }
          }
        },
        "/api/print_jobs/{job_id}" => %{
          "get" => %{
            tags: ["Print Jobs"],
            summary: "Get print job status",
            description: "Get the current status and details of a specific print job",
            operationId: "getPrintJob",
            security: [%{"bearerAuth" => []}],
            parameters: [
              %{
                name: "job_id",
                in: "path",
                required: true,
                schema: %{type: "string"},
                description: "Print job ID"
              }
            ],
            responses: %{
              "200" => %{
                description: "Print job details",
                content: %{
                  "application/json" => %{
                    schema: %{"$ref" => "#/components/schemas/PrintJob"}
                  }
                }
              },
              "401" => %{
                description: "Unauthorized",
                content: %{
                  "application/json" => %{
                    schema: %{"$ref" => "#/components/schemas/ErrorResponse"}
                  }
                }
              },
              "404" => %{
                description: "Print job not found",
                content: %{
                  "application/json" => %{
                    schema: %{"$ref" => "#/components/schemas/ErrorResponse"}
                  }
                }
              }
            }
          },
          "delete" => %{
            tags: ["Print Jobs"],
            summary: "Cancel print job",
            description: "Cancel a print job if it hasn't been printed yet",
            operationId: "cancelPrintJob",
            security: [%{"bearerAuth" => []}],
            parameters: [
              %{
                name: "job_id",
                in: "path",
                required: true,
                schema: %{type: "string"},
                description: "Print job ID"
              }
            ],
            responses: %{
              "200" => %{
                description: "Print job cancelled",
                content: %{
                  "application/json" => %{
                    schema: %{
                      type: "object",
                      properties: %{
                        success: %{type: "boolean"},
                        message: %{type: "string"}
                      }
                    }
                  }
                }
              },
              "401" => %{
                description: "Unauthorized",
                content: %{
                  "application/json" => %{
                    schema: %{"$ref" => "#/components/schemas/ErrorResponse"}
                  }
                }
              },
              "404" => %{
                description: "Print job not found",
                content: %{
                  "application/json" => %{
                    schema: %{"$ref" => "#/components/schemas/ErrorResponse"}
                  }
                }
              },
              "409" => %{
                description: "Cannot cancel - job already printed or cancelled",
                content: %{
                  "application/json" => %{
                    schema: %{"$ref" => "#/components/schemas/ErrorResponse"}
                  }
                }
              }
            }
          }
        },
        "/api/print_jobs/file" => %{
          "post" => %{
            tags: ["Print Jobs"],
            summary: "Create a print job from file",
            description: "Submit a file for printing to a specific client and printer",
            operationId: "createPrintJobFile",
            security: [%{"bearerAuth" => []}],
            requestBody: %{
              required: true,
              content: %{
                "application/json" => %{
                  schema: %{"$ref" => "#/components/schemas/PrintJobRequest"}
                }
              }
            },
            responses: %{
              "201" => %{
                description: "Print job created successfully",
                content: %{
                  "application/json" => %{
                    schema: %{"$ref" => "#/components/schemas/PrintJobResponse"}
                  }
                }
              },
              "400" => %{
                description: "Bad request",
                content: %{
                  "application/json" => %{
                    schema: %{"$ref" => "#/components/schemas/ErrorResponse"}
                  }
                }
              },
              "401" => %{
                description: "Unauthorized",
                content: %{
                  "application/json" => %{
                    schema: %{"$ref" => "#/components/schemas/ErrorResponse"}
                  }
                }
              }
            }
          }
        },
        "/api/print_jobs/test" => %{
          "post" => %{
            tags: ["Print Jobs"],
            summary: "Send a test print",
            description: "Send a test page to verify printer connectivity",
            operationId: "createTestPrint",
            security: [%{"bearerAuth" => []}],
            requestBody: %{
              required: true,
              content: %{
                "application/json" => %{
                  schema: %{"$ref" => "#/components/schemas/TestPrintRequest"}
                }
              }
            },
            responses: %{
              "201" => %{
                description: "Test print created successfully",
                content: %{
                  "application/json" => %{
                    schema: %{"$ref" => "#/components/schemas/PrintJobResponse"}
                  }
                }
              },
              "400" => %{
                description: "Bad request",
                content: %{
                  "application/json" => %{
                    schema: %{"$ref" => "#/components/schemas/ErrorResponse"}
                  }
                }
              },
              "401" => %{
                description: "Unauthorized",
                content: %{
                  "application/json" => %{
                    schema: %{"$ref" => "#/components/schemas/ErrorResponse"}
                  }
                }
              }
            }
          }
        }
      },
      components: %{
        securitySchemes: %{
          "bearerAuth" => %{
            type: "http",
            scheme: "bearer",
            bearerFormat: "API Key"
          }
        },
        schemas: %{
          "Client" => %{
            type: "object",
            properties: %{
              id: %{type: "string", format: "uuid"},
              api_name: %{type: "string", description: "Display name for the client"},
              status: %{type: "string", enum: ["connected", "disconnected", "error"]},
              last_connected_at: %{type: "string", format: "date-time", nullable: true},
              registered_at: %{type: "string", format: "date-time"},
              operating_system: %{type: "string"},
              app_version: %{type: "string"},
              printer_count: %{type: "integer"}
            }
          },
          "ClientDetail" => %{
            type: "object",
            properties: %{
              id: %{type: "string", format: "uuid"},
              api_name: %{type: "string", description: "Display name for the client"},
              status: %{type: "string", enum: ["connected", "disconnected", "error"]},
              last_connected_at: %{type: "string", format: "date-time", nullable: true},
              registered_at: %{type: "string", format: "date-time"},
              operating_system: %{type: "string"},
              app_version: %{type: "string"},
              printers: %{
                type: "array",
                items: %{
                  type: "object",
                  properties: %{
                    id: %{type: "string"},
                    name: %{type: "string"},
                    status: %{type: "string", enum: ["online", "offline", "error"]},
                    is_default: %{type: "boolean"},
                    capabilities: %{
                      type: "object",
                      properties: %{
                        color: %{type: "boolean"},
                        duplex: %{type: "boolean"},
                        paper_sizes: %{type: "array", items: %{type: "string"}}
                      }
                    }
                  }
                }
              },
              statistics: %{
                type: "object",
                properties: %{
                  total_jobs: %{type: "integer"},
                  completed_jobs: %{type: "integer"},
                  failed_jobs: %{type: "integer"},
                  pages_printed: %{type: "integer"}
                }
              }
            }
          },
          "PrintJob" => %{
            type: "object",
            properties: %{
              job_id: %{type: "string"},
              client_id: %{type: "string", format: "uuid"},
              printer_id: %{type: "string"},
              status: %{type: "string", enum: ["queued", "sent", "printing", "completed", "failed", "cancelled"]},
              paper_size: %{type: "string"},
              pages: %{type: "integer", nullable: true},
              created_at: %{type: "string", format: "date-time"},
              updated_at: %{type: "string", format: "date-time"},
              completed_at: %{type: "string", format: "date-time", nullable: true},
              error_message: %{type: "string", nullable: true},
              options: %{
                type: "object",
                properties: %{
                  document_name: %{type: "string"},
                  copies: %{type: "integer"},
                  color: %{type: "boolean"},
                  duplex: %{type: "boolean"}
                }
              }
            }
          },
          "PrintJobRequest" => %{
            type: "object",
            required: ["client_id", "printer_id", "data_base64", "mime"],
            properties: %{
              client_id: %{type: "string", format: "uuid", description: "UUID of the client/printer"},
              printer_id: %{type: "string", description: "Identifier of the specific printer"},
              data_base64: %{type: "string", description: "Base64 encoded file content"},
              mime: %{type: "string", description: "MIME type of the file", example: "application/pdf"},
              filename: %{type: "string", description: "Name of the file", example: "document.pdf"},
              options: %{
                type: "object",
                properties: %{
                  document_name: %{type: "string"},
                  page_size: %{type: "string", enum: ["A4", "Letter", "Legal"], default: "A4"},
                  copies: %{type: "integer", minimum: 1, default: 1},
                  color: %{type: "boolean", default: true},
                  duplex: %{type: "boolean", default: false}
                }
              }
            }
          },
          "TestPrintRequest" => %{
            type: "object",
            required: ["client_id", "printer_id"],
            properties: %{
              client_id: %{type: "string", format: "uuid", description: "UUID of the client/printer"},
              printer_id: %{type: "string", description: "Identifier of the specific printer"}
            }
          },
          "PrintJobResponse" => %{
            type: "object",
            required: ["success", "job_id", "status"],
            properties: %{
              success: %{type: "boolean"},
              job_id: %{type: "string", description: "Unique identifier for the print job"},
              status: %{type: "string", enum: ["queued", "sent", "printing", "completed", "failed"]},
              message: %{type: "string", description: "Optional status message"}
            }
          },
          "ErrorResponse" => %{
            type: "object",
            required: ["success", "error"],
            properties: %{
              success: %{type: "boolean", default: false},
              error: %{type: "string", description: "Error code"},
              message: %{type: "string", description: "Human-readable error message"},
              details: %{type: "object", description: "Additional error details", nullable: true}
            }
          }
        }
      }
    }
  end
end