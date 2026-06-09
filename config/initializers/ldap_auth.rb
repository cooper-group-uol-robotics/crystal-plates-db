require Rails.root.join("lib/rack/ldap_authentication")

if ENV["LDAP_HOST"].present?
  Rails.logger.info "Initializing LDAP auth middleware with host=#{ENV.fetch("LDAP_HOST")} base=#{ENV.fetch("LDAP_BASE")}"

  Rails.application.config.middleware.use Rack::LdapAuthentication,
    host: ENV.fetch("LDAP_HOST"),
    port: ENV.fetch("LDAP_PORT", "389").to_i,
    base: ENV.fetch("LDAP_BASE"),
    uid_attribute: ENV.fetch("LDAP_UID_ATTRIBUTE", "uid"),
    bind_dn_template: ENV["LDAP_BIND_DN_TEMPLATE"],
    admin_bind_dn: ENV["LDAP_ADMIN_BIND_DN"],
    admin_bind_password: ENV["LDAP_ADMIN_BIND_PASSWORD"],
    filter_template: ENV.fetch("LDAP_SEARCH_FILTER", "(%{uid_attribute}=%{username})"),
    authentication_realm: ENV.fetch("LDAP_AUTH_REALM", "LDAP Authentication"),
    use_tls: ENV["LDAP_USE_TLS"] == "true",
    allowed_paths: (ENV["LDAP_ALLOWED_PATHS"] || "/health,/favicon.ico").split(","),
    allow_assets: true
else
  Rails.logger.warn "LDAP auth middleware not initialized because LDAP_HOST is not set"
end
