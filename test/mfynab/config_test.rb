# frozen_string_literal: true

require "test_helper"
require "mfynab/config"
require "support/test_loggers"

module MFYNAB
  class ConfigTest < Minitest::Test
    include TestLoggers

    def test_from_yaml_with_top_level_key
      Tempfile.create do |file|
        file.write(<<~YAML)
          top_level_key:
            ynab_budget: "budget_id"
            accounts:
              - money_forward_name: "mf account"
                ynab_name: "ynab account"
        YAML
        file.close

        config = Config.from_yaml(file.path, memory_logger)

        assert_equal "budget_id", config.ynab_budget
        assert_includes memory_logger.messages, "Top-level key in configuration file is deprecated. Please remove it."
      end
    end

    def test_from_yaml_without_top_level_key
      Tempfile.create do |file|
        file.write(<<~YAML)
          ynab_budget: "budget_id"
          accounts:
            - money_forward_name: "mf account"
              ynab_name: "ynab account"
        YAML
        file.close

        config = Config.from_yaml(file.path, null_logger)

        assert_equal "budget_id", config.ynab_budget
      end
    end
  end
end
