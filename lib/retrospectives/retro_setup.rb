module Retrospectives
  class RetroSetup


    attr_reader :hours_logged, :tickets, :members, :start_time, :end_time, :retrospective_sheet_key,
                :google_client, :jira_client, :sprint_delimiter_index, :hours_spent_index,
                :ticket_id_index, :include_other_tickets

    def initialize
      ticket_id_index = 1
      sprint_delimiter_index = 3
      hours_spent_index = 4
      include_other_tickets = false

      members = Set.new
      tickets = Set.new
    end

    def authenticate_google_drive(config_path)
      google_client = GoogleDrive::Session.from_config(config_path)
    end

    def authenticate_jira(options)
      jira_client = JIRA::Client.new(options)
    end

    def tickets=(tickets_array)
      return if tickets_array.nil?

      tickets = Set.new
      tickets_array.each { |ticket| tickets.add(Utils.clean(Ticket.new(ticket))) }
    end

    def members=(members_array)
      return if members_array.nil?

      members = Set.new
      validate_members_array(members_array)

      members_array.each { |member| members.add(Member.new(member)) }
    end

    def add_ticket(ticket_id)
      return if ticket_id.nil?

      tickets.add(Utils.clean(new Ticket(ticket)))
    end

    def add_member(member)
      Utils.validate_params(member, :name, :sheet_key)

      raise "This key #{member[:sheet_key]} already exists !" if key_already_exists(member)

      members.add(Member.new(member))
    end

    def time_frame(frame)
      raise 'Invalid time frame [Expected format \
      : \'20170102 - 20170115\']' if frame.nil? || !frame.include('-')

      start_time, end_time = frame.split('-')
      start_time.strip!
      end_time.strip!
    end

    def generate!
      validate_prerequisites

      FetchHours.from_timesheet(self)
      FetchHours.from_jira(self)

      generate_retro_sheet
    end


    private

    def validate_members_array(members_array)
      sheet_keys = Set.new

      members_array.each do |member|
        Utils.validate_params(member, :name, :sheet_key)
        sheet_keys.add(member[:sheet_key].strip)
      end

      raise 'Duplicate sheet key found in members \
      array' unless sheet_keys.length != members_array.length
    end

    def key_already_exists(new_member)
      return false if members.nil?

      members.each do |member|
        return true if member.sheet_key == new_member[:sheet_key]
      end

      false
    end

    def validate_prerequisites
      raise 'Google drive not authenticated' if google_client.nil?

      raise 'JIRA not authenticated' if jira_client.nil?

      raise 'No members added' if members.nil?

      raise 'Timeframe not set properly [Expected format : \'20170102 - 20170115\']'

      raise 'Retrospective sheet key not set ' if retrospective_sheet_key.nil?
    end

    def generate_retro_sheet

    end
  end
end
