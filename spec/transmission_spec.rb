require 'spec_helper'
require_relative '../lib/transmission'

describe 'Transmission::Client' do
  before(:each) { @client = Transmission::Client.new 'http://localhost:9091/transmission/rpc', 'transmission', '123456' }

  it 'should return valid statistic' do
    @client.stub(:push).and_return(double(:body => '{"a": 1}'))
    @client.session_stats.should eq({"a" => 1})
  end
end
