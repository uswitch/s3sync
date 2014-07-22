module S3sync

  class FileDiff

    def self.diff(source, destination)
      source.reject { |key,item| same_file?(item, destination[key]) }
    end

  private

    def self.last_modified(item)
      item[:last_modified]
    end

    def self.content_length(item)
      item[:content_length]
    end

    def self.same_file?(source, dest)
      return false unless dest
      return false if content_length(dest) != content_length(source)
      return false unless last_modified(dest) >= last_modified(source)
      return true
    end

  end

end
