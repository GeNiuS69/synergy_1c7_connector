class ConnectorWorker
  include Sidekiq::Worker
  sidekiq_options retry: false
  
  def perform
      Synergy1c7Connector::Connection.new.parse_with_ftp_copy
  end
end


