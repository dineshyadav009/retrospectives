module Retrospectives
  class Ticket
    attr_reader :id, :description, :type, :story_points, :status, :hours_logged

    def initialize(ticket_id)
      self.ticket_id = ticket_id
      hours_logged = Hash.new(0)
    end
  end
end
