require 'find'
require 'fileutils'

module S3sync

  class Syncer
    def initialize
      @s3 = AWS::S3.new
    end

    def upload(local_path, s3_location)
      s3_path = s3_location.match(/s3:\/\/(.*)/)[1] rescue nil
      exit 1 unless s3_path

      bucket_name, *folders = s3_path.split /\//

      Find.find(local_path) do |item|
        next if File.directory? item
        
        relative_path = item.match(/#{local_path}(.*)/)[1]
        path_bits = relative_path.split(/\//)
        s3_key = File.join folders+path_bits

        puts "Uploading: #{item} to s3://#{bucket_name}/#{s3_key}"
        @s3.buckets[bucket_name].objects[s3_key].write(:file => item)
      end
    end

    def download(s3_location, local_path)
      s3_path = s3_location.match(/s3:\/\/(.*)/)[1] rescue nil
      exit 1 unless s3_path

      bucket_name, *folders = s3_path.split /\//
      destination_folder = File.absolute_path(local_path)

      @s3.buckets[bucket_name].objects.with_prefix(File.join(folders)).each do |object|
        relative_file_name = object.key.split(/\//).drop folders.length
        destination_file = File.join destination_folder, relative_file_name

        puts "Downloading: s3://#{bucket_name}/#{object.key} to #{destination_file}"

        FileUtils.mkdir_p(File.dirname(destination_file)) unless File.directory?(File.dirname(destination_file))
        File.open(destination_file, 'wb') do |f|
          object.read do |chunk|
            f.write chunk
          end
        end

      end
    end

  private

    def local_files(path)
      results = []
      Find.find(path) do |item|
        next if File.directory? item
        
        file_path      = item.match(/#{path}(.*)/)[1]
        last_modified  = File.mtime(file_path)
        content_length = File.size(file_path)

        results << { key:file_path, last_modified:last_modified, content_length: content_length, file: File.absolute_path(item)}
      end

      results
    end

    def remote_files(bucket, prefix)
      @s3.buckets[bucket].objects.with_prefix(prefix).map do |object|
        relative_file_name = File.join(object.key.split(/\//).drop folders.length)
        last_modified      = object.last_modified
        content_length     = object.content_length
        
        { key:relative_file_name, last_modified:last_modified, content_length:content_length, file:object }

      end
    end

  end
end
