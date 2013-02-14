module Tuca
  class Response
    def initialize(connection, code, response)
      @connection = connection
      @code       = code
      @response   = response
      @can_build  = can_build_json?
      @json = build_json if @can_build
      @result = @json[:result] if @json
    end

    def success(iterate = true, &block)
      return self unless block_given? && success?

      if torrents_response?
        if iterate
          torrents.each { |t| yield Tuca::Torrent.new(@connection, t) }
        else
          block.call(torrents.map { |t| Tuca::Torrent.new(@connection, t) })
        end
      else
        block.call(@json)
      end
      self
    end

    def error(&block)
      block.call(@code, @result) if block_given? && error?
      self
    end

    def unknown(&block)
      block.call() if block_given? && unknown?
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

    def corrupt(&block)
      block.call() if block_given? && corrupt?
      self
    end

    def end(&block)
      block.call() if block_given?
      self
    end

    def duplicate?
      @result && @result == 'duplicate torrent'
    end

    def success?
      @code == 200 && !duplicate? && !corrupt?
    end

    def error?
      !success?
    end

    def unauthorized?
      @code == 401
    end

    def corrupt?
      @result && @result == 'invalid or corrupt torrent file'
    end

    def unknown?
      error? && !duplicate? && !corrupt? && !unauthorized?
    end

    private
    def torrents
      @json[:arguments][:torrents] || [@json[:arguments][:'torrent-added']]
    end

    def torrents_response?
      @json && @json.key?(:arguments) && (@json[:arguments].key?(:torrents) || @json[:arguments].key?(:'torrent-added'))
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
end
