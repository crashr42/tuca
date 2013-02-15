$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$:.unshift(File.dirname(__FILE__))

require 'tuca'

loop do
  cl = Tuca::Client.new 'http://localhost:9091/transmission/rpc', 'transmission', '123456'
  cl.get do |r|
    r.success { |result| puts "Status (#{result.id}): #{result.status}" }
    r.error { |code, message| puts "Error (#{code}) #{message} 11" }
    r.unauthorized { puts :unauthorized }
  end
  cl.added do |torrent|
    puts "New torrent: #{torrent.id}"
  end
  cl.exists do |torrent|
    puts "Exists torrent on transmission connection init: #{torrent.start_date}"
  end
  cl.deleted do |torrent|
    puts "Torrent was deleted: #{torrent.id}"
  end
  cl.stopped do |torrent|
    puts "Torrent was stopped: #{torrent.id}"
  end
  cl.started { |t| puts "Torrent started: #{t.inspect}" }
  cl.seeded { |t| puts "Torrent seeded: #{t.inspect}" }
  cl.progress { |t| puts "Torrent #{t.id} progress: #{t.downloaded_ever}" }
  cl.error { |code| puts "Getting code: #{code}" }
  cl.unauthorized { puts 'unauthorized' }
  cl.create({:filename => '/home/nikita/Downloads/[rutracker.org].t3498008.torrent'}) do |r|
    r.success { |result| puts result }
    r.error { |code, message| puts "Error (#{code}) #{message}" }
    r.duplicate { puts 'Torrent duplicate' }
    r.corrupt { puts 'File corrupt!!!' }
  end

  sleep(1)
end