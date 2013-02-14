require 'spec_helper'
require 'tuca'

describe 'Tuca::Client' do
  before(:each) { @client = Tuca::Client.new 'http://localhost:9091/transmission/rpc', 'transmission', '123456' }

  it 'should return valid statistic' do
    @client.stub(:sync_request).and_return({:a => 1})
    @client.session_stats.should eq({:a => 1})
  end
end
