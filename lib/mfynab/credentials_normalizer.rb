# frozen_string_literal: true

module MFYNAB
  class CredentialsNormalizer
    def initialize(hash_config, logger)
      @hash_config = hash_config
      @logger = logger
    end

    def normalize
      config = hash_config["credentials"]
      if config.nil?
        logger.warn("No credentials found in configuration file. Please update your configuration file.")
        # This provides backwards compatibility with old configuration files
        # that did not include the new credentials.
        # TODO: at some point (major version bump), we should probably remove this.
        return {
          "ynab_access_token" => ENV.fetch("YNAB_ACCESS_TOKEN"),
          "moneyforward_username" => ENV.fetch("MONEYFORWARD_USERNAME"),
          "moneyforward_password" => ENV.fetch("MONEYFORWARD_PASSWORD"),
        }
      end

      config.transform_values { normalize_credential(_1) }
    end

    private

      attr_reader :hash_config, :logger

      def normalize_credential(value)
        case value
        when String
          value
        when Hash
          if !value.key?("type") || value["type"] == "literal"
            value.fetch("value")
          elsif value["type"] == "env"
            ENV.fetch(value.fetch("value"))
          else
            raise "Unknown credential type: #{value['type']}"
          end
        else
          raise "Unknown credential type: #{value.class}"
        end
      end
  end
end
