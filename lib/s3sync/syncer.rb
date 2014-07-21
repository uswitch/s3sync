require 'find'
require 'fileutils'

module S3sync

  class Syncer
    def initialize
      @s3 = AWS::S3.new
    end

    def upload(local_path, s3_url)
      bucket_name, *folders = s3url_to_bucket_folder s3_url

      puts "Uploading files"
      diff(local_files(local_path), remote_files(bucket_name, folders)).each do |key,item|
        s3_key = File.join folders, key
        puts "#{item[:file]} => s3://#{bucket_name}/#{s3_key}"
        s3_upload item, bucket_name, s3_key
      end
      puts "done"

    end

    def download(s3_location, local_path)
      bucket_name, *folders = s3url_to_bucket_folder s3_location
      destination_folder = File.absolute_path(local_path)

      puts "Downloading"
      diff(remote_files(bucket_name, folders), local_files(local_path)).each do |key,item|
        destination_file = File.join destination_folder, key
        puts "#{item[:file].public_url} => #{destination_file}"
        s3_download item, destination_file
      end
      puts "done"

    end

  private

    def ensure_folder_exists(folder)
      FileUtils.mkdir_p(folder) unless File.directory?(folder)
    end 

    def update_last_modified(file, time)
      FileUtils.touch file, mtime:time
    end

    def s3_download(item, destination_file)
      ensure_folder_exists File.dirname(destination_file)

      File.open(destination_file, 'wb') do |f|
        item[:file].read {|chunk| f.write chunk }
      end

      update_last_modified destination_file, item[:last_modified]
    end

    def s3_upload(item, bucket, key)
      object = @s3.buckets[bucket].objects[key]
      object.write(:file => item[:file])
      object.metadata['last_modified'] = item[:last_modified]
    end

    def s3url_to_bucket_folder(s3_location)
      s3_path = s3_location.match(/s3:\/\/(.*)/)[1] rescue nil
      exit 1 unless s3_path

      s3_path.split /\//
    end

    def local_files(path)
      return {} unless File.directory? path

      results = {}
      Find.find(path) do |item|
        next if File.directory? item
        
        file_path  = item.match(/#{path}\/?(.*)/)[1]
        results[file_path] = { key:file_path, 
                               last_modified:File.mtime(item), 
                               content_length: File.size(item), 
                               file: File.absolute_path(item) }
      end

      results
    end

    def remote_files(bucket, folders)
      @s3.buckets[bucket].objects.with_prefix(File.join(folders)).reduce({}) do |result,object|
        relative_file_name = File.join(object.key.split(/\//).drop folders.length)
        last_modified      = Time.parse object.metadata['last_modified']
        content_length     = object.content_length
        
        result.merge relative_file_name => { key:relative_file_name, last_modified:last_modified, content_length:content_length, file:object }
      end
    end

    def same_file?(source, dest)
      return false unless dest
      return false unless dest[:last_modified] >= source[:last_modified]
      return false unless dest[:content_length] == source[:content_length]
      return true
    end

    def diff(source, destination)
      source.reject { |key,item| same_file?(item, destination[key]) }
    end

  end
end