class String
  def underscore
    self.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase
  end
end

class Symbol
  def underscore
    self.to_s.underscore.to_sym
  end
end

require 'json'
require 'net/http'
require 'em-http-request'
require 'tuca/methods'
require 'tuca/client'
require 'tuca/response'
require 'tuca/torrent'