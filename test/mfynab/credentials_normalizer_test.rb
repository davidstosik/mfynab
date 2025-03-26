# frozen_string_literal: true

require "test_helper"
require "mfynab/credentials_normalizer"
require "support/test_loggers"

module MFYNAB
  class CredentialsNormalizerTest < Minitest::Test
    include TestLoggers

    def test_backwards_compatibility_with_old_configuration_files
      mock_env_credentials do
        normalized = CredentialsNormalizer.new({}, memory_logger).normalize

        assert_equal(expected_credentials, normalized)
        assert_includes(
          memory_logger.messages,
          "No credentials found in configuration file. Please update your configuration file.",
        )
      end
    end

    def test_literal_credentials
      hash_config = {
        "credentials" => {
          "ynab_access_token" => {
            "type" => "literal",
            "value" => "expected_ynab_access_token",
          },
          "moneyforward_username" => "expected_moneyforward_username",
          "moneyforward_password" => "expected_moneyforward_password",
        },
      }
      normalized = CredentialsNormalizer.new(hash_config, null_logger).normalize

      assert_equal(expected_credentials, normalized)
    end

    def test_env_var_credentials
      mock_env_credentials do
        hash_config = {
          "credentials" => {
            "ynab_access_token" => {
              "type" => "env",
              "value" => "YNAB_ACCESS_TOKEN",
            },
            "moneyforward_username" => {
              "type" => "env",
              "value" => "MONEYFORWARD_USERNAME",
            },
            "moneyforward_password" => {
              "type" => "env",
              "value" => "MONEYFORWARD_PASSWORD",
            },
          },
        }
        normalized = CredentialsNormalizer.new(hash_config, null_logger).normalize

        assert_equal(expected_credentials, normalized)
      end
    end

    private

      def expected_credentials
        {
          "ynab_access_token" => "expected_ynab_access_token",
          "moneyforward_username" => "expected_moneyforward_username",
          "moneyforward_password" => "expected_moneyforward_password",
        }
      end

      def mock_env_credentials
        old_env = ENV.to_h

        ENV.update(
          "YNAB_ACCESS_TOKEN" => "expected_ynab_access_token",
          "MONEYFORWARD_USERNAME" => "expected_moneyforward_username",
          "MONEYFORWARD_PASSWORD" => "expected_moneyforward_password",
        )

        yield
      ensure
        ENV.replace(old_env)
      end
  end
end
