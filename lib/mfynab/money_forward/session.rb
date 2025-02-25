# frozen_string_literal: true

require "ferrum"
require "net/http"
require "nokogiri"
require "uri"

module MFYNAB
  class MoneyForward
    class Session
      COOKIE_NAME = "_moneybook_session"
      SIGNIN_PATH = "/sign_in"

      def initialize(username:, password:, logger:, base_url:)
        @username = username
        @password = password
        @logger = logger
        @base_url = URI(base_url)
      end

      def http_get(path)
        Net::HTTP.start(base_url.host, use_ssl: true) do |http|
          request = Net::HTTP::Get.new(
            path,
            "Cookie" => "#{COOKIE_NAME}=#{cookie.value}",
          )

          result = http.request(request)
          raise "Got unexpected result: #{result.inspect}" unless result.is_a?(Net::HTTPSuccess)

          result.body
        end
      end

      def http_post(path, body, headers = {})
        Net::HTTP.start(base_url.host, use_ssl: true) do |http|
          request = Net::HTTP::Post.new(
            path,
            "Cookie" => "#{COOKIE_NAME}=#{cookie.value}",
            **headers,
          )
          request.body = body

          result = http.request(request)
          raise "Got unexpected result: #{result.inspect}" unless result.is_a?(Net::HTTPSuccess)

          result.body
        end
      end

      def cookie
        # TODO: cache on disk
        @cookie || login
      end

      def cookie=(cookie) # rubocop:disable Style/TrivialAccessors
        # TODO: Update cache on disk
        @cookie = cookie
      end

      def login
        logger.info("Logging in to Money Forward...")
        with_ferrum do |browser|
          browser.goto("#{base_url}#{SIGNIN_PATH}")
          browser.at_css("input[type='email']").focus.type(username)
          browser.at_css("input[type='password']").focus.type(password, :Enter)
          wait(5) do
            browser.body.include?("ログアウト")
          end

          self.cookie = browser.cookies[COOKIE_NAME]
        rescue Timeout::Error
          # FIXME: use custom error class
          raise "Login failed"
        end
      end

      # FIXME: not sure a CSRF token is generic to the session
      # Maybe it has different instances depending on the page it's on?
      def csrf_token
        @_csrf_token ||= Nokogiri::HTML(http_get("/accounts"))
          .at_css("meta[name='csrf-token']")[:content]
      end

      private

        attr_reader :username, :password, :logger, :base_url

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
          browser.screenshot(path: "screenshot.png")
          logger.error("An error occurred and a screenshot was saved to ./screenshot.png")
          raise
        ensure
          browser&.quit
        end

        def wait(time)
          Timeout.timeout(time) do
            loop do
              return if yield

              sleep 0.1
            end
          end
        end
    end
  end
end
