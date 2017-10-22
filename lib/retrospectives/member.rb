module Retrospectives
  class Member
    attr_reader :name, :username, :sheet_key, :sheet_index, :hours_spent_timesheet,
                :hours_spent_jira, :bandwidth, :days_worked

    attr_accessor :project_misc_hours, :internal_hours

    def initialize(member_hash)
      @name = member_hash[:name]
      @username = member_hash[:username]
      @sheet_key = member_hash[:sheet_key]
      @sheet_index = member_hash[:sheet_index] || 0
      @bandwidth = member_hash[:bandwidth] || 0
      @days_worked = member_hash[:days_worked] || 0

      @hours_spent_timesheet = Hash.new(0)
      @hours_spent_jira = Hash.new(0)
      @project_misc_hours = 0
      @internal_hours = 0
    end

    def expected_sps
      (@bandwidth.to_f * @days_worked.to_f * 2).round(2)
    end
  end
end
