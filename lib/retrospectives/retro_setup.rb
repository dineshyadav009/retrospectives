module Retrospectives
  class RetroSetup

    attr_reader :hours_logged, :tickets, :members, :start_date, :end_date, :google_client,
                :jira_client, :simple_jira_wrapper

    attr_accessor :sprint_delimiter_index, :hours_spent_index, :retrospective_sheet_key,
                  :ticket_id_index, :include_other_tickets, :ignore_issues_starting_with

    def initialize
      @ticket_id_index = 1
      @sprint_delimiter_index = 3
      @hours_spent_index = 4
      @include_other_tickets = false

      @members = Set.new
      @tickets = Set.new

      @ignore_issues_starting_with = Array.new
    end

    def authenticate_google_drive(config_path)
      @google_client = GoogleDrive::Session.from_config(config_path)
    end

    def authenticate_jira(options)
      @simple_jira_wrapper = JIRAWrapper.new(options)
      @jira_client = JIRA::Client.new(options)
    end

    def authenticate_simple_jira(options)
      @simple_jira_wrapper = JIRAWrapper.new(options)
    end

    # Ignored only for JIRA calls
    def ignore_issues_starting_with=(param)
      @ignore_issues_starting_with = param.split(',') if param.is_a?(String)
      @ignore_issues_starting_with = param if param.is_a?(Array)
    end

    def tickets=(tickets_array)
      return if tickets_array.nil?

      @tickets = Set.new
      tickets_array.each do |ticket|
        ticket = Utils.clean(ticket)
        @tickets.add(Ticket.new(ticket))
      end
    end

    def members=(members_array)
      return if members_array.nil?

      @members = Set.new
      validate_members_array(members_array)

      members_array.each { |member| @members.add(Member.new(member)) }
    end

    def add_ticket(ticket_id)
      return if ticket_id.nil? || ticket_already_exists(ticket_id)

      ticket_id = Utils.clean(ticket_id)
      @tickets.add(Ticket.new(ticket_id))
    end

    def add_member(member)
      return if ticket_id.nil?

      Utils.validate_params(member, [:name, :sheet_key])

      raise "This key #{member[:sheet_key]} already exists !" if key_already_exists(member)

      @members.add(Member.new(member))
    end

    def time_frame=(frame)
      raise 'Invalid time frame [Expected format \
      : \'20170102 - 20170115\']' if frame.nil? || !frame.include?('-')

      @start_date, @end_date = frame.split('-')
      @start_date = Date.parse(@start_date.strip!)
      @end_date = Date.parse(@end_date.strip!)
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
        Utils.validate_params(member, [:name, :sheet_key])
        sheet_keys.add(member[:sheet_key].strip)
      end

      raise 'Duplicate sheet key found in members array' unless sheet_keys.length == members_array.length
    end

    def key_already_exists(new_member)
      return false if @members.nil?

      @members.each do |member|
        return true if member.sheet_key == new_member[:sheet_key]
      end

      false
    end

    def ticket_already_exists(new_ticket)
      return false if @tickets.nil?

      @tickets.each do |ticket|
        return true if ticket.id == new_ticket
      end

      false
    end

    def validate_prerequisites
      raise 'Google drive not authenticated' if @google_client.nil?

      raise 'JIRA not authenticated' if @jira_client.nil?

      raise 'No members added' if @members.nil?

      raise 'Timeframe not set properly [Expected format : \'20170102 - 20170115\']' if @start_date.nil? || @end_date.nil?

      raise 'Retrospective sheet key not set ' if @retrospective_sheet_key.nil?
    end

    def generate_retro_sheet
      all_rows = Array.new

      retro_sheet = google_client.spreadsheet_by_key(retrospective_sheet_key).worksheets[0]
      headers = ['Ticket id', 'Description', 'Story type', 'Assignee', 'Status']

      @members.each { |member| headers.push("Hrs (J) [#{member.name.split('.').first}]") }
      headers.push('Total hrs (JIRA)')
      @members.each { |member| headers.push("Hrs (T) [#{member.name.split('.').first}]") }
      headers.push('Total hrs (Timesheet)')

      all_rows.push(headers)

      @tickets.to_a.each do |ticket|
        ticket_row = []
        total_hours_jira = 0.0
        total_hours_timesheet = 0.0

        ticket_row.push(ticket.id, ticket.description, ticket.type, ' ', ' ')

        @members.each do |member|
          ticket_row.push(ticket.hours_logged[member.name])
          total_hours_jira += ticket.hours_logged[member.name]
        end
        ticket_row.push(total_hours_jira)

        @members.each do |member|
          timesheet_hours_for_member = get_timesheet_hours_for(member, ticket.id)
          ticket_row.push(timesheet_hours_for_member)
          total_hours_timesheet += timesheet_hours_for_member
        end
        ticket_row.push(total_hours_timesheet)

        all_rows.push(ticket_row)
      end
      retro_sheet.update_cells(1, 1, all_rows)
      retro_sheet.save

      all_rows
    end

    def get_timesheet_hours_for(member, ticket_id)
      member.hours_spent_timesheet[ticket_id].to_f
    end
  end
end
