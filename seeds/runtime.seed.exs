
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
  aud: auth0_audience,
  domain: auth0_domain,
  client_id: auth0_client_id

