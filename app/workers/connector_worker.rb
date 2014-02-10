class ConnectorWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :autoshopparser

 
  def perform
      Synergy1c7Connector::Connection.new.parse_with_ftp_copy
  end
end


