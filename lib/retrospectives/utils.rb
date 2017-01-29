module Retrospectives
  class Utils

    def self.validate_params(params, keys)
      keys.each do |key|
        raise 'Required key missing [#{key}]' if params.exclude?(key) || params[key].strip.empty?
      end
    end

    def clean(string)
      begin
        string.to_s.tr('"','').strip.chomp
      rescue NoMethodError
        nil
      end
    end

  end
end
