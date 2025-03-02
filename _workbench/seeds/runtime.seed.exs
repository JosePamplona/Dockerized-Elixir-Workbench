
# <!-- workbench-auth0 open -->
# Auth0 implementation:
auth0_domain = System.get_env("AUTH0_DOMAIN") ||
  raise """
  environment variable AUTH0_DOMAIN is missing.
  For example: dev-tenant.us.auth0.com
  """

auth0_client_id = System.get_env("AUTH0_CLIENT_ID") ||
  raise """
  environment variable AUTH0_CLIENT_ID is missing.
  For example: j8Te46O4Sk55NKXnY6M7m6WDagdoxVD5
  """

auth0_issuer = System.get_env("AUTH0_ISSUER") ||
  raise """
  environment variable AUTH0_ISSUER is missing.
  For example: "https://dev-tenant.us.auth0.com/"
  """

auth0_audience = System.get_env("AUTH0_AUDIENCE") ||
  raise """
  environment variable AUTH0_AUDIENCE is missing.
  For example: "https://dev-tenant.us.auth0.com/api/v2/"
  """

# <!-- workbench-auth0 close -->
# <!-- workbench-openai open -->
# AI Assistant implementation:
ai_assistant_api_url = System.get_env("AI_ASSISTANT_API_URL") ||
raise """
environment variable AI_ASSISTANT_API_URL is missing.
For example: "sk-proj-secret"
"""

ai_assistant_api_key = System.get_env("AI_ASSISTANT_API_KEY") ||
raise """
environment variable AI_ASSISTANT_API_KEY is missing.
For example: "sk-proj-secret"
"""

# <!-- workbench-openai close -->
# <!-- workbench-auth0 open -->
# Auth0 & ExDoc implementation:
# Create auth_config.js file for token request in ExDoc token page.
if config_env() != :prod do
  File.mkdir_p!("./priv/static/doc/assets/")
  File.write(
    "./priv/static/doc/assets/auth_config.js",
    """
    var authConfig = {
      domain: "#{auth0_domain}",
      client_id: "#{auth0_client_id}"
    }
    """
  )
end

config :auth0_jwks,
  iss: auth0_issuer,
  aud: auth0_audience

config :%{elixir_project_name},
  auth0_domain: auth0_domain,
  auth0_client_id: auth0_client_id,
  auth0_issuer: auth0_issuer,
  auth0_audience: auth0_audience,
  # <!-- workbench-auth0 close -->
  # <!-- workbench-openai open -->
  ai_assistant_api_url: ai_assistant_api_url,
  ai_assistant_api_key: ai_assistant_api_key
  # <!-- workbench-openai close -->

