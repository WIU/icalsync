require 'googleauth'

module Google
  #
  # This is a utility class that communicates with the google calendar api.
  #
  class Connection
    # BASE_URI = 'https://www.googleapis.com/calendar/v3'.freeze
    # TOKEN_URI = 'https://accounts.google.com/o/oauth2/token'.freeze
    # AUTH_URI = 'https://accounts.google.com/o/oauth2/auth'.freeze
    SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR
    attr_accessor :client

    #
    # Prepare a connection to google for fetching a calendar events
    #
    #  the +params+ paramater accepts
    # * :client_id => the client ID that you received from Google after registering your application with them (https://console.developers.google.com/)
    # * :client_secret => the client secret you received from Google after registering your application with them.
    # * :redirect_uri => the url where your users will be redirected to after they have successfully permitted access to their calendars. Use 'urn:ietf:wg:oauth:2.0:oob' if you are using an 'application'"
    # * :refresh_token => if a user has already given you access to their calendars, you can specify their refresh token here and you will be 'logged on' automatically (i.e. they don't need to authorize access again)
    #

    def initialize(params)
      raise ArgumentError unless Connection.credentials_provided?(params)
      @impersonator = params[:impersonator] if params[:impersonator]
      @client = dup_client
    end

    def dup_client
      ap @impersonator
      auth = Google::Auth.get_application_default(SCOPE)
      c = auth.dup
      c.sub = @impersonator
      c.fetch_access_token!
      ap c
      c
    end

    #
    # The URL you need to send a user in order to let them grant you access to their calendars.
    #
    # def authorize_url
    #   @client.authorization_uri
    # end

    #
    # The single use auth code that google uses during the auth process.
    #
    # def auth_code
    #   @client.code
    # end

    #
    # The current access token.  Used during a session, typically expires in a hour.
    #
    # def access_token
    #   @client.access_token
    # end

    #
    # The refresh token is used to obtain a new access token.  It remains valid until a user revokes access.
    #
    # def refresh_token
    #   @client.refresh_token
    # end

    #
    # Convenience method used to streamline the process of logging in with a auth code.
    # Returns the refresh token.
    #
    # def login_with_auth_code(auth_code)
    #   @client.code = auth_code
    #   Connection.get_new_access_token(@client)
    #   @client.refresh_token
    # end

    #
    # Convenience method used to streamline the process of logging in with a refresh token.
    #
    # def login_with_refresh_token(refresh_token)
    #   @client.refresh_token = refresh_token
    #   @client.grant_type = 'refresh_token'
    #   Connection.get_new_access_token(@client)
    # end

    #
    # Send a request to google.
    #
    def send(path, method, content = '', wait = nil)
      if wait
        rnd = rand
        puts "Waiting for #{(wait + rnd).round(3)} sec and resend"
        sleep(wait + rnd)
      end
      uri = BASE_URI + path
      response = @client.fetch_protected_resource(
        uri: uri,
        method: method,
        body: content,
        headers: { 'Content-type' => 'application/json' }
      )

      case response.status
      when 400
        puts content
        raise HTTPRequestFailed, response.body
      when 403
        wait = wait ? wait * 2 : 1
        raise(HTTPRequestFailed, response.body) if wait > 1025
        return send(path, method, content, wait)
      when 404 then raise HTTPNotFound, response.body
      when 405..499 then raise HTTPRequestFailed, response.body
      end

      # check_for_errors(response)
      response
    end

    protected

    #
    # Utility method to centralize the process of getting an access token.
    #
    # def self.get_new_access_token(client) #:nodoc:
    #   client.fetch_access_token!
    # rescue Signet::AuthorizationError
    #   raise HTTPAuthorizationFailed
    # end

    # Google::HTTPQuotaExceeded: {
    # "error": {
    # "errors": [
    # {
    # "domain": "usageLimits",
    # "reason": "userRateLimitExceeded",
    # "message": "User Rate Limit Exceeded"
    # }
    # ],
    # "code": 403,
    # "message": "User Rate Limit Exceeded"
    # }
    # }

    #
    # Check for common HTTP Errors and raise the appropriate response.
    #
    def check_for_errors(response) #:nodoc
      case response.status
      when 400 then raise HTTPRequestFailed, response.body
      when 403 then raise HTTPQuotaExceeded, response.body
      when 404 then raise HTTPNotFound, response.body
      when 405..499 then raise HTTPRequestFailed, response.body
      end
    end

    private

    #
    # Utility method to centralize credential validation.
    #
    def self.credentials_provided?(params) #:nodoc:
      blank = /[^[:space:]]/
      !(params[:impersonator] !~ blank) # && !(params[:client_secret] !~ blank)
    end
  end
end
