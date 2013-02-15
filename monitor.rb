$:.unshift(File.join(File.dirname(__FILE__), 'lib'))
$:.unshift(File.join(File.dirname(__FILE__), 'examples'))
$:.unshift(File.dirname(__FILE__))

require 'daemons'

options = {
    :app_name => 'transmission_monitor',
    :backtrace => true,
    :log_output => true,
    :dir_mode => :normal,
    :dir => File.dirname(__FILE__)
}

file = File.expand_path('tmp/daemon.sock', File.dirname(__FILE__))
File.unlink(file) if File.exists?(file)

Daemons.run(File.expand_path('examples/main.rb', File.dirname(__FILE__)), options)