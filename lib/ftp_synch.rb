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

        oils = ftp.list('oils/*.xlsx')
        details = ftp.list('details/*.xlsx')

        Dir.chdir(Rails.root.join('public','uploads', 'oils'))
        oils.each do |oil|
          ftp.getbinaryfile(oil.split.last)
          ftp.delete(oil.split.last)
        end

        Dir.chdir(Rails.root.join('public','uploads', 'details'))
        details.each do |detail|
          ftp.getbinaryfile(detail.split.last)
          ftp.delete(detail.split.last)
        end

        puts 'End downloading'
        ftp.close
      end

  end
end

