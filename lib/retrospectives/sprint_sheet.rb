module Retrospectives
  class SprintSheet
    # required fields from sprint sheet and their indices
    attr_accessor :indices, :sheet_key, :sheet_title, :retro_obj, :sheet_obj, :fields

    KEY_INDEX = 0
    SUMMARY_INDEX = 1
    TYPE_INDEX = 2
    STATUS_INDEX = 3
    TICKET_OWNER_INDEX = 4
    TICKET_REVIEWER_INDEX = 5
    SPS_INDEX = 6

    def initialize(retro, key, title)
      @retro_obj = retro
      @sheet_key = key
      @sheet_title = title

      # Don't alter the order of fields. If you need to, update the constants ending with '_INDEX'
      @fields = ['Key', 'Summary', 'Type', 'Status', 'Ticket owner', 'Reviewer',  'Assigned SPs']

      parse_sheet_info
      parse_indices
    end

    def parse_data
      tickets = Array.new

      (2..@sheet_obj.max_rows).each do |row|
        key = @sheet_obj[row, @indices[@fields[KEY_INDEX]]]
        summary = @sheet_obj[row, @indices[@fields[SUMMARY_INDEX]]]
        type = @sheet_obj[row, @indices[@fields[TYPE_INDEX]]]
        status = @sheet_obj[row, @indices[@fields[STATUS_INDEX]]]
        sp = @sheet_obj[row, @indices[@fields[SPS_INDEX]]]
        owner = @sheet_obj[row, @indices[@fields[TICKET_OWNER_INDEX]]]
        reviewer = @sheet_obj[row, @indices[@fields[TICKET_REVIEWER_INDEX]]]

        next if key.empty?

        ticket = Ticket.new(key)
        ticket.description = summary
        ticket.status = status
        ticket.story_points = sp
        ticket.owner = owner
        ticket.type = type
        ticket.reviewer = reviewer

        tickets.push(ticket)
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

    def parse_indices
      raise "Sheet not initialized properly" if @sheet_obj.nil?

      @indices = Hash.new(0)
      max_cols = @sheet_obj.max_cols

      (1..max_cols).each do |col|
        cell_data = @sheet_obj[1, col]

        next if cell_data.empty?

        @fields.each_with_index do |f, index|
          if cell_data.gsub("\n", ' ').downcase.include?(f.downcase)
            @indices[cell_data] = index + 1
            break
          end
        end
      end

      unless @fields.length == @indices.keys.length
        raise "Indices not populated, check field names in sheet \n #{@fields.inspect}"
      end
    end
  end
end
