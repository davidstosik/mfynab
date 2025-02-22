# frozen_string_literal: true

require "ferrum"
require "net/http"
require "nokogiri"
require "uri"

module MFYNAB
  class MoneyForward
    ACCOUNT_FRESHNESS_LIMIT = 24 * 60 * 60 # 1 day
    DEFAULT_BASE_URL = "https://moneyforward.com"
    SIGNIN_PATH = "/sign_in"
    CSV_PATH = "/cf/csv"
    SESSION_COOKIE_NAME = "_moneybook_session"

    def initialize(logger:, base_url: DEFAULT_BASE_URL)
      @base_url = URI(base_url)
      @logger = logger
    end

    def get_session_id(username:, password:)
      with_ferrum do |browser|
        browser.goto("#{base_url}#{SIGNIN_PATH}")
        browser.at_css("input[type='email']").focus.type(username)
        browser.at_css("input[type='password']").focus.type(password, :Enter)

        wait(5) do
          browser.body.include?("ログアウト")
        end

        browser.cookies[SESSION_COOKIE_NAME].value
      rescue Timeout::Error
        # FIXME: use custom error class
        raise "Login failed"
      end
    end

    def update_accounts(session_id:, account_names:)
      logger.info("Checking Money Forward accounts status")
      accounts = accounts_status(
        session_id: session_id,
        account_names: account_names,
      )

      # Require accounts to have been updated in the last day
      # FIXME: make configurable?
      time_limit = Time.now - ACCOUNT_FRESHNESS_LIMIT

      wait_and_retry = false
      accounts.each do |account|
        status_log = "#{account[:name]}:\t#{account[:status]}"
        case account[:status]
        when :success
          status_log << " (#{account[:updated_at]})"
          if account[:updated_at] < time_limit
            status_log << " - Will update"
            update_account(session_id: session_id, id_hash: account[:id_hash])
            wait_and_retry = true
          end
        when :processing
          status_log << " - Updating"
          wait_and_retry = true
        else
          # FIXME: I think I need to try and update accounts with weird state at least one,
          # to confirm whether it's resolved.
          status_log << " - Ignoring"
          # FIXME: we can probably handle :additional_request and/or :login right here in the script,
          # when we find the time.
          # FIXME: sometimes, nothing can be done about the status, for example, I can currently see モバイルSUICA
          # show an `errors` status with this message:
          # ただいま大変混み合っております。今しばらくお待ちいただきますようお願いいたします。 失敗日時：02/22 14:03
          # In other words: "please wait". Maybe improve messaging?
          warning_message = "The Money Forward account named #{account[:name]} is in an invalid state: "
          warning_message << "`#{account[:status]}`"
          warning_message << " (#{account[:extra]['message']})" if account[:extra]["message"]
          warning_message << ". Please handle the issue manually to resume syncing."
          logger.warn(warning_message)
        end

        # FIXME: I'll probably want to refresh the display instead of relogging everything every 5 seconds.
        logger.info(status_log)
      end

      return unless wait_and_retry

      logger.info("Waiting for a while before checking status again...")
      # FIXME: I'm never comfortable with using sleep().
      # Do I want to implement a solution based on callbacks?
      # For example, the script could say:
      # > Accounts are out of date.
      # > I triggered the updates, and will call myself again in X seconds/minutes.
      # > When the accounts are updated, I'll proceed to the next step.
      sleep(5)
      update_accounts(session_id: session_id, account_names: account_names)
    end

    def accounts_status(session_id:, account_names:)
      # Download /accounts page
      # Parse it with Nokogiri
      Net::HTTP.start(base_url.host, use_ssl: true) do |http|
        request = Net::HTTP::Get.new(
          "/accounts",
          "Cookie" => "#{SESSION_COOKIE_NAME}=#{session_id}",
        )

        result = http.request(request)
        root = Nokogiri::HTML(result.body)

        accounts = root.css("section.accounts section.common-account-table-container > table > tr[id]").map do |node|
          {
            id_hash: node[:id],
            name: node.xpath("td").first.text.lines[1].strip,
            status: node.css("td.account-status>span:not([id*='hidden'])").text.strip,
            # FIXME: can this be a little more robust?
            #  - this should not depend on the timezone the server is running in
            #  - this should explicitly fail if parsing is not possible
            updated_at: Time.parse(node.css("td.created").text[/(?<=\().*?(?=\))/]),
          }
        end

        accounts.select! { account_names.include?(_1[:name]) }

        # FIXME: I should only care about accounts that are of interest for mfynab
        # (the ones that have a mapping in the config file)
        accounts.each do |account|
          account[:status] =
            case account[:status]
            when "正常" then :success
            when "更新中" then :processing
            else
              request = Net::HTTP::Get.new(
                "/accounts/polling/#{account[:id_hash]}",
                "Cookie" => "#{SESSION_COOKIE_NAME}=#{session_id}",
              )
              response = http.request(request)
              # JSON format:
              #  - loading: boolean
              #  - message: Japanese text
              #  - status: success, processing, additional_request, errors, important_announcement,
              #            invalid_password, login, suspended
              # FIXME: make more robust
              queried_status = JSON.parse(response.body)
              account[:extra] = queried_status
              queried_status["status"].to_sym
            end
        end

        accounts
      end
    end

    # FIXME: I shouldn't have to pass session_id to all these methods
    def update_account(session_id:, id_hash:)
      Net::HTTP.start(base_url.host, use_ssl: true) do |http|
        # FIXME: centralize request building
        csrf_token_page = http.get(
          "/accounts",
          "Cookie" => "#{SESSION_COOKIE_NAME}=#{session_id}",
        ).body

        csrf_token = Nokogiri::HTML(csrf_token_page).at_css("meta[name='csrf-token']")[:content]
        request = Net::HTTP::Post.new(
          "/faggregation_queue2/#{id_hash}",
          "Cookie" => "#{SESSION_COOKIE_NAME}=#{session_id}",
          "X-CSRF-Token" => csrf_token,
        )
        request.body = URI.encode_www_form(commit: "更新")

        http.request(request)
      end
    end

    def download_csv(session_id:, path:, months:)
      month = Date.today
      month -= month.day - 1 # First day of month
      months.times do
        date_string = month.strftime("%Y-%m")

        logger.info("Downloading CSV for #{date_string}")

        # FIXME: I don't really need to save the CSV files to disk anymore.
        # Maybe just return parsed CSV data?
        File.open(File.join(path, "#{date_string}.csv"), "wb") do |file|
          file << download_csv_string(date: month, session_id: session_id)
        end

        month = month.prev_month
      end
    end

    def download_csv_string(date:, session_id:)
      Net::HTTP.start(base_url.host, use_ssl: true) do |http|
        http.response_body_encoding = Encoding::SJIS

        request = Net::HTTP::Get.new(
          "#{CSV_PATH}?from=#{date.strftime('%Y/%m/%d')}",
          "Cookie" => "#{SESSION_COOKIE_NAME}=#{session_id}",
        )

        result = http.request(request)
        raise "Got unexpected result: #{result.inspect}" unless result.is_a?(Net::HTTPSuccess)
        raise "Invalid encoding" unless result.body.valid_encoding?

        result.body.encode(Encoding::UTF_8)
      end
    end

    private

      attr_reader :base_url, :logger

      def wait(time)
        Timeout.timeout(time) do
          loop do
            return if yield

            sleep 0.1
          end
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
        browser.screenshot(path: "screenshot.png")
        logger.error("An error occurred and a screenshot was saved to ./screenshot.png")
        raise
      ensure
        browser&.quit
      end
  end
end
