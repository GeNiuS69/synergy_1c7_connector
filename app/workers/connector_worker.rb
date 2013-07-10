module Spree::Admin
class ConnectorWorker
  include Sidekiq::Worker
  def perform
      Synergy1c7Connector::Connection.new.parse_xml
  end
end
end


