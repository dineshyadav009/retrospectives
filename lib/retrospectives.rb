require 'retrospectives/fetch_hours'
require 'retrospectives/jira_wrapper'
require 'retrospectives/member'
require 'retrospectives/retro_setup'
require 'retrospectives/ticket'
require 'retrospectives/utils'
require 'retrospectives/version'
require 'retrospectives/logger'
require 'google_drive'
require 'jira-ruby'
require 'typhoeus'
require 'logger'
require 'json'
require 'date'
require 'set'

module Retrospectives
  @@logger = Log.new

  def self.logger
    @@logger
  end
end
