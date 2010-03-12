class User < ActiveRecord::Base
  has_many :messages

  validates_presence_of :name
  validates_length_of   :name, :minimum => 1

  class << self
    # find_by_name or create!
    def find_or_create!(name)
      find_by_name(name) || create!(:name => name)
    end

    # bot の User を返す
    def bot
      @bot ||= find_by_name(IRCLogger.config.bot.user)
    end
  end
end
