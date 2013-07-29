Spree::AppConfiguration.class_eval do
  preference :ftp_host, :string
  preference :ftp_login, :string
  preference :ftp_password, :string
end
