require "net/ldap"

module Rack
  class LdapAuthentication
    DEFAULTS = {
      port: 389,
      uid_attribute: "uid",
      filter_template: "(%{uid_attribute}=%{username})",
      authentication_realm: "LDAP Authentication",
      use_tls: false,
      allowed_paths: %w[/health /favicon.ico],
      allow_assets: true
    }.freeze

    def initialize(app, options = {})
      @app = app
      @options = DEFAULTS.merge(options.transform_keys(&:to_sym))
    end

    def call(env)
      request = Rack::Request.new(env)
      return @app.call(env) if allowed_request?(request)

      auth = Rack::Auth::Basic::Request.new(env)
      return unauthorized unless auth.provided? && auth.basic? && auth.credentials

      username, password = auth.credentials
      return unauthorized unless username && password

      if authenticate_username_and_password(username, password)
        env["REMOTE_USER"] = username
        @app.call(env)
      else
        unauthorized
      end
    end

    private

    def allowed_request?(request)
      if @options[:allow_assets] && request.path.start_with?("/assets")
        return true
      end

      @options[:allowed_paths].any? do |allowed|
        request.path == allowed || request.path.start_with?(allowed)
      end
    end

    def authenticate_username_and_password(username, password)
      ldap = init_ldap(username, password)
      result = ldap.bind
      Rails.logger.info "LDAP auth attempt for #{username}: #{result ? 'success' : 'failure'}"
      result
    rescue StandardError => e
      Rails.logger.warn "LDAP auth error for #{username}: #{e.class} #{e.message}"
      false
    end

    def init_ldap(username, password)
      ldap_options = {
        host: @options.fetch(:host),
        port: @options.fetch(:port),
        encryption: encryption_option
      }

      if @options[:admin_bind_dn] && @options[:admin_bind_password]
        admin_ldap = Net::LDAP.new(ldap_options.merge(
          auth: {
            method: :simple,
            username: @options[:admin_bind_dn],
            password: @options[:admin_bind_password]
          }
        ))

        return simple_user_ldap(username, password) if admin_ldap.bind
        return Net::LDAP.new(ldap_options.merge(
          auth: {
            method: :simple,
            username: bind_dn(username),
            password: password
          }
        ))
      end

      Net::LDAP.new(ldap_options.merge(
        auth: {
          method: :simple,
          username: bind_dn(username),
          password: password
        }
      ))
    end

    def simple_user_ldap(username, password)
      user_dn = search_user_dn(username)
      return Net::LDAP.new(host: @options.fetch(:host), port: @options.fetch(:port), encryption: encryption_option) unless user_dn

      Net::LDAP.new(
        host: @options.fetch(:host),
        port: @options.fetch(:port),
        encryption: encryption_option,
        auth: {
          method: :simple,
          username: user_dn,
          password: password
        }
      )
    end

    def search_user_dn(username)
      filter = Net::LDAP::Filter.construct(
        format(@options.fetch(:filter_template),
          uid_attribute: @options.fetch(:uid_attribute),
          username: escape_filter(username)
        )
      )

      Rails.logger.info "LDAP search DN for #{username} using filter #{filter}"
      ldap = Net::LDAP.new(
        host: @options.fetch(:host),
        port: @options.fetch(:port),
        encryption: encryption_option,
        auth: {
          method: :simple,
          username: @options[:admin_bind_dn],
          password: @options[:admin_bind_password]
        }
      )

      return nil unless ldap.bind

      result = ldap.search(base: @options.fetch(:base), filter: filter, scope: Net::LDAP::SearchScope_WholeSubtree)
      user_dn = result&.first&.dn
      Rails.logger.info "LDAP search result for #{username}: #{user_dn || 'no DN found'}"
      user_dn
    end

    def bind_dn(username)
      dn = if @options[:bind_dn_template].present?
        @options[:bind_dn_template] % { username: username }
      else
        "#{@options.fetch(:uid_attribute)}=#{username},#{@options.fetch(:base)}"
      end
      Rails.logger.info "LDAP bind DN for #{username}: #{dn}"
      dn
    end

    def encryption_option
      return nil unless @options[:use_tls]
      { method: :simple_tls }
    end

    def escape_filter(value)
      value.to_s.gsub(/([\*\(\)\\])/) { |m| "\\#{m}" }
    end

    def unauthorized
      [ 401, { "Content-Type" => "text/plain", "WWW-Authenticate" => "Basic realm=\"#{@options[:authentication_realm]}\"" }, [ "HTTP Basic: Access denied.\n" ] ]
    end
  end
end
