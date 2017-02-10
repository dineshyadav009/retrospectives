module Retrospectives
  class JIRAWrapper
    attr_reader   :username, :password, :domain, :auth
    attr_accessor :debug

    JIRA_ISSUE_API = '/rest/api/2/issue/'
    WORKLOG_PATH = '/worklog'
    HEADERS = {'content-type' => 'application/json'}

    def initialize(options)
      @username = options[:username]
      @password = options[:password]
      @auth     = @username + ':' + @password
      @domain   = options[:site]
      @debug    = options[:debug]
    end

    def add_worklog(params, ticket_id)
      raise "params empty" if(params.nil? || params.empty?)

      url = @domain + JIRA_ISSUE_API + ticket_id + WORKLOG_PATH

      begin
        resp = Typhoeus::Request.post(url, body: params.to_json, headers: HEADERS, userpwd: @auth)
        puts "Response code for #{ticket_id} : #{resp.code}" if @debug
        resp
      rescue StandardError => e
        puts "Exception #{e.message} for #{ticket_id}"
      end
    end

    def update_custom_field(params, ticket_id)
      raise "params empty" if(params.nil? || params.empty?)

      url = @domain + JIRA_ISSUE_API + ticket_id
      request_params = {'fields' => params}

      begin
        resp = Typhoeus::Request.put(url, body: request_params.to_json, headers: HEADERS, userpwd: @auth)
        puts "Response code for #{ticket_id} : #{resp.code}" if @debug
        resp
      rescue StandardError => e
        puts "Exception #{e.message} for #{ticket_id}"
      end
    end

    def update_assignee(new_assignee, ticket_id)
      raise 'new assignee cannot be nil' if new_assignee.nil?

      params = {'assignee' => {'name' => new_assignee}}
      update_custom_field(params, ticket_id)
    end

    def get_worklog(ticket_id)
      raise 'ticket_id cannot be nil' if ticket_id.nil?

      url = @domain + JIRA_ISSUE_API + ticket_id + WORKLOG_PATH

      begin
        resp = Typhoeus::Request.get(url, headers: HEADERS, userpwd: @auth)
        puts "Response code for #{ticket_id} : #{resp.code}" if @debug
        JSON.parse(resp.body)
      rescue StandardError => e
        puts "Exception #{e.message} for #{ticket_id}"
      end
    end
  end
end
