# frozen_string_literal: true

require "json"

module MFYNAB
  class MoneyForward
    class CookieCache
      PATH_PREFIX = File.join(Dir.home, ".config", "mfynab", "cookie_cache")

      def initialize(username)
        @username = username
      end

      def fetch
        self.cookie ||= read_from_cache
        # FIXME: check if the cookie expired
        return cookie if cookie

        yield.tap do |cookie|
          write_to_cache(cookie)
        end
      end

      def write_to_cache(cookie)
        self.cookie = cookie
        FileUtils.mkdir_p(File.dirname(path))

        File.write(path, JSON.dump(cookie))
      end

      private

        attr_reader :username
        attr_accessor :cookie

        def read_from_cache
          return unless File.exist?(path)

          JSON.parse(File.read(path))
        end

        def path
          File.join(PATH_PREFIX, "#{username}.json")
        end
    end
  end
end
