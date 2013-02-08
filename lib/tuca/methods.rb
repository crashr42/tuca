module Tuca
  module Methods
    def session_set(arguments, &block)
      body = {
          :method    => :'session-set',
          :arguments => arguments
      }

      push(body, &block)
    end

    def session_get(&block)
      body = {
          :method => :'session-get'
      }

      push(body, &block)
    end

    def blocklist_update(&block)
      body = {
          :method => :'blocklist-update'
      }

      push(body, &block)
    end

    def port_test(&block)
      body = {
          :method => :'port-test'
      }

      push(body, &block)
    end

    def session_stats(&block)
      body = {
          :method => :'session-stats'
      }

      push(body, &block)
    end

    def get(fields = Tuca::Torrent::ATTRIBUTES, id = nil, &block)
      fields = (fields + [:id, :name, :hashString, :status, :downloadedEver]).uniq
      body   = {
          :method    => :'torrent-get',
          :arguments => {
              :fields => fields
          }
      }
      body[:arguments][:ids] = format_id(id) unless id.nil?

      push(body, &block)
    end

    def start(id, &block)
      body = {
          :method    => :'torrent-start',
          :arguments => {
              :ids => format_id(id)
          }
      }

      push(body, &block)
    end

    def start_now(id, &block)
      body = {
          :method    => :'torrent-start-now',
          :arguments => {
              :ids => format_id(id)
          }
      }

      push(body, &block)
    end

    def stop(id, &block)
      body = {
          :method    => :'torrent-stop',
          :arguments => {
              :ids => format_id(id)
          }
      }

      push(body, &block)
    end

    def verify(id, &block)
      body = {
          :method    => :'torrent-verify',
          :arguments => {
              :ids => format_id(id)
          }
      }

      push(body, &block)
    end

    def reannounce(id, &block)
      body = {
          :method    => :'torrent-reannounce',
          :arguments => {
              :ids => format_id(id)
          }
      }

      push(body, &block)
    end

    def set(id, property, value, &block)
      body = {
          :method    => :'torrent-set',
          :arguments => {
              :ids            => format_id(id),
              property.to_sym => value
          }
      }

      push(body, &block)
    end

    def create(arguments, &block)
      raise "Undefined filename or metainfo" unless arguments.key?(:filename) || arguments.key?(:metainfo)
      arguments.delete(:filename) if arguments.key?(:metainfo) && arguments.key?(:filename)

      body = {
          :method    => :'torrent-add',
          :arguments => arguments
      }

      push(body, &block)
    end

    def delete(id = nil, delete_local_data = false, &block)
      body = {
          :method    => :'torrent-remove',
          :arguments => {
              :delete_local_data => delete_local_data
          }
      }
      body[:arguments][:ids] = format_id(id) unless id.nil?

      push(body, &block)
    end

    def move(location, id = nil, move = true, &block)
      body = {
          :method    => :'torrent-set-location',
          :arguments => {
              :location => location
          }
      }
      body[:arguments][:ids] = format_id(id) unless id.nil?
      body[:arguments][:move] = move unless move.nil?

      push(body, &block)
    end
  end
end