class ParserWorker
  include Sidekiq::Worker
  sidekiq_options retry: false

  def perform(file)
	Synergy1c7Connector::Connection.new.parse_detail(file)

  end
end


