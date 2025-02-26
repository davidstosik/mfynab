# frozen_string_literal: true

module MFYNAB
  class MoneyForward
    CSV_PATH = "/cf/csv"

    def initialize(session, logger:)
      @session = session
      @logger = logger
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
      # FIXME: handle errors/edge cases
      session
        .http_get(CSV_PATH, from: date.strftime("%Y/%m/%d"))
        .force_encoding(Encoding::SJIS)
        .encode(Encoding::UTF_8)
    end

    private

      attr_reader :session, :logger
  end
end
