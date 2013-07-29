#encoding: UTF-8
require 'net/ftp'
module FtpSynch
  class Get

      def try_download
        ftp = Net::FTP.open(Spree::Config[:ftp_host],Spree::Config[:ftp_login],Spree::Config[:ftp_password])
        ftp.binary = true
        ftp.passive = true
        puts 'Start downloading'
        Dir.chdir(Rails.root.join('public','uploads'))

        files = ftp.list('*.xml')
        files.each do |file|
          ftp.getbinaryfile(file.split.last)
          ftp.delete(file.split.last)
        end

        files = ftp.list('*.xlsx')
        files.each do |file|
          ftp.getbinaryfile(file.split.last)
          ftp.delete(file.split.last)
        end

        puts 'End downloading'
        ftp.close
      end

  end
end

