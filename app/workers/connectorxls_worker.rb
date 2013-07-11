class ConnectorxlsWorker
  include Sidekiq::Worker
  def perform(filename)
      Synergy1c7Connector::Connection.new.parse_xls(filename)
  end
end


