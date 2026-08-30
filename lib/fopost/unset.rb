# frozen_string_literal: true

module Fopost
  # Sentinel for "the caller did not pass this", so an explicit nil can still
  # clear a field on a partial update.
  UNSET = Object.new
  def UNSET.inspect = 'Fopost::UNSET'
  def UNSET.to_s = 'Fopost::UNSET'
  UNSET.freeze
end
