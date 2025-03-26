# frozen_string_literal: true

module MFYNAB
  module TestLoggers
    class MemoryLogger < Logger
      def initialize
        @log = StringIO.new
        super(@log)
      end

      def messages
        @log.string
      end
    end

    def null_logger
      @_null_logger ||= Logger.new(File::NULL)
    end

    def memory_logger
      @_memory_logger ||= MemoryLogger.new
    end
  end
end
