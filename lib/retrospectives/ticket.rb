module Retrospectives
  class Ticket
    attr_accessor :id, :description, :type, :story_points, :status, :hours_logged, :owner, :reviewer

    def initialize(ticket_id)
      @id = ticket_id
      @hours_logged = Hash.new(0)
      type = ' '
    end
  end
end
