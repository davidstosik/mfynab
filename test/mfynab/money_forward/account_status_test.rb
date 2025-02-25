# frozen_string_literal: true

require "test_helper"
require "mfynab/money_forward/account_status"
require "support/test_loggers"

module MFYNAB
  class MoneyForward
    class AccountStatusTest < Minitest::Test
      include TestLoggers

      def test_fetch
        # FIXME: should I use WebMock instead of relying on implementation details?
        # This would allow me to assert that the HTTP request made is correct
        # (e.g. the path, headers, cookie)
        mock_session = Minitest::Mock.new
        html = accounts_page_html(
          [
            {
              id: "account-1",
              name: "Account 1",
              updated_at: Time.new(Time.now.year, 2, 22, 13, 57),
              status: :updated,
            },
            {
              id: "account-2",
              name: "Account 2",
              updated_at: Time.new(Time.now.year, 2, 22, 15, 37),
              status: :updating,
            },
          ],
        )
        mock_session.expect(:http_get, html, ["/accounts"])

        fetcher = AccountStatus::Fetcher.new(mock_session, logger: null_logger)
        accounts = fetcher.fetch(account_names: ["Account 1", "Account 2"])

        assert_equal 2, accounts.size
        assert_equal ["Account 1", "Account 2"], accounts.map(&:name)
        assert_equal %i[success processing], accounts.map(&:key)

        expected_date = Time.new(Time.now.year, 2, 22, 13, 57)

        assert_equal expected_date, accounts[0].updated_at
      end

      def test_fetch_ignores_unwanted_accounts
        mock_session = Minitest::Mock.new
        html = accounts_page_html(
          [
            {
              id: "account-1",
              name: "Account 1",
              updated_at: Time.new(Time.now.year, 2, 22, 13, 57),
              status: :updated,
            },
            {
              id: "account-2",
              name: "Account 2",
              updated_at: Time.new(Time.now.year, 2, 22, 15, 37),
              status: :updating,
            },
          ],
        )
        mock_session.expect(:http_get, html, ["/accounts"])

        fetcher = AccountStatus::Fetcher.new(mock_session, logger: null_logger)
        accounts = fetcher.fetch(account_names: ["Account 1"])

        assert_equal 1, accounts.size
        assert_equal "Account 1", accounts.first.name
      end

      def test_fetch_with_additional_request
        mock_session = Minitest::Mock.new
        html = accounts_page_html(
          [
            {
              id: "account-1",
              name: "Account 1",
              updated_at: Time.new(Time.now.year, 2, 22, 13, 57),
              status: :errors,
            },
          ],
        )
        json = { "loading" => false, "status" => "errors", "message" => "error message" }.to_json
        # FIXME: should I use WebMock instead of relying on implementation details?

        mock_session.expect(:http_get, html, ["/accounts"])
        additional_query_mock = mock_session.expect(:http_get, json, ["/accounts/polling/account-1"])

        fetcher = AccountStatus::Fetcher.new(mock_session, logger: null_logger)
        accounts = fetcher.fetch(account_names: ["Account 1"])

        additional_query_mock.verify

        assert_equal 1, accounts.size
        account = accounts.first

        assert_equal "Account 1", account.name
        assert_equal :errors, account.key
        assert_equal "error message", account.message
      end

      private

        def accounts_page_html(accounts)
          html = +<<~HTML
            <section class="accounts">
              <section class="common-account-table-container">
                <table>
                  <tr>
                    <th>金融機関</th>
                    <th>登録日（最終取得日）</th>
                    <th>更新状態</th>
                  </tr>
          HTML
          accounts.each do |account|
            html << <<~HTML
              <tr id="#{account[:id]}">
                <td class="service">
                  #{account[:name]}
                </td>
                <td class="created">2023/09/20 (#{account[:updated_at].strftime('%m/%d %H:%M')})</td>
                <td class="account-status">
                  <span id="js-#{'hidden-' unless account[:status] == :updated}status-sentence-1-updated">正常</span>
                  <span id="js-#{'hidden-' unless account[:status] == :updating}status-sentence-1-updating">更新中</span>
                </td>
              </tr>
            HTML
          end
          html << <<~HTML
                </table>
              </section>
            </section>
          HTML
        end
    end
  end
end
