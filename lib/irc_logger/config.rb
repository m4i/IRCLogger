require 'ostruct'

module IRCLogger
  class Config < OpenStruct
    def initialize(hash = nil)
      @table = {}
      if hash
        hash.each do |k, v|
          @table[k.to_sym] = v.is_a?(Hash) ? self.class.new(v) : v.freeze
          new_ostruct_member(k)
        end
      end
      @table.freeze
      freeze
    end
  end
end
