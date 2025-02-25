# frozen_string_literal: true

require "nokogiri"
require "uri"
require "mfynab/money_forward/session"

module MFYNAB
  class MoneyForward
    ACCOUNT_FRESHNESS_LIMIT = 24 * 60 * 60 # 1 day
    DEFAULT_BASE_URL = "https://moneyforward.com"
    CSV_PATH = "/cf/csv"

    def initialize(username:, password:, logger:, base_url: DEFAULT_BASE_URL)
      @username = username
      @password = password
      @logger = logger
      @base_url = URI(base_url)
      @session = Session.new(username: username, password: password, logger: logger, base_url: base_url)
    end

    def update_accounts(account_names:)
      logger.info("Checking Money Forward accounts status")
      accounts = accounts_status(account_names: account_names)

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
            update_account(id_hash: account[:id_hash])
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
      update_accounts(account_names: account_names)
    end

    def accounts_status(account_names:)
      # Download /accounts page
      # Parse it with Nokogiri
      body = session.http_get("/accounts")
      root = Nokogiri::HTML(body)

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
            body = session.http_get("/accounts/polling/#{account[:id_hash]}")
            # JSON format:
            #  - loading: boolean
            #  - message: Japanese text
            #  - status: success, processing, additional_request, errors, important_announcement,
            #            invalid_password, login, suspended
            # FIXME: make more robust
            queried_status = JSON.parse(body)
            account[:extra] = queried_status
            queried_status["status"].to_sym
          end
      end

      accounts
    end

    def update_account(id_hash:)
      session.http_post(
        "/faggregation_queue2/#{id_hash}",
        URI.encode_www_form(commit: "更新"),
        "X-CSRF-Token" => csrf_token,
      )
    end

    def csrf_token
      body = session.http_get("/accounts")
      Nokogiri::HTML(body).at_css("meta[name='csrf-token']")[:content]
    end

    def download_csv(path:, months:)
      month = Date.today
      month -= month.day - 1 # First day of month
      months.times do
        date_string = month.strftime("%Y-%m")

        logger.info("Downloading CSV for #{date_string}")

        # FIXME: I don't really need to save the CSV files to disk anymore.
        # Maybe just return parsed CSV data?
        File.open(File.join(path, "#{date_string}.csv"), "wb") do |file|
          file << download_csv_string(date: month)
        end

        month = month.prev_month
      end
    end

    def download_csv_string(date:)
      # TODO: check if I can use more idiomatic syntax to pass query parameters
      # FIXME: handle errors/edge cases
      session
        .http_get("#{CSV_PATH}?from=#{date.strftime('%Y/%m/%d')}")
        .force_encoding(Encoding::SJIS)
        .encode(Encoding::UTF_8)
    end

    private

      attr_reader :username, :password, :logger, :base_url, :session
  end
end
