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

class AdminController < ApplicationController
  layout 'admin'
  self.main_menu = false
  menu_item :projects, :only => :projects
  menu_item :plugins, :only => :plugins
  menu_item :info, :only => :info
  menu_item :personal_access_tokens, :only => :personal_access_tokens

  before_action :require_admin
  require_sudo_mode :revoke_personal_access_token

  helper :queries
  include QueriesHelper
  helper :projects_queries
  helper :projects

  def index
    @no_configuration_data = Redmine::DefaultData::Loader::no_data?
  end

  def projects
    retrieve_query(ProjectAdminQuery, false, :defaults => @default_columns_names)
    @entry_count = @query.result_count
    @entry_pages = Paginator.new @entry_count, per_page_option, params['page']
    @projects = @query.results_scope(:limit => @entry_pages.per_page, :offset => @entry_pages.offset).to_a

    render :action => "projects", :layout => false if request.xhr?
  end

  def plugins
    @plugins = Redmine::Plugin.all
  end

  def personal_access_tokens
    @status = personal_access_token_status_param
    @personal_access_tokens =
      personal_access_tokens_scope(@status).includes(:user).sorted
  end

  def revoke_personal_access_token
    token = PersonalAccessToken.find(params[:id])
    token.revoke!
    flash[:notice] = l(:notice_personal_access_token_revoked)
    redirect_to admin_personal_access_tokens_path
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  # Loads the default configuration
  # (roles, trackers, statuses, workflow, enumerations)
  def default_configuration
    if request.post?
      begin
        Redmine::DefaultData::Loader::load(params[:lang])
        flash[:notice] = l(:notice_default_data_loaded)
      rescue => e
        flash[:error] = l(:error_can_t_load_default_data, ERB::Util.h(e.message))
      end
    end
    redirect_to admin_path
  end

  def test_email
    begin
      Mailer.deliver_test_email(User.current)
      flash[:notice] = l(:notice_email_sent, ERB::Util.h(User.current.mail))
    rescue => e
      flash[:error] = l(:notice_email_error, ERB::Util.h(Redmine::CodesetUtil.replace_invalid_utf8(e.message.dup)))
    end
    redirect_to settings_path(:tab => 'notifications')
  end

  def info
    @checklist = [
      [:text_default_administrator_account_changed, User.default_admin_account_changed?],
      [:text_file_repository_writable, File.writable?(Attachment.storage_path)],
      [:text_all_migrations_have_been_run, !ActiveRecord::Base.connection.pool.migration_context.needs_migration?],
      [:text_minimagick_available,     Object.const_defined?(:MiniMagick)],
      [:text_convert_available,        Redmine::Thumbnail.convert_available?],
      [:text_gs_available,             Redmine::Thumbnail.gs_available?]
    ]
    @checklist << [:text_default_active_job_queue_changed, Rails.application.config.active_job.queue_adapter != :async] if Rails.env.production?
  end

  private

  def personal_access_token_status_param
    status = params[:status].presence || 'active'
    %w[active expired revoked all].include?(status) ? status : 'active'
  end

  def personal_access_tokens_scope(status)
    case status
    when 'expired'
      PersonalAccessToken.expired
    when 'revoked'
      PersonalAccessToken.revoked
    when 'all'
      PersonalAccessToken.all
    else
      PersonalAccessToken.active
    end
  end
end
