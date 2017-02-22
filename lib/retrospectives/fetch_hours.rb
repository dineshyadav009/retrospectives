module Retrospectives
  class FetchHours
    def self.from_timesheet(retro)
      retro.members.each do |member|
        sheet = retro.google_client.spreadsheet_by_key(member.sheet_key).
        worksheets[member.sheet_index]

        start_row = get_row(sheet, retro, retro.start_date.to_s.gsub('-',''))
        end_row = get_row(sheet, retro, retro.end_date.to_s.gsub('-',''))

        raise "Sprint not marked correctly for #{member.name}"  if start_row.nil? || end_row.nil?

        (start_row..end_row).to_a.each do |row_index|
          ticket_id = Utils.clean(sheet[row_index, retro.ticket_id_index])
          hours_spent = Utils.clean(sheet[row_index, retro.hours_spent_index]).to_f.round(2)

          next if ticket_id.nil? || ticket_id.empty?

          if retro.include_other_tickets || retro_tickets_include?(retro, ticket_id)
            member.hours_spent_timesheet[ticket_id] += hours_spent
            retro.add_ticket(ticket_id) if retro.include_other_tickets
          end
        end
      end
    end

    def self.from_jira(retro)
      retro.tickets.each do |ticket|
        retry_attempts = 0
        skip = false

        retro.ignore_issues_starting_with.each do |issue_key|
          if ticket.id.start_with? issue_key
            skip = true
            break
          end
        end

        next("Skipping for JIRA calls #{ticket.id}") if skip == true

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
        ticket.description = issue.attrs['fields']['summary']
        ticket.type = issue.attrs['fields']['issuetype']['name']
        ticket.story_points = issue.attrs['fields']['customfield_10004']
        ticket.status = issue.attrs['fields']['status']['name']
        fetch_and_store_jira_hours(ticket, retro)
      end
    end


    private

    def self.get_row(sheet, retro, text)
      (1..sheet.num_rows).each do |row_index|
        next unless sheet[row_index, retro.sprint_delimiter_index].include?(text)

        return row_index
      end

      nil
    end

    def self.retro_tickets_include?(retro, ticket_id)
      retro.tickets.each do |ticket|
        return true if ticket.id == ticket_id
      end

      false
    end

    def self.fetch_and_store_jira_hours(ticket, retro)
      worklogs = retro.simple_jira_wrapper.get_worklog(ticket.id)

      worklogs['worklogs'].each do |worklog|
        worklog_date = Date.parse(worklog['started'])
        worklog_id = worklog['self'].split('/').last

        # this substracts one day not one second, as retro.end_date is a date class object
        sprint_end_date = retro.end_date - 1

        next("Ignoring #{ticket} #{worklog_id}") if(worklog_date > sprint_end_date ||
                                                    worklog_date < retro.start_date)

        author = worklog['author']['name']
        time_in_hours = (worklog['timeSpentSeconds'] / 3600.0).round(2)

        retro.members.each do |member|
          member.hours_spent_jira[ticket.id] += time_in_hours if member.name == author
          ticket.hours_logged['total'] += time_in_hours
        end
      end
    end
  end
end
