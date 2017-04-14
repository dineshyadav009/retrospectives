module Retrospectives
  class FetchHours
    def self.from_timesheet(retro)
      retro.members.each do |member|
        sheet = retro.google_client.spreadsheet_by_key(member.sheet_key).
        worksheets[member.sheet_index]

        start_date_column, end_date_column = get_start_and_end_date_columns(sheet, retro)

        if start_date_column.nil? || end_date_column.nil?
          Retrospectives::logger.debug("start, end col vals : #{start_date_column}, #{end_date_column}")
          raise "Incorrect dates marked or timesheet not completed for #{member.name}"
        end

        (start_date_column..end_date_column).each do |column|
          (1..sheet.max_rows).each do |row|
            value = sheet[row, column]
            input_value = sheet.input_value(row, column)

            next if input_value.include?('=SUM') || input_value.blank?

            ticket_id = Utils.clean(sheet[row, retro.ticket_id_index])
            hours_spent = Utils.clean(input_value).to_f.round(2)

            next if ticket_id.nil? || ticket_id.empty?

            if retro.include_other_tickets || retro_tickets_include?(retro, ticket_id)
              member.hours_spent_timesheet[ticket_id] += hours_spent
              retro.add_ticket(ticket_id) if retro.include_other_tickets
            end
          end
        end
      end
    end

    def self.from_jira(retro)
      retro.tickets.each do |ticket|
        retry_attempts = 0
        skip = false

        retro.ignore_issues_starting_with.each do |issue_key|
          if ticket.id.start_with?(issue_key)
            skip = true
            break
          end
        end

        next("Skipping for JIRA calls #{ticket.id}") if skip == true

        if retro.sprint_sheet_obj.nil?  || retro.get_total_sps == true
          begin
            issue = retro.jira_client.Issue.find(ticket.id)
          rescue
            Retrospectives::logger.info("WARNING : timeout [#{ticket.id}]. Retry [#{retry_attempts} / 3]")
            retry_attempts += 1
            if retry_attempts < 3
              retry
            end
            if issue.nil?
              Retrospectives::logger.info("WARNING : Issue details not found [#{ticket.inspect}]. Skipping...")
              next
            end
          end

          if retro.get_total_sps == false
            ticket.description = issue.attrs['fields']['summary']
            ticket.type = issue.attrs['fields']['issuetype']['name']
            ticket.status = issue.attrs['fields']['status']['name']
          end

          ticket.total_story_points = issue.attrs['fields']['customfield_10004']
        end

        fetch_and_store_jira_hours(ticket, retro)
      end
    end


    private

    def self.get_start_and_end_date_columns(sheet, retro)
      start_date_column = nil
      end_date_column = nil

      (1..sheet.max_cols).each do |column|
        begin
         date = Date.strptime(sheet[1, column],'%d/%m/%Y')

         start_date_column = column if date == retro.start_date
         end_date_column = column if date == retro.end_date
        rescue
          # Not important to catch
        end
      end

      [start_date_column, end_date_column]
    end

    def self.retro_tickets_include?(retro, ticket_id)
      retro.tickets.each do |ticket|
        return true if ticket.id == ticket_id
      end

      false
    end

    def self.fetch_and_store_jira_hours(ticket, retro)
      worklogs = retro.simple_jira_wrapper.get_worklog(ticket.id)
      return if worklogs.nil? || worklogs['worklogs'].nil?

      worklogs['worklogs'].each do |worklog|
        worklog_date = Date.parse(worklog['started'])
        worklog_id = worklog['self'].split('/').last

        # this substracts one day not one second, as retro.end_date is a date class object
        sprint_end_date = retro.end_date - 1

        author = worklog['author']['name']
        time_in_hours = (worklog['timeSpentSeconds'] / 3600.0).round(2)
        ticket.hours_logged['total'] += time_in_hours

        next if(worklog_date > sprint_end_date || worklog_date < retro.start_date)

        retro.members.each do |member|
          member.hours_spent_jira[ticket.id] += time_in_hours if member.username == author
        end
      end
    end
  end
end
