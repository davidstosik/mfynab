# frozen_string_literal: true

require "ferrum"
require "net/http"
require "nokogiri"
require "uri"

module MFYNAB
  class MoneyForward
    class AccountStatus
      class Fetcher
        def initialize(session, logger:)
          @logger = logger
          @session = session
        end

        def fetch(account_names:)
          logger.info("Checking Money Forward accounts status")
          html = session.http_get("/accounts")
          table_rows_selector = "section.accounts section.common-account-table-container > table > tr[id]"
          Nokogiri::HTML(html).css(table_rows_selector).filter_map do |node|
            account = parse_html_table_row(node)
            next unless account_names.include?(account.name)

            status_data = determine_status_data(account)
            account.assign_status_data(**status_data)

            account
          end
        end

        private

          attr_reader :session, :logger

          def determine_status_data(account)
            case account.raw_status
            when "正常" then { key: :success }
            when "更新中" then { key: :processing }
            else
              body = session.http_get("/accounts/polling/#{account.id_hash}")
              # JSON format:
              #  - loading: boolean
              #  - message: Japanese text
              #  - status: success, processing, additional_request, errors, important_announcement,
              #            invalid_password, login, suspended
              # FIXME: make more robust
              queried_status = JSON.parse(body)
              {
                key: queried_status["status"].to_sym,
                message: queried_status["message"],
              }
            end
          end

          def parse_html_table_row(node)
            AccountStatus.new(
              id_hash: node[:id],
              name: node.xpath("td").first.text.lines[1].strip,
              raw_status: node.css("td.account-status>span:not([id*='hidden'])").text.strip,
              # FIXME: can this be a little more robust?
              #  - this should not depend on the timezone the server is running in
              #  - this should explicitly fail if parsing is not possible
              #  - what if it's January 1st and last update was last year?
              updated_at: Time.parse(node.css("td.created").text[/(?<=\().*?(?=\))/]),
            )
          end
      end

      FRESHNESS_LIMIT = 24 * 60 * 60 # 1 day

      attr_reader :id_hash, :name, :raw_status, :updated_at, :key, :message

      def initialize(id_hash:, name:, raw_status:, updated_at:)
        @id_hash = id_hash
        @name = name
        @raw_status = raw_status
        @updated_at = updated_at
      end

      def assign_status_data(key:, message: nil)
        @key = key
        @message = message
      end

      def invalid_state_warning
        warning = "The Money Forward account named #{name} is in an invalid state: #{key}"
        warning << " (#{message})" if message
        warning << ". Please handle the issue manually to resume syncing."
      end

      def outdated?
        # Require accounts to have been updated in the last day
        # FIXME: make configurable?
        updated_at < Time.now - FRESHNESS_LIMIT
      end

      def trigger_update(session)
        session.http_post(
          "/faggregation_queue2/#{id_hash}",
          URI.encode_www_form(commit: "更新"),
          "X-CSRF-Token" => session.csrf_token,
        )
      end
    end
  end
end
