module Retrospectives
  class RetroSetup

    attr_reader :hours_logged, :members, :start_date, :end_date, :google_client,
                :jira_client, :simple_jira_wrapper

    attr_accessor :tickets, :sprint_delimiter_index, :hours_spent_index, :retrospective_sheet_key,
                  :ticket_id_index, :include_other_tickets, :ignore_issues_starting_with,
                  :sprint_id, :sprint_sheet_obj

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

    def get_tickets_from_sprint_sheet(sheet_key, sheet_title)
      @sprint_sheet_obj = SprintSheet.new(self, sheet_key, sheet_title)
    end

    def add_tickets(tickets_array)
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

      sdate, edate = frame.split('-')
      @start_date = Date.parse(sdate.strip!)
      @end_date = Date.parse(edate.strip!)
    end

    def generate!
      validate_prerequisites!

      Retrospectives::logger.info('Validated Prerequisites')

      unless @sprint_sheet_obj.nil?
        @sprint_sheet_obj.parse_data
        Retrospectives::logger.info('Fetched tickets from sprint sheet')
      end

      FetchHours.from_timesheet(self)
      Retrospectives::logger.info('Fetched data from timesheet')

      FetchHours.from_jira(self)
      Retrospectives::logger.info('Fetched data from JIRA')

      generate_retro_sheet_tickets
      generate_retro_sheet_summary

      Retrospectives::logger.info('Generated retrospective sheet, CTRL + Click to view')
      Retrospectives::logger.info(get_sheet(@retrospective_sheet_key, 0).human_url)
    end

    def validate_members_array(members_arr)
      s_keys = Set.new

      members_arr.each do |member|
        Utils.validate_params(member, [:name, :sheet_key])
        s_keys.add(member[:sheet_key].strip)
      end

      raise 'Duplicate sheet key found in members array' unless s_keys.length == members_arr.length
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

    def validate_prerequisites!
      raise 'Google drive not authenticated' if @google_client.nil?

      raise 'JIRA not authenticated' if @jira_client.nil?

      raise 'No members added' if @members.nil?

      raise 'Timeframe not set properly [Expected format : \'20170102 - 20170115\']' if @start_date.nil? || @end_date.nil?

      raise 'Retrospective sheet key not set ' if @retrospective_sheet_key.nil?
    end

    def generate_retro_sheet_tickets
      all_rows = Array.new

      retro_sheet = get_sheet(@retrospective_sheet_key, 0)
      # headers = ['Ticket id', 'Description', 'Story type', 'Story points', 'Owner',
      #            'Participants', 'Owner hours', 'Status', 'Comments']

      # headers.push('Total hrs (JIRA)')
      # headers.push('Total hrs (Timesheet)')

      # #@members.each { |member| headers.push("Hrs (J) [#{member.name.split('.').first}]") }

      # @members.each { |member| headers.push("Hrs (T) [#{member.name.split('.').first}]") }

      # all_rows.push(headers)

      @tickets.to_a.each do |ticket|
        ticket_row = []
        total_hours_jira = 0.0
        total_hours_timesheet = 0.0
        member_hours_jira = []
        member_hours_timesheet = []
        participants = Hash.new(0)

        ticket_row.push(ticket.id, ticket.description, ticket.type, ticket.story_points)

        @members.each do |member|
          member_hours_jira.push(member.hours_spent_jira[ticket.id].round(2) || 0)
          total_hours_jira += member.hours_spent_jira[ticket.id]
        end

        @members.each do |member|
          timesheet_hours_for_member = get_timesheet_hours_for(member, ticket.id)
          member_hours_timesheet.push(timesheet_hours_for_member.round(2) || 0)
          total_hours_timesheet += timesheet_hours_for_member

          participants[member.name] = timesheet_hours_for_member unless timesheet_hours_for_member.to_f.zero?
        end

        owner = ticket.owner

        ticket_row.push(owner)
        ticket_row.push(participants.keys.join(', '))
        ticket_row.push(ticket.hours_logged[owner])
        ticket_row.push(ticket.status)

        ticket_row.push('') # Comments

        ticket_row.push(total_hours_jira.round(2) || 0)
        ticket_row.push(total_hours_timesheet.round(2) || 0)

        # 3 black cells before we put individual hours
        ticket_row.push('')
        ticket_row.push('')
        ticket_row.push('')

        ticket_row.push(*member_hours_jira)
        ticket_row.push(*member_hours_timesheet)

        all_rows.push(ticket_row)
      end

      retro_sheet.update_cells(26, 1, all_rows)
      retro_sheet.save
    end

    # Hardcoded logic (for rows), should not be in the gem
    def generate_retro_sheet_summary
      retro_sheet = get_sheet(@retrospective_sheet_key, 0)
      retro_sheet.update_cells(3, 4, [[@sprint_id, @start_date.to_s, (@end_date - 1).to_s]])

      @members.each_with_index do |member, index|
        row = [member.name, '-', '-', member.hours_spent_timesheet.values.inject(:+), '-',
               member.expected_sps]
        retro_sheet.update_cells(8 + index, 4, [row])
      end

      retro_sheet.save
    end

    def get_timesheet_hours_for(member, ticket_id)
      member.hours_spent_timesheet[ticket_id].to_f
    end

    def get_sheet(sheet_key, index)
      @google_client.spreadsheet_by_key(sheet_key).worksheets[index]
    end

    def get_sheets(sheet_key)
      @google_client.spreadsheet_by_key(sheet_key).worksheets
    end

    def get_tickets(sheet)
      (2..100).each do |row|
        next unless sheet[row, 1].include?('-')

        @tickets.add(Ticket.new(sheet[row, 1]))
      end

      @tickets
    end
  end
end
