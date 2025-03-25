# frozen_string_literal: true

module MFYNAB
  class Config
    DEFAULT_MONTHS_TO_SYNC = 3

    def initialize(hash_config, logger)
      @hash_config = hash_config
      @logger = logger
    end

    def self.from_yaml(file, logger)
      yaml_data = YAML.load_file(file)
      # Backwards compatibility: support old config files that still have a top-level key.
      # TODO: at some point (major version bump), we should probably remove this.
      unless yaml_data.key?("accounts")
        logger.warn("Top-level key in configuration file is deprecated. Please remove it.")
        yaml_data = yaml_data.values.first
      end

      raise "Invalid configuration file" unless yaml_data.key?("accounts")

      new(yaml_data, logger)
    end

    def ynab_budget
      hash_config.fetch("ynab_budget")
    end

    def months_to_sync
      hash_config.fetch("months_to_sync", DEFAULT_MONTHS_TO_SYNC)
    end

    def accounts
      hash_config.fetch("accounts", [])
    end

    private

      attr_reader :hash_config, :logger
  end
end
