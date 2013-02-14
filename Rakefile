#!/usr/bin/env rake
task :default do
  puts 'Please, using \'rake -P\' for show all tasks.'
end

desc 'Generate test torrent file.'
task :generate_fixtures do
  require 'fileutils'

  fixtures_path = "#{File.dirname(__FILE__)}/spec/fixtures"
  FileUtils.rm_rf fixtures_path if Dir.exist?(fixtures_path)
  FileUtils.mkpath fixtures_path
  1.upto(5) { |i| File.open("#{fixtures_path}/test_#{i}.txt", 'w') { |f| f.write("This is #{i} test file!") } }

  `transmission-create -o spec/fixtures/test.torrent -t http://10.110.1.90:6969/announce spec/fixtures`
end