# frozen_string_literal: true

require "ferrum"
require "net/http"
require "uri"

module MFYNAB
  class MoneyForward
    class Session
      COOKIE_NAME = "_moneybook_session"
      DEFAULT_BASE_URL = "https://moneyforward.com"
      SIGNIN_PATH = "/sign_in"

      def initialize(username:, password:, logger:, base_url: DEFAULT_BASE_URL)
        @username = username
        @password = password
        @logger = logger
        @base_url = URI(base_url)
      end

      def login
        logger.info("Logging in to Money Forward...")
        with_ferrum do |browser|
          submit_login_form(browser)

          self.cookie = browser.cookies[COOKIE_NAME]
        rescue Timeout::Error
          # FIXME: use custom error class
          raise "Login failed"
        end
      end

      def cookie
        @cookie || login
      end

      def http_get(path, params = {})
        path = URI.join(base_url, path)
        path.query = URI.encode_www_form(params) unless params.empty?
        request = Net::HTTP::Get.new(path, "Cookie" => "#{COOKIE_NAME}=#{cookie.value}")
        http_request(request)
      end

      def http_post(path, body, headers = {})
        request = Net::HTTP::Post.new(
          path,
          "Cookie" => "#{COOKIE_NAME}=#{cookie.value}",
          **headers,
        )
        request.body = body
        http_request(request)
      end

      # FIXME: not sure a CSRF token is generic to the session
      # Maybe it has different instances depending on the page it's on?
      def csrf_token
        @_csrf_token ||= Nokogiri::HTML(http_get("/accounts"))
          .at_css("meta[name='csrf-token']")[:content]
      end

      private

        attr_reader :username, :password, :logger, :base_url
        attr_writer :cookie

        def http_request(request)
          # FIXME: switch to Faraday or another advanced HTTP library?
          # (Better error handling, response parsing, cookies, possibly keep the connection open, etc.)
          Net::HTTP.start(base_url.host, use_ssl: true) do |http|
            result = http.request(request)
            raise "Got unexpected result: #{result.inspect}" unless result.is_a?(Net::HTTPSuccess)

            result.body
          end
        end

        def with_ferrum
          browser = Ferrum::Browser.new(timeout: 30, headless: !ENV.key?("NO_HEADLESS"))
          user_agent = browser.default_user_agent.sub("HeadlessChrome", "Chrome")
          browser.headers.add({
            "Accept-Language" => "en-US,en",
            "User-Agent" => user_agent,
          })
          yield browser
        rescue StandardError
          # FIXME: add datetime to path
          browser&.screenshot(path: "screenshot.png")
          logger.error("An error occurred and a screenshot was saved to ./screenshot.png")
          raise
        ensure
          browser&.quit
        end

        def submit_login_form(browser)
          browser.goto("#{base_url}#{SIGNIN_PATH}")
          browser.at_css("input[type='email']").focus.type(username)
          browser.at_css("input[type='password']").focus.type(password, :Enter)
          Timeout.timeout(5) do
            sleep 0.1 until browser.body.include?("ログアウト")
          end
        end
    end
  end
end
