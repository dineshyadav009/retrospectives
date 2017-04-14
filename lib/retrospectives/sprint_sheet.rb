module Retrospectives
  class SprintSheet
    # required fields from sprint sheet and their indices
    attr_accessor :indices, :sheet_key, :sheet_title, :retro_obj, :sheet_obj, :fields, :key_index,
                  :summary_index, :type_index, :status_index, :ticket_owner_index,
                  :ticket_reviewer_index, :story_points_index


    def initialize(retro, key, title)
      @retro_obj = retro
      @sheet_key = key
      @sheet_title = title

      # fields are indexed from '1' in a google worksheet
      @key_index = 1
      @summary_index = 2
      @type_index = 3
      @status_index = 4
      @ticket_owner_index = 5
      @ticket_reviewer_index = 6
      @story_points_index = 7

      parse_sheet_info
    end

    def parse_data
      tickets = Set.new

      (2..@sheet_obj.max_rows).each do |row|
        key = @sheet_obj[row, key_index]
        summary = @sheet_obj[row, summary_index]
        type = @sheet_obj[row, type_index]
        status = @sheet_obj[row, status_index]
        sp = @sheet_obj[row, story_points_index]
        owner = @sheet_obj[row, ticket_owner_index]
        reviewer = @sheet_obj[row, ticket_reviewer_index]

        next if key.empty?

        ticket = Ticket.new(key)
        ticket.description = summary
        ticket.status = status
        ticket.story_points = sp
        ticket.owner = owner
        ticket.type = type
        ticket.reviewer = reviewer

        tickets.add(ticket)
      end
      @retro_obj.tickets = tickets
    end

    private

    def parse_sheet_info
      sheets = @retro_obj.get_sheets(@sheet_key)
      sheets.each_with_index do |sheet|
        @sheet_obj = sheet if sheet.title.downcase == @sheet_title.downcase
      end

      raise "Invalid title. No sheet found with name '#{@sheet_title}'" if @sheet_obj.nil?
    end
  end
end
