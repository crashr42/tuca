require 'spec_helper'
require_relative '../lib/Tuca'

describe 'Tuca::Client' do
  before(:each) { @client = Tuca::Client.new 'http://localhost:9091/transmission/rpc', 'transmission', '123456' }

  it 'should return valid statistic' do
    @client.stub(:push).and_return(double(:body => '{"a": 1}'))
    @client.session_stats.should eq({"a" => 1})
  end
end
