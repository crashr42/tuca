require 'spec_helper'

describe 'Tuca::Client' do
  def build_client(&block)
    if block_given?
      Tuca::Client.new @options[:rpc], @options[:username], @options[:password], &block
    else
      Tuca::Client.new @options[:rpc], @options[:username], @options[:password]
    end
  end

  arguments_map = {
      :session_set => [{}],
      :start => [nil],
      :start_now => [nil],
      :stop => [nil],
      :verify => [nil],
      :reannounce => [nil],
      :set => [nil, 'test', nil],
      :create => [{:filename => 'test.torrent'}],
      :move => [nil]
  }

  before(:each) { @options = {
      :rpc => 'http://localhost:9091/transmission/rpc',
      :username => 'transmission',
      :password => '123456'
  } }

  it 'should run reactor' do
    build_client do
      EM.reactor_running?.should == true
      EM.stop_event_loop
    end
  end

  it 'should not running reactor' do
    build_client
    EM.reactor_running?.should == false
  end

  context 'should do sync requests' do
    Tuca::Methods.public_instance_methods.each do |name|
      it name do
        client = build_client
        client.should_receive(:sync_request)
        client.stub(:sync_request).and_return(nil)
        if arguments_map.key?(name)
          client.send(name, *arguments_map[name])
        else
          client.send(name)
        end
      end
    end
  end

  context 'should do async requests' do
    Tuca::Methods.public_instance_methods.each do |name|
      it name do
        build_client do |client|
          client.stub(:async_request) { |_, &block| block.call }
          client.should_receive(:async_request)
          if arguments_map.key?(name)
            client.send(name, *arguments_map[name]) { client.disconnect }
          else
            client.send(name) { client.disconnect }
          end
        end
      end
    end
  end

  it 'should return valid statistic' do
    client = build_client
    client.stub(:sync_request).and_return({:a => 1})
    client.session_stats.should eq({:a => 1})
  end
end
