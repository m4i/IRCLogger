module IRCLogger
  CONFIG_PATH = File.join(RAILS_ROOT, 'config', 'irc_logger.yml')

  class << self
    def config
      @config ||= IRCLogger::Config.new(YAML.load_file(CONFIG_PATH))
    end
  end
end
