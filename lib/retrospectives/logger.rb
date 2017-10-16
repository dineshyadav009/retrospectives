module Retrospectives
  class Log
    def initialize
      @logger = Logger.new($stdout)
      @logger.datetime_format = '%Y-%m-%d %H:%M:%S'
    end

    def info(str)
      begin
        str.split("\n").each do |line|
          @logger.info(line)
        end
      rescue
      end
    end

    def debug(str)
      return if Retrospectives::RetroSetup.debug == false

      begin
        str.split("\n").each do |line|
          @logger.debug(line)
        end
      rescue
      end
    end
  end
end
