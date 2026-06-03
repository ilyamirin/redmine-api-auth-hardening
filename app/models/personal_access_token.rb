# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.

require 'digest'

class PersonalAccessToken < ApplicationRecord
  TOKEN_PREFIX = 'redmine_pat_'
  TOKEN_RANDOM_BYTES = 32
  LAST_USED_UPDATE_INTERVAL = 1.hour

  belongs_to :user

  attr_reader :plain_value

  before_validation :generate_token_digest, :on => :create

  validates :name, :token_digest, :expires_on, :presence => true
  validates :token_digest, :uniqueness => true
  validate :validate_expires_on

  scope :active, -> {where(:revoked_on => nil).where(:expires_on => Date.current..)}
  scope :expired, -> {where(:revoked_on => nil).where(:expires_on => ...Date.current)}
  scope :revoked, -> {where.not(:revoked_on => nil)}
  scope :sorted, -> {order(:created_on => :desc, :id => :desc)}

  def self.find_active_by_plaintext_token(value)
    digest = digest_value(value)
    return nil unless digest

    token = find_by(:token_digest => digest)
    return nil unless token
    return nil unless ActiveSupport::SecurityUtils.secure_compare(token.token_digest, digest)
    return nil unless token.active?
    return nil unless token.user&.active?

    token
  end

  def self.digest_value(value)
    value = value.to_s
    return nil unless value.start_with?(TOKEN_PREFIX)

    Digest::SHA256.hexdigest(value)
  end

  def self.generate_plaintext_token
    "#{TOKEN_PREFIX}#{SecureRandom.hex(TOKEN_RANDOM_BYTES)}"
  end

  def self.maximum_lifetime_days
    [Setting.personal_access_token_max_lifetime.to_i, 1].max
  end

  def self.default_expires_on
    [30, maximum_lifetime_days].min.days.from_now.to_date
  end

  def reload(*)
    @plain_value = nil
    super
  end

  def active?
    !revoked? && !expired?
  end

  def expired?
    expires_on.present? && expires_on < Date.current
  end

  def revoked?
    revoked_on.present?
  end

  def status
    if revoked?
      'revoked'
    elsif expired?
      'expired'
    else
      'active'
    end
  end

  def revoke!
    update!(:revoked_on => Time.current) unless revoked?
  end

  def touch_last_used!
    return if last_used_on.present? && last_used_on > LAST_USED_UPDATE_INTERVAL.ago

    update_column(:last_used_on, Time.current)
  end

  private

  def generate_token_digest
    return if token_digest.present?

    @plain_value = self.class.generate_plaintext_token
    self.token_digest = self.class.digest_value(@plain_value)
  end

  def validate_expires_on
    return if expires_on.blank?

    if expires_on < Date.current
      errors.add(:expires_on, 'cannot be in the past')
    end

    if expires_on > self.class.maximum_lifetime_days.days.from_now.to_date
      errors.add(:expires_on, 'exceeds the maximum lifetime')
    end
  end
end
