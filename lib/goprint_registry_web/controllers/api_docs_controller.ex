defmodule GoprintRegistryWeb.ApiDocsController do
  use GoprintRegistryWeb, :controller
  alias GoprintRegistryWeb.ApiSpec
  
  def openapi(conn, _params) do
    spec = ApiSpec.spec() |> Map.from_struct() |> Map.delete(:__struct__)
    json(conn, spec)
  end
  
  def swagger_ui(conn, _params) do
    html(conn, """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <title>GoPrint API Documentation</title>
      <link rel="stylesheet" type="text/css" href="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui.css" />
      <style>
        html { box-sizing: border-box; overflow: -moz-scrollbars-vertical; overflow-y: scroll; }
        *, *:before, *:after { box-sizing: inherit; }
        body { margin:0; background: #fafafa; }
        .topbar { display: none !important; }
      </style>
    </head>
    <body>
      <div id="swagger-ui"></div>
      <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
      <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui-standalone-preset.js"></script>
      <script>
        window.onload = function() {
          const ui = SwaggerUIBundle({
            url: "/api/openapi",
            dom_id: '#swagger-ui',
            deepLinking: true,
            presets: [
              SwaggerUIBundle.presets.apis,
              SwaggerUIStandalonePreset
            ],
            plugins: [
              SwaggerUIBundle.plugins.DownloadUrl
            ],
            layout: "StandaloneLayout",
            persistAuthorization: true,
            tryItOutEnabled: true,
            requestInterceptor: (request) => {
              // Allow users to add their API key in the Swagger UI
              return request;
            }
          });
          window.ui = ui;
        };
      </script>
    </body>
    </html>
    """)
  end
end