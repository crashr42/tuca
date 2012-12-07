$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$:.unshift(File.dirname(__FILE__))

require 'tuca'

EventMachine.run do
  client = Tuca::Client.new 'http://localhost:9091/transmission/rpc', 'transmission', '123456'
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
  response = client.create({:filename => '/home/nikita/Downloads/[rutracker.org].t3498008.torrent'})
  response.success { |result| puts "#{result} ---" }
  response.error { |code, message| puts "Error (#{code}) #{message}" }
  response.duplicate { puts "Torrent duplicate" }
end