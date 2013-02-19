module Tuca
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
        1  => :check_wait,
        2  => :checked,
        4  => :download,
        8  => :seeded,
        16 => :stopped
    }

    STATUSES.each do |name|
      define_method("#{name}?".to_sym) { STATUSES[@fields[:status]] == name }
    end

    ATTRIBUTES.each do |name|
      define_method(name.underscore) { @fields[name] }
    end

    SETTABLE.each do |name|
      define_method "#{name.underscore}=".to_sym do |value|
        update_attribute(name, value)
        @fields[name] = value
      end
    end

    def initialize(connection, fields = {})
      @connection = connection
      @fields = fields
    end

    def [](key)
      @fields[key]
    end

    def []=(key, value)
      raise "Attribute #{key} is readonly" unless SETTABLE.include?(key)
      update_attribute(key, value)
      @fields[key] = value
    end

    def status
      STATUSES[@fields[:status]]
    end

    def save(&block)
      if new_torrent?
        saved_attributes = @fields.select { |key| SETTABLE.include?(key) || [:filename, :metainfo].include?(key) }
        result = @connection.create(saved_attributes)
        @fields.merge(result[:arguments][:'torrent-added']) if result.success?
        block.call(result)
      end
    end

    def start(&block)
      unless new_torrent?
        @connection.start(@fields[:id], &block)
      end
    end

    def start_now(&block)
      unless new_torrent?
        @connection.start_now(@fields[:id], &block)
      end
    end

    def stop(&block)
      unless new_torrent?
        @connection.stop(@fields[:id], &block)
      end
    end

    def delete(delete_local_data = false, &block)
      unless new_torrent?
        @connection.delete(@fields[:id], delete_local_data, &block)
      end
    end

    def move(location, move = true, &block)
      unless new_torrent?
        @connection.move(location, @fields[:id], move, &block)
      end
    end

    def new_torrent?
      !@fields.key?(:id) || @fields[:id].to_i < 0
    end

    def to_json
      @fields.to_json
    end

    private
    def update_attribute(key, value)
      @connection.set(@fields[:id], key, value) unless new_torrent?
    end
  end
end