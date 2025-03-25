# frozen_string_literal: true

require "nokogiri"
require "mfynab/money_forward/account_status"

module MFYNAB
  class MoneyForward
    CSV_PATH = "/cf/csv"

    def initialize(session, logger:)
      @session = session
      @logger = logger
    end

    def update_accounts(account_names, update_invalid: true)
      account_statuses = AccountStatus::Fetcher.new(session, logger: logger).fetch(account_names: account_names)

      finished = account_statuses.map do |account_status|
        ensure_account_updated(account_status, update_invalid: update_invalid)
      end.all?

      return if finished

      logger.info("Waiting for a while before checking status again...")
      # FIXME: I'm never comfortable with using sleep().
      # Do I want to implement a solution based on callbacks?
      # For example, the script could say:
      # > Accounts are out of date.
      # > I triggered the updates, and will call myself again in X seconds/minutes.
      # > When the accounts are updated, I'll proceed to the next step.
      sleep(5)
      update_accounts(account_names, update_invalid: false)
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

    # FIXME: make private or inline
    def download_csv_string(date:)
      # FIXME: handle errors/edge cases
      session
        .http_get(CSV_PATH, from: date.strftime("%Y/%m/%d"))
        .force_encoding(Encoding::SJIS)
        .encode(Encoding::UTF_8)
    end

    private

      attr_reader :session, :logger

      def ensure_account_updated(account_status, update_invalid:)
        if account_status.should_update?(update_invalid: update_invalid)
          suffix = "Will update"
          account_status.trigger_update(session)
          updated = false
        elsif account_status.key == :processing
          suffix = "Updating"
          updated = false
        elsif account_status.key == :success
          suffix = "Up to date"
          updated = true
        else
          # FIXME: we can probably handle :additional_request and/or :login right here in the script,
          # if we can find the time.
          # FIXME: sometimes, nothing can be done about the status, for example, I can currently see モバイルSUICA
          # show an `errors` status with this message:
          # ただいま大変混み合っております。今しばらくお待ちいただきますようお願いいたします。 失敗日時：02/22 14:03
          # In other words: "please wait". Maybe improve messaging?
          suffix = "Ignoring"
          updated = true
          logger.warn(account_status.invalid_state_warning)
        end

        # FIXME: I'll probably want to refresh the display instead of relogging everything every 5 seconds.
        # FIXME: would be nice to tabulate the info better, for readability.
        logger.info("#{account_status.name}:\t#{account_status.key} (#{account_status.updated_at}) - #{suffix}")

        updated
      end
  end
end
