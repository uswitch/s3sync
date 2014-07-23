require 'find'
require 'fileutils'
require 'syslog/logger'

module S3sync

  class Syncer
    def initialize
      @s3 = AWS::S3.new
      @log = Logger.new
    end

    def upload(local_path, s3_url)
      bucket_name, *folders = s3url_to_bucket_folder s3_url

      @log.info "Uploading files" 

      local_files = local_files(local_path)
      remote_files(bucket_name, folders) do |s3|
        source = local_files[s3[:key]]
        local_files.delete s3[:key] if FileDiff::same_file? source, s3
      end

      local_files.each do |key,item|
        s3_key = File.join folders, key
        @log.info "#{item[:file]} => s3://#{bucket_name}/#{s3_key}"
        s3_upload item, bucket_name, s3_key
      end
      @log.info "Done"
    rescue Exception -> e
      @log.error e
    end

    def download(s3_location, local_path)
      bucket_name, *folders = s3url_to_bucket_folder s3_location
      destination_folder = File.absolute_path(local_path)

      @log.info "Downloading"
      
      local_files = local_files(local_path)
      remote_files(bucket_name, folders) do |s3|
        next if FileDiff::same_file? s3, local_files[s3[:key]]
        destination_file = File.join destination_folder, s3[:key]
        @log.info "#{s3[:file].public_url} => #{destination_file}"
        s3_download s3, destination_file
      end
      @log.info "Done"
    rescue Exception -> e
      @log.error e
    end

  private

    def ensure_folder_exists(folder)
      FileUtils.mkdir_p(folder) unless File.directory?(folder)
    end 

    def update_last_modified(file, time)
      FileUtils.touch file, mtime:time
    end

    def last_modified(item)
      item[:last_modified]
    end

    def s3_download(item, destination_file)
      ensure_folder_exists File.dirname(destination_file)

      File.open(destination_file, 'wb') do |f|
        item[:file].read {|chunk| f.write chunk }
      end

      update_last_modified destination_file, last_modified(item)
    end

    def s3_upload(item, bucket, key)
      object = @s3.buckets[bucket].objects[key]
      object.write(:file => item[:file])
      object.metadata['last_modified'] = last_modified(item)
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
                               last_modified: File.mtime(item), 
                               content_length: File.size(item),
                               file: File.absolute_path(item) }
      end

      results
    end

    def remote_item(object, relative_path)
      last_modified = Time.parse object.metadata['last_modified'] rescue 0

      { key:File.join(relative_path), 
        last_modified:last_modified, 
        content_length:object.content_length, 
        file:object }
    end

    # Yielding the remote s3 files and doing a 2 pass filter
    # as better performance than computing a diff of 2 complete directory listings
    def remote_files(bucket, folders)
      objects = @s3.buckets[bucket].objects.with_prefix(File.join(folders))
      objects.each do |object|
        relative_path = object.key.split(/\//).drop folders.length
        next if object.content_length.nil? or object.content_length == 0 or relative_path.empty?
        yield remote_item(object, relative_path)
      end
    end

  end
end
