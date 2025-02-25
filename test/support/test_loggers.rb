# frozen_string_literal: true

module MFYNAB
  module TestLoggers
    def null_logger
      @_null_logger ||= Logger.new(File::NULL)
    end
  end
end
