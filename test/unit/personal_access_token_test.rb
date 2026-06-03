# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require_relative '../test_helper'

class PersonalAccessTokenTest < ActiveSupport::TestCase
  def setup
    User.current = nil
  end

  test "create should generate a plaintext value and store only its digest" do
    token =
      PersonalAccessToken.create!(
        :user => User.find(2),
        :name => 'CI integration',
        :expires_on => 30.days.from_now.to_date
      )

    assert_match(/\Aredmine_pat_[a-f0-9]{64}\z/, token.plain_value)
    assert_equal 64, token.token_digest.length
    assert_not_equal token.plain_value, token.token_digest
    assert_nil PersonalAccessToken.find_by(:token_digest => token.plain_value)

    token.reload
    assert_nil token.plain_value
  end

  test "find_active_by_plaintext_token should return active token" do
    token =
      PersonalAccessToken.create!(
        :user => User.find(2),
        :name => 'Build bot',
        :expires_on => 30.days.from_now.to_date
      )
    plain_value = token.plain_value

    assert_equal token, PersonalAccessToken.find_active_by_plaintext_token(plain_value)
  end

  test "find_active_by_plaintext_token should return nil for expired token" do
    token =
      PersonalAccessToken.create!(
        :user => User.find(2),
        :name => 'Expired bot',
        :expires_on => 30.days.from_now.to_date
      )
    plain_value = token.plain_value
    token.update_column(:expires_on, Date.yesterday)

    assert_nil PersonalAccessToken.find_active_by_plaintext_token(plain_value)
  end

  test "find_active_by_plaintext_token should return nil for revoked token" do
    token =
      PersonalAccessToken.create!(
        :user => User.find(2),
        :name => 'Revoked bot',
        :expires_on => 30.days.from_now.to_date
      )
    plain_value = token.plain_value
    token.revoke!

    assert_nil PersonalAccessToken.find_active_by_plaintext_token(plain_value)
  end

  test "find_active_by_plaintext_token should return nil for locked user" do
    user = User.find(5)
    token =
      PersonalAccessToken.create!(
        :user => user,
        :name => 'Locked user bot',
        :expires_on => 30.days.from_now.to_date
      )

    assert_nil PersonalAccessToken.find_active_by_plaintext_token(token.plain_value)
  end

  test "expires_on should be mandatory" do
    token = PersonalAccessToken.new(:user => User.find(2), :name => 'No expiry')

    assert_not token.valid?
    assert_match(/blank/, token.errors[:expires_on].join)
  end

  test "expires_on should not be in the past" do
    token =
      PersonalAccessToken.new(
        :user => User.find(2),
        :name => 'Past expiry',
        :expires_on => Date.yesterday
      )

    assert_not token.valid?
    assert_includes token.errors[:expires_on], 'cannot be in the past'
  end

  test "expires_on should not exceed admin maximum lifetime" do
    with_settings :personal_access_token_max_lifetime => '10' do
      token =
        PersonalAccessToken.new(
          :user => User.find(2),
          :name => 'Too long',
          :expires_on => 11.days.from_now.to_date
        )

      assert_not token.valid?
      assert_includes token.errors[:expires_on], 'exceeds the maximum lifetime'
    end
  end

  test "status helpers should distinguish active expired and revoked tokens" do
    active =
      PersonalAccessToken.create!(
        :user => User.find(2),
        :name => 'Active',
        :expires_on => 30.days.from_now.to_date
      )
    expired =
      PersonalAccessToken.create!(
        :user => User.find(2),
        :name => 'Expired',
        :expires_on => 30.days.from_now.to_date
      )
    expired.update_column(:expires_on, Date.yesterday)
    revoked =
      PersonalAccessToken.create!(
        :user => User.find(2),
        :name => 'Revoked',
        :expires_on => 30.days.from_now.to_date
      )
    revoked.revoke!

    assert active.active?
    assert expired.expired?
    assert revoked.revoked?
    assert_equal 'active', active.status
    assert_equal 'expired', expired.status
    assert_equal 'revoked', revoked.status
  end

  test "status scopes should be exclusive" do
    active =
      PersonalAccessToken.create!(
        :user => User.find(2),
        :name => 'Active',
        :expires_on => 30.days.from_now.to_date
      )
    expired =
      PersonalAccessToken.create!(
        :user => User.find(2),
        :name => 'Expired',
        :expires_on => 30.days.from_now.to_date
      )
    expired.update_column(:expires_on, Date.yesterday)
    revoked =
      PersonalAccessToken.create!(
        :user => User.find(2),
        :name => 'Revoked',
        :expires_on => 30.days.from_now.to_date
      )
    revoked.revoke!

    assert_includes PersonalAccessToken.active, active
    assert_includes PersonalAccessToken.expired, expired
    assert_includes PersonalAccessToken.revoked, revoked
    assert_not_includes PersonalAccessToken.expired, revoked
  end

  test "touch_last_used should update last_used_on at most once per hour" do
    token =
      PersonalAccessToken.create!(
        :user => User.find(2),
        :name => 'Observed',
        :expires_on => 30.days.from_now.to_date
      )

    travel_to Time.zone.local(2026, 6, 3, 10, 0, 0) do
      assert_changes -> {token.reload.last_used_on} do
        token.touch_last_used!
      end
    end
    first_used_on = token.reload.last_used_on

    travel_to first_used_on + 30.minutes do
      assert_no_changes -> {token.reload.last_used_on} do
        token.touch_last_used!
      end
    end

    travel_to first_used_on + 61.minutes do
      assert_changes -> {token.reload.last_used_on} do
        token.touch_last_used!
      end
    end
  end
end
