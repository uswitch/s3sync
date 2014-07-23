require 'syslog/logger'

module S3sync

  class Logger
    def initialize
      @log = Syslog::Logger.new 'S3sync'
    end

    def info(message)
      return puts message if ENV['DEBUG']
      @log.info "INFO: #{message}"
    end

    def error(e)
      message = "ERROR: #{e.message} #{e.backtrace.inspect}"
      return puts message if ENV['DEBUG']
      @log.error message
    end
  end

end
