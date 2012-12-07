require 'json'
require 'em-http-request'

module Transmission
  class Client
    def initialize(rpc, username, password)
      @rpc = rpc
      @username = username
      @password = password
      @session_id = nil
      @callbacks = {}
    end

    def session_set(arguments)
      body = {
        :method => 'session-set',
        :arguments => arguments
      }

      push(body) { |response| yield response }
    end

    def session_get
      body = {
        :method => 'session-get'        
      }

      push(body) { |response| yield response }
    end

    def blocklist_update
      body = {
        :method => 'blocklist-update'
      }

      push(body) { |response| yield response }
    end

    def port_test
      body = {
        :method => 'port-test'
      }

      push(body) { |response| yield response }
    end

    def session_stats
      body = {
          :method => :'session-stats'
      }

      push(body) { |response| yield response }
    end   

    def get(fields, id = nil)
      body = {
          :method => :'torrent-get',
          :arguments => {
              :fields => fields
          }
      }
      body[:arguments][:ids] = format_id(id) unless id.nil?

      push(body) { |response| yield response }
    end

    def start(id)
      body = {
          :method => 'torrent-start',
          :arguments => {
              :ids => format_id(id)
          }
      }

      push(body) { |response| yield response }
    end

    def start_now(id)
      body = {
          :method => 'torrent-start-now',
          :arguments => {
              :ids => format_id(id)
          }
      }

      push(body) { |response| yield response }
    end

    def stop(id)
      body = {
          :method => 'torrent-stop',
          :arguments => {
              :ids => format_id(id)
          }
      }

      push(body) { |response| yield response }
    end

    def verify(id)
      body = {
          :method => 'torrent-verify',
          :arguments => {
              :ids => format_id(id)
          }
      }

      push(body) { |response| yield response }
    end

    def reannounce(id)
      body = {
          :method => 'torrent-reannounce',
          :arguments => {
              :ids => format_id(id)
          }
      }

      push(body) { |response| yield response }
    end

    def set(id, property, value)
      body = {
        :method => 'torrent-set',
        :arguments => {
          :ids => format_id(id),
          property.to_sym => value
        }
      }

      push(body) { |response| yield response }
    end

    def create(arguments)
      raise "Undefined filename or metainfo" unless arguments.key?(:filename) || arguments.key?(:metainfo)
      arguments.delete(:filename) if arguments.key?(:metainfo) && arguments.key?(:filename)

      body = {
        :method => 'torrent-add',
        :arguments => arguments
      }

      push(body) { |response| yield response }
    end

    def delete(id = nil, delete_local_data = false)
      body = {
        :method => 'torrent-remove',
        :arguments => {
          :delete_local_data => delete_local_data
        }
      }
      body[:arguments][:ids] = format_id(id) unless id.nil?

      push(body) { |response| yield response }
    end

    def move(location, id = nil, move = true)
      body = {
        :method => 'torrent-set-location',
        :arguments => {
          :location => location
        }
      }
      body[:arguments][:ids] = format_id(id) unless id.nil?
      body[:arguments][:move] = move unless move.nil?

      push(body) { |response| yield response }
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
              @torrents.each { |t| safe_callback_call(:deleted, t) }

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

    def push(body)
      options = {:head => {}, :body => body.to_json}
      options[:head][:authorization] = [@username, @password] unless @username.nil? && @password.nil?
      options[:head][:'x-transmission-session-id'] = @session_id unless @session_id.nil?

      request = EventMachine::HttpRequest.new(@rpc).post(options)      
      
      request.callback do
        status = request.response_header.status
        if status == 409
          @session_id = request.response_header['x-transmission-session-id']
          push(body) { |response| yield response }
        else
          safe_callback_call(:error, status) unless [200, 401].key?(status)
          safe_callback_call(:unauthorized) if status == 401
          yield Transmission::Response.new(self, status, request.response)
        end
      end

      request.errback do |error|
        safe_callback_call(:error, error)
        yield Transmission::Response.new(self, request.response_header.status, request.response)
      end
    end
  end

  # TODO: добавить колбеки для успешно выполненных запросов по полю {result:}
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
      return self unless block_given?
      return self unless @code == 200 || @can_build
      return self unless success?

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
      return self unless block
      block.call(@code, '') if @code != 401 && @code != 200
      block.call(@code, @result) if @can_build && !success?
      self      
    end

    def unauthorized(&block)
      return self unless block
      block.call() if @code == 401
      self
    end

    def success?
      @result && @result == 'success'
    end

    private
    def torrents
      @json[:arguments][:torrents]
    end

    def torrents_response?
      @json && @json.key?(:arguments) && @json.key?(:torrents)
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
      raise "Attribute #{key} is readonly" unless SETTABLE.key?(key)
      @fields[key] = value
      update_attribute(key, value)
    end

    def status
      STATUSES[@fields[:status]]
    end

    def save
      if new_torrent?
        saved_attributes = @fields.select { |key, value| SETTABLE.key?(key) || [:filename, :metainfo].key?(key) }
        @connection.create(saved_attributes) do |r|
          r.success { |result| @fields.merge(result[:arguments][:'torrent-added']) }
          r.error { nil }
        end
      end
      self
    end

    def start
      @connection.start(@fields[:id]) unless new_torrent?
    end

    def start_now
      @connection.start_now(@fields[:id]) unless new_torrent?
    end

    def stop
      @connection.stop(@fields[:id]) unless new_torrent?
    end

    def delete(delete_local_data = false)
      @connection.delete(@fields[:id], delete_local_data) unless new_torrent?
    end

    def move(location, move = true)
      @connection.move(location, @fields[:id], move)
    end

    def new_torrent?
      !@fields.key?(:id) || @fields[:id].to_i < 0
    end

    private
    def method_missing(m, *args, &block)
      @fields[m]
      @block = block
      @args = args
    end

    def update_attribute(key, value)
      @connection.set(@fields[:id], key, value) unless new_torrent?
    end
  end
end

EventMachine.run do
  client = Transmission::Client.new 'http://localhost:9091/transmission/rpc', 'transmission', '1234526'
  client.get([:id, :name, :hashString, :status, :downloadedEver]) do |r|   
    r.success { |result| puts "Status (#{result.id}): #{result.status}}" }
    r.error { |code, message| puts "Error (#{code}) #{message}" }
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
    r.success { |r| puts r }
    r.error { |code| puts code }
  end
end
