require 'json'
require 'net/http'
require 'em-http-request'

module Transmission
  class Client
    def initialize(rpc, username, password)
      @uri = URI.parse(rpc)
      @rpc = rpc
      @username = username
      @password = password
      @session_id = nil
      @callbacks = {}
    end

    def session_set(arguments, &block)
      body = {
        :method => 'session-set',
        :arguments => arguments
      }

      block_given? ? push(body, &block) : push(body)
    end

    def session_get(&block)
      body = {
        :method => 'session-get'        
      }

      block_given? ? push(body, &block) : push(body)
    end

    def blocklist_update(&block)
      body = {
        :method => 'blocklist-update'
      }

      block_given? ? push(body, &block) : push(body)
    end

    def port_test(&block)
      body = {
        :method => 'port-test'
      }

      block_given? ? push(body, &block) : push(body)
    end

    def session_stats(&block)
      body = {
          :method => :'session-stats'
      }

      block_given? ? push(body, &block) : push(body)
    end   

    def get(fields = Transmission::Torrent::ATTRIBUTES, id = nil, &block)
      fields = (fields + [:id, :name, :hashString, :status, :downloadedEver]).uniq
      body = {
          :method => :'torrent-get',
          :arguments => {
              :fields => fields
          }
      }
      body[:arguments][:ids] = format_id(id) unless id.nil?

      block_given? ? push(body, &block) : push(body)
    end

    def start(id, &block)
      body = {
          :method => 'torrent-start',
          :arguments => {
              :ids => format_id(id)
          }
      }

      block_given? ? push(body, &block) : push(body)
    end

    def start_now(id, &block)
      body = {
          :method => 'torrent-start-now',
          :arguments => {
              :ids => format_id(id)
          }
      }

      block_given? ? push(body, &block) : push(body)
    end

    def stop(id, &block)
      body = {
          :method => 'torrent-stop',
          :arguments => {
              :ids => format_id(id)
          }
      }

      block_given? ? push(body, &block) : push(body)
    end

    def verify(id, &block)
      body = {
          :method => 'torrent-verify',
          :arguments => {
              :ids => format_id(id)
          }
      }

      block_given? ? push(body, &block) : push(body)
    end

    def reannounce(id, &block)
      body = {
          :method => 'torrent-reannounce',
          :arguments => {
              :ids => format_id(id)
          }
      }

      block_given? ? push(body, &block) : push(body)
    end

    def set(id, property, value, &block)
      body = {
        :method => 'torrent-set',
        :arguments => {
          :ids => format_id(id),
          property.to_sym => value
        }
      }

      block_given? ? push(body, &block) : push(body)
    end

    def create(arguments, &block)
      raise "Undefined filename or metainfo" unless arguments.key?(:filename) || arguments.key?(:metainfo)
      arguments.delete(:filename) if arguments.key?(:metainfo) && arguments.key?(:filename)

      body = {
        :method => 'torrent-add',
        :arguments => arguments
      }

      block_given? ? push(body, &block) : push(body)
    end

    def delete(id = nil, delete_local_data = false, &block)
      body = {
        :method => 'torrent-remove',
        :arguments => {
          :delete_local_data => delete_local_data
        }
      }
      body[:arguments][:ids] = format_id(id) unless id.nil?

      block_given? ? push(body, &block) : push(body)
    end

    def move(location, id = nil, move = true, &block)
      body = {
        :method => 'torrent-set-location',
        :arguments => {
          :location => location
        }
      }
      body[:arguments][:ids] = format_id(id) unless id.nil?
      body[:arguments][:move] = move unless move.nil?

      block_given? ? push(body, &block) : push(body)
    end

    %w(added deleted moved stopped start_wait started seed_wait seeded exists check_wait checked progress error unauthorized).each do |c|
      name = c.to_sym
      define_method name do |&block|
        @callbacks[name] = block
        activate_callbacks
      end
    end

    def stop_callbacks
      @callbacks_timer.cancel if @callbacks_timer
    end

    private
    def activate_callbacks
      return if @callbacks_timer
      @callbacks_timer = EventMachine::PeriodicTimer.new(1) do
        get([:id, :name, :hashString, :status, :downloadedEver]) do |response|
          response.error { |code| safe_callback_call(:error, code) } 
          response.unauthorized { safe_callback_call(:unauthorized) }

          response.success(false) do |torrents|
            if @torrents
              watch_torrents = {}
              torrents.each do |t|
                if @torrents.key?(t[:hashString])
                  wt = @torrents[t[:hashString]]

                  tc = Transmission::Torrent.new(self, t)

                  safe_callback_call(:moved, tc)      unless t[:downloadDir] == wt[:downloadDir]                   
                  safe_callback_call(:progress, tc)   unless t[:downloadedEver] == wt[:downloadedEver]
                  safe_callback_call(:stopped, tc)    if status_changed?(0, t, wt)
                  safe_callback_call(:check_wait, tc) if status_changed?(1, t, wt)
                  safe_callback_call(:checked, tc)    if status_changed?(2, t, wt)
                  safe_callback_call(:start_wait, tc) if status_changed?(3, t, wt)
                  safe_callback_call(:started, tc)    if status_changed?(4, t, wt)
                  safe_callback_call(:seed_wait, tc)  if status_changed?(5, t, wt)
                  safe_callback_call(:seeded, tc)     if status_changed?(6, t, wt)
                  
                  watch_torrents[t[:hashString]] = t
                  @torrents.delete(t[:hashString])
                else
                  watch_torrents[t[:hashString]] = t
                  safe_callback_call(:added, t)
                end
              end
              @torrents.each { |hash, t| safe_callback_call(:deleted, Transmission::Torrent.new(self, t)) }

              @torrents = watch_torrents
            else
              @torrents = {}
              torrents.each do |t| 
                @torrents[t[:hashString]] = t
                safe_callback_call(:exists, Transmission::Torrent.new(self, t))
              end
            end
          end
        end
      end
    end

    def status_changed?(status_code, one_torrent, two_torrent)
      one_torrent[:status].to_i == status_code && two_torrent[:status].to_i != status_code
    end

    def safe_callback_call(cb, *args)
      return unless @callbacks
      @callbacks[cb].call(*args) if @callbacks.key?(cb)
    end

    def format_id(id)
      case id
        when Hash then id.to_a
        when Array then id
        else [id]
      end
    end

    def push(body, &block)
      if block_given?
        options = {:head => {}, :body => body.to_json}
        options[:head][:authorization] = [@username, @password] unless @username.nil? && @password.nil?
        options[:head][:'x-transmission-session-id'] = @session_id unless @session_id.nil?

        request = EventMachine::HttpRequest.new(@rpc).post(options)

        request.callback do
          status = request.response_header.status
          if status == 409
            @session_id = request.response_header['x-transmission-session-id']
            push(body, &block)
          else
            safe_callback_call(:error, status) unless [200, 401].include?(status)
            safe_callback_call(:unauthorized) if status == 401
            block.call(Transmission::Response.new(self, status, request.response))
          end
        end

        request.errback do |error|
          safe_callback_call(:error, error)
          block.call(Transmission::Response.new(self, request.response_header.status, request.response))
        end
      else
        response = Net::HTTP.start(@uri.host, @uri.port, :use_ssl => @uri.scheme == 'https') do |http|
          request = Net::HTTP::Post.new(@uri.path)
          request.body = body.to_json
          request.basic_auth(@username, @password) unless @username.nil? && @password.nil?
          request['x-transmission-session-id'] = @session_id unless @session_id.nil?
          http.request(request)
        end

        status = response.code.to_i
        if status == 409
          @session_id = response.header['x-transmission-session-id']
          push(body)
        else
          safe_callback_call(:error, status) unless [200, 401].include?(status)
          safe_callback_call(:unauthorized) if status == 401
          return Transmission::Response.new(self, status, response.body)
        end
      end
    end
  end

  class Response
    def initialize(connection, code, response)
      @connection = connection
      @code = code
      @response = response
      @can_build = can_build_json?
      @json = build_json if @can_build
      @result = @json[:result] if @json
    end

    def success(iterate = true, &block)
      return self unless block_given? && success?

      if torrents_response?
        if iterate
          torrents.each { |t| yield Transmission::Torrent.new(@connection, t) }
        else
          ts = []
          torrents.each { |t| ts << Transmission::Torrent.new(@connection, t) }
          block.call(ts)
        end
      else
        block.call(@json)
      end
      self
    end

    def error(&block)
      block.call(@code, @result) if !duplicate? && block_given? && error?
      self      
    end

    def unauthorized(&block)
      block.call() if unauthorized? && block_given?
      self
    end

    def duplicate(&block)
      block.call() if block_given? && duplicate?
      self
    end

    def duplicate?
      @result && @result == 'duplicate torrent'
    end

    def success?
      [200, 401].include?(@code) && !duplicate?
    end

    def error?
      !success?
    end

    def unauthorized?
      @code == 401
    end

    private
    def torrents
      @json[:arguments][:torrents]
    end

    def torrents_response?
      @json && @json.key?(:arguments) && @json[:arguments].key?(:torrents)
    end

    def build_json
      JSON.parse(@response, :symbolize_names => true)
    end

    def can_build_json?
      begin
        build_json
        true
      rescue JSON::ParserError
        false
      end
    end
  end

  class Torrent
    ATTRIBUTES = [
      :activityDate, :addedDate, :announceResponse, :announceURL, :bandwidthPriority, :comment,
      :corruptEver, :creator, :dateCreated, :desiredAvailable, :doneDate, :downloadDir,
      :downloadedEver, :downloaders, :downloadLimit, :downloadLimited, :error, :errorString,
      :eta, :files, :fileStats, :hashString, :haveUnchecked, :haveValid, :honorsSessionLimits,
      :id, :isPrivate, :lastAnnounceTime, :lastScrapeTime, :leechers, :leftUntilDone,
      :manualAnnounceTime, :maxConnectedPeers, :name, :nextAnnounceTime, :'peer-limit',
      :peers, :peersConnected, :peersFrom, :peersGettingFromUs, :peersKnown, :peersSendingToUs, 
      :percentDone, :pieces, :pieceCount, :pieceSize, :priorities, :rateDownload, :rateUpload, 
      :recheckProgress, :scrateResponse, :scrapeURL, :seeders, :seedRatioLimit, :seedRatioMode,
      :sizeWhenDone, :startDate, :status, :swarmSpeed, :timesCompleted, :trackers, :totalSize, 
      :torrentFile, :uploadedEver, :uploadedLimit, :uploadedLimited, :uploadRatio, :wanted, 
      :webseeds, :webseedsSendingToUs
    ]

    SETTABLE = [
      :bandwidthPriority, :downloadLimit, :downloadLimited, :'files-wanted', :'files-unwanted',
      :'honorsSessionsLimits', :location, :'peer-limit', :'priority-high', :'priority-low',
      :'priority-normal', :seedRatioLimit, :seedRationMode, :uploadLimit, :uploadLimited
    ]

    STATUSES = {
      0 => :stopped,
      1 => :check_wait,
      2 => :check,
      3 => :download_wait,
      4 => :download,
      5 => :seed_wait,
      6 => :seeded
    }

    def initialize(connection, fields = {})
      @connection = connection
      @fields = fields
    end
    
    def [](key)
      @fields[key]
    end

    def []=(key, value)
      raise "Attribute #{key} is readonly" unless SETTABLE.include?(key)
      @fields[key] = value
      update_attribute(key, value)
    end

    def status
      STATUSES[@fields[:status]]
    end

    def save(&block)
      if new_torrent?
        saved_attributes = @fields.select { |key, value| SETTABLE.include?(key) || [:filename, :metainfo].include?(key) }
        result = @connection.create(saved_attributes)
        @fields.merge(result[:arguments][:'torrent-added']) if result.success?
        block.call(result)
      end
    end

    def start(&block)
      unless new_torrent?
        block_given? ? @connection.start(@fields[:id], &block) : @connection.start(@fields[:id])
      end
    end

    def start_now(&block)
      unless new_torrent?
        block_given? ? @connection.start_now(@fields[:id], &block) : @connection.start_now(@fields[:id])
      end
    end

    def stop(&block)
      unless new_torrent?
        block_given? ? @connection.stop(@fields[:id], &block) : @connection.stop(@fields[:id])
      end
    end

    def delete(delete_local_data = false, &block)
      unless new_torrent?
        block_given? ? @connection.delete(@fields[:id], delete_local_data, &block) : @connection.delete(@fields[:id], delete_local_data)
      end
    end

    def move(location, move = true, &block)
      unless new_torrent?
        block_given? ? @connection.move(location, @fields[:id], move, &block) : @connection.move(location, @fields[:id], move)
      end
    end

    def new_torrent?
      !@fields.key?(:id) || @fields[:id].to_i < 0
    end

    private
    def method_missing(m, *args, &block)
      @fields[m]
    end

    def update_attribute(key, value)
      @connection.set(@fields[:id], key, value) unless new_torrent?
    end
  end
end

EventMachine.run do
  client = Transmission::Client.new 'http://localhost:9091/transmission/rpc', 'transmission', '123456'
  client.get do |r|
    r.success { |result| puts "Status (#{result.id}): #{result.status}" }
    r.error { |code, message| puts "Error (#{code}) #{message} 11" }
    r.unauthorized { puts :unauthorized }
  end
  client.added do |torrent|
    puts "New torrent: #{torrent.id}"
  end
  client.exists do |torrent|
    puts "Exists torrent on transmission connection init: #{torrent.status}"
  end
  client.deleted do |torrent|
    puts "Torrent was deleted: #{torrent.id}"
  end
  client.stopped do |torrent|
    puts "Torrent was stopped: #{torrent.id}"
  end
  client.started { |t| puts "Torrent started: #{t.inspect}" }
  client.seeded { |t| puts "Torrent seeded: #{t.inspect}" }
  client.progress { |t| puts "Torrent #{t.id} progress: #{t.downloadedEver}" }
  client.error { |code| puts "Getting code: #{code}" }
  client.unauthorized { puts "unauthorized" }
  client.create({:filename => '/home/nikita/Downloads/[rutracker.org].t3498008.torrent'}) do |r|
    r.success { |result| puts result }
    r.error { |code, message| puts "Error (#{code}) #{message}" }
    r.duplicate { puts "Torrent duplicate" }
  end
  #response = client.create({:filename => '/home/nikita/Downloads/[rutracker.org].t3498008.torrent'})
  #response.success { |result| puts "#{result} ---" }
  #response.error { |code, message| puts "Error (#{code}) #{message}" }
  #response.duplicate { puts "Torrent duplicate" }
end
