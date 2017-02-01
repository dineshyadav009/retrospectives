module Retrospectives
  class Member
    attr_reader :name, :sheet_key, :sheet_index, :hours_spent_timesheet, :hours_spent_jira

    def initialize(member_hash)
      @name = member_hash[:name]
      @sheet_key = member_hash[:sheet_key]
      @sheet_index = member_hash[:sheet_index] || 0

      @hours_spent_timesheet = Hash.new(0)
      @hours_spent_jira = Hash.new(0)
    end
  end
end
