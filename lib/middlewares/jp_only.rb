require "net/http"
require "digest"
require "rubygems/package"
require "fileutils"
require "zlib"

module Middlewares
  class JpOnly
    class GeoLite2
      class UpdateError < StandardError; end

      def initialize
        @mutex = Mutex.new
      end
    
      def db
        @mutex.synchronize do
          # db_path のファイルが作成から1週間以内なら db_path を返す
          if FileTest.file?(db_path) && File.mtime(db_path) > 1.week.ago
            return db_path
          end
    
          update_db
        end
      end
    
      private
    
      def db_path
        @db_path ||= make_path("GeoLite2-Country.mmdb")
      end
    
      def download_file(url, path, account_id, license_key, limit = 10)
        raise ArgumentError, "too many HTTP redirects" if limit == 0
      
        uri = URI(url)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
          req = Net::HTTP::Get.new(uri)
          req.basic_auth account_id, license_key if account_id && license_key
          response = http.request(req)
      
          case response
          when Net::HTTPSuccess then
            File.open(path, "wb") { |file| file.write(response.body) }
          when Net::HTTPRedirection then
            location = response["location"]
            warn "redirected to #{location}"
            download_file(location, path, nil, nil, limit - 1)
          else
            response.value
          end
        end
      end
    
      def make_path(relative_path)
        Rails.root.join("tmp", relative_path).to_s
      end
    
      def update_db
        # ファイルを一時的に保存するパス
        temp_file_path = make_path("GeoLite2-Country.tar.gz")
        temp_sha256_path = make_path("GeoLite2-Country.tar.gz.sha256")
    
        # ダウンロードするファイルのURL
        db_url = "https://download.maxmind.com/geoip/databases/GeoLite2-Country/download?suffix=tar.gz"
        sha256_url = "https://download.maxmind.com/geoip/databases/GeoLite2-Country/download?suffix=tar.gz.sha256"
    
        # ユーザー名とパスワード
        account_id = ENV["MAXMIND_ACCOUNT_ID"]
        license_key = ENV["MAXMIND_LICENSE_KEY"]
        raise UpdateError.new("Missing MAXMIND_ACCOUNT_ID") unless account_id.present?
        raise UpdateError.new("Missing MAXMIND_LICENSE_KEY") unless license_key.present?
    
        # ダウンロードして一時的に保存
        download_file(db_url, temp_file_path, account_id, license_key)
    
        # SHA256ハッシュを取得
        download_file(sha256_url, temp_sha256_path, account_id, license_key)
        sha256_hash = File.read(temp_sha256_path).strip.split(/\s/).first
    
        # ダウンロードしたファイルのSHA256ハッシュを計算
        downloaded_file_sha256_hash = Digest::SHA256.file(temp_file_path).hexdigest
    
        if sha256_hash == downloaded_file_sha256_hash
          tar_extract = Gem::Package::TarReader.new(Zlib::GzipReader.open(temp_file_path))
          tar_extract.rewind
          tar_extract.each do |entry|
            if entry.full_name.include?("GeoLite2-Country.mmdb")
              if File.exist?(db_path)
                File.unlink(db_path)
              else
                FileUtils.mkdir_p(File.dirname(db_path)) if File.directory?(File.dirname(db_path))
              end
              File.open(db_path, "wb") { |f| f.write(entry.read) }
              return db_path
            end
          end
        else
          raise UpdateError.new("Downloaded file is corrupted.")
        end
        nil
      ensure
        # 一時ファイルを削除
        File.delete(temp_file_path) if temp_file_path && File.exist?(temp_file_path)
        File.delete(temp_sha256_path) if temp_sha256_path && File.exist?(temp_sha256_path)
      end
    end
    
    def initialize(app)
      @app = app
    end

    def call(env)
      if allowed?(env)
        @app.call(env)
      else
        [403, { 'Content-Type' => 'text/plain' }, ['Forbidden']]
      end
    end

    private

    def allowed?(env)
      request = ActionDispatch::Request.new(env)
      # HTTP POST でないなら許可
      return true unless request.post?
      remote_ip = request.remote_ip
      # ローカルホストでないなら許可
      return true if localhost?(remote_ip)
      # 日本国内なら許可
      return true if jp?(remote_ip)

      false
    end

    def localhost?(remote_ip)
      remote_ip == "127.0.0.1" || remote_ip == "::1"
    end

    def jp?(remote_ip)
      db_path = geolite2db
      return true unless db_path

      reader = MaxMind::DB.new(db_path, mode: MaxMind::DB::MODE_MEMORY)
      record = reader.get(remote_ip)
      if record && record["country"]
        record["country"]["iso_code"] == "JP"
      else
        # 不明。とりあえず通す
        true
      end
    end

    def geolite2db
      JpOnly::GeoLite2.new.db
    rescue JpOnly::GeoLite2::UpdateError => e
      Rails.logger.error(e)
      nil
    end
  end
end
