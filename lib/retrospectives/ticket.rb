module Retrospectives
  class Ticket
    attr_accessor :id, :description, :type, :story_points, :total_story_points, :status,
                  :hours_logged, :owner, :reviewer, :is_advance_item

    def initialize(ticket_id)
      @id = ticket_id
      @hours_logged = Hash.new(0)
      @type = ' '
      @description = ''
      @is_advance_item = true
    end
  end
end
