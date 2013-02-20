module Tuca
  class Client
    # Transmission RPC methods
    include Tuca::Methods

    attr_reader :torrents

    def initialize(rpc, username, password, interval = 1, &block)
      @options = {
          :uri => URI.parse(rpc),
          :rpc => rpc,
          :username => username,
          :password => password,
          :session_id => nil
      }      
      @fresh = true
      @callbacks = {}
      @block = block
      @torrents = {}
      @interval = interval || 1
      if block_given?
        if EventMachine.reactor_running?
          @block.call(self)
        else
          EventMachine.run { @block.call(self) }
        end
      end
    end

    def disconnect
      clear_callbacks
      EventMachine.stop_event_loop unless EventMachine.reactor_running?
    end

    %w(added deleted moved stopped start_wait started seed_wait seeded exists check_wait checked progress error unauthorized).each do |c|
      name = c.to_sym
      define_method name do |&block|
        @callbacks[name] = block
        activate_callbacks
      end
    end

    def pause_callbacks
      @callbacks_timer.cancel if @callbacks_timer
    end

    def resume_callbacks
      activate_callbacks
    end

    def clear_callbacks
      @callbacks = {}
    end

    def options
      @options
    end

    private
    def activate_callbacks
      return if @callbacks_timer
      if EventMachine.reactor_running?
        @callbacks_timer = EventMachine::PeriodicTimer.new(@interval) { process_callbacks }
      else
        process_callbacks
      end
    end

    def process_callbacks
      get do |response|
        response.error { |code| safe_callback_call(:error, code) }
        response.unauthorized { safe_callback_call(:unauthorized) }

        response.success(false) do |torrents|
          if @fresh
            torrents.each do |t|
              @torrents[t.hash_string] = t
              safe_callback_call(:exists, t)
            end
            @fresh = false
          else
            watch_torrents = {}
            torrents.each do |t|
              if @torrents.key?(t.hash_string)
                wt = @torrents[t.hash_string]

                safe_callback_call(:moved, t) unless t.download_dir == wt.download_dir
                safe_callback_call(:progress, t) unless t.downloaded_ever == wt.downloaded_ever

                safe_callback_call(:stopped, t) if status_changed?(:stopped, t, wt)
                safe_callback_call(:check_wait, t) if status_changed?(:check_wait, t, wt)
                safe_callback_call(:checked, t) if status_changed?(:check, t, wt)
                safe_callback_call(:start_wait, t) if status_changed?(:download_wait, t, wt)
                safe_callback_call(:started, t) if status_changed?(:download, t, wt)
                safe_callback_call(:seed_wait, t) if status_changed?(:seed_wait, t, wt)
                safe_callback_call(:seeded, t) if status_changed?(:seeded, t, wt)

                watch_torrents[t.hash_string] = t
                @torrents.delete(t.hash_string)
              else
                watch_torrents[t.hash_string] = t
                safe_callback_call(:added, t)
              end
            end
            @torrents.each { |_, t| safe_callback_call(:deleted, t) }

            @torrents = watch_torrents
          end
        end
      end
    end

    def status_changed?(status_code, one_torrent, two_torrent)
      one_torrent.status == status_code && two_torrent.status != status_code
    end

    def safe_callback_call(cb, *args)
      return unless @callbacks
      @callbacks[cb].call(*args) if @callbacks.key?(cb)
    end

    def format_id(id)
      case id
        when Hash then
          id.to_a
        when Array then
          id
        else
          [id]
      end
    end

    def push(body, &block)
      if @block.nil?
        sync_request(body, &block)
      else
        async_request(body, &block)
      end
    end

    def sync_request(body, &block)
      response = Net::HTTP.start(@options[:uri].host, @options[:uri].port, :use_ssl => @options[:uri].scheme == 'https') do |http|
        request = Net::HTTP::Post.new(@options[:uri].path)
        request.body = body.to_json
        request.basic_auth(@options[:username], @options[:password]) unless @options[:username].nil? && @options[:password].nil?
        request['x-transmission-session-id'] = @options[:session_id] unless @options[:session_id].nil?
        http.request(request)
      end

      status = response.code.to_i
      if status == 409
        @options[:session_id] = response.header['x-transmission-session-id']
        push(body, &block)
      else
        safe_callback_call(:error, status) unless [200, 401].include?(status)
        safe_callback_call(:unauthorized) if status == 401
        response = Tuca::Response.new(self, status, response.body)
        block_given? ? block.call(response) : response
      end
    end

    def async_request(body, &block)
      options = {:head => {}, :body => body.to_json}
      options[:head][:authorization] = [@options[:username], @options[:password]] unless @options[:username].nil? && @options[:password].nil?
      options[:head][:'x-transmission-session-id'] = @options[:session_id] unless @options[:session_id].nil?

      request = EventMachine::HttpRequest.new(@options[:rpc]).post(options)

      request.callback do
        status = request.response_header.status
        if status == 409
          @options[:session_id] = request.response_header['x-transmission-session-id']
          push(body, &block)
        else
          safe_callback_call(:error, status) unless [200, 401].include?(status)
          safe_callback_call(:unauthorized) if status == 401
          response = Tuca::Response.new(self, status, request.response)
          block_given? ? block.call(response) : response
        end
      end

      request.errback do |error|
        safe_callback_call(:error, error)
        response = Tuca::Response.new(self, request.response_header.status, request.response)
        block_given? ? block.call(response) : response
      end
    end
  end
end