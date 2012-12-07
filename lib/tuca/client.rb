module Tuca
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

    def get(fields = Tuca::Torrent::ATTRIBUTES, id = nil, &block)
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

                  tc = Tuca::Torrent.new(self, t)

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
              @torrents.each { |hash, t| safe_callback_call(:deleted, Tuca::Torrent.new(self, t)) }

              @torrents = watch_torrents
            else
              @torrents = {}
              torrents.each do |t|
                @torrents[t[:hashString]] = t
                safe_callback_call(:exists, Tuca::Torrent.new(self, t))
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
            block.call(Tuca::Response.new(self, status, request.response))
          end
        end

        request.errback do |error|
          safe_callback_call(:error, error)
          block.call(Tuca::Response.new(self, request.response_header.status, request.response))
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
          return Tuca::Response.new(self, status, response.body)
        end
      end
    end
  end
end