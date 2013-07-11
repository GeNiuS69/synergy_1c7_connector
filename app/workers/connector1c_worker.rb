class Connector1cWorker
  include Sidekiq::Worker
  def perform(filename)
      Synergy1c7Connector::Connection.new.parse_xml(filename)
  end
end


