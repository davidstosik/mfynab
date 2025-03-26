# frozen_string_literal: true

require "debug"
require "minitest/autorun"
require "webmock/minitest"

require "mfynab/money_forward/session"

MFYNAB::MoneyForward::Session.cookie_cache_backend = Class.new do
  def initialize(_); end

  def fetch
    yield
  end

  def write_to_cache(_); end
end
