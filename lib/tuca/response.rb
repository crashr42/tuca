module Tuca
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
          torrents.each { |t| yield Tuca::Torrent.new(@connection, t) }
        else
          ts = []
          torrents.each { |t| ts << Tuca::Torrent.new(@connection, t) }
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
end