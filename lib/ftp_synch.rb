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
        buses = ftp.list("bus/**.xlsx")
        discs = ftp.list("discs/**.xlsx")
        batteries = ftp.list("acb/**.xlsx")
        lambs = ftp.list("lambs/**.xlsx")
        instruments = ftp.list("instruments/**.xlsx")
        autocosmetics = ftp.list("autocosmetics/**.xlsx")
        hoods = ftp.list("hoods/**.xlsx")

        catalogs = ftp.list("catalogs/*.xml")
        catalog_updates = ftp.list("catalog_updates/*.xml")
        backorder_catalog = ftp.list("backorder_catalog/*.xml")

        categories = ftp.list("categories/*.xlsx")
        quantity = ftp.list("quantity/*.xlsx")
        backorder_tie = ftp.list("backorder_tie/*.xlsx")
        backorder_disk = ftp.list("backorder_disk/*.xlsx")




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
        
        Dir.chdir(Rails.root.join('public','uploads', 'bus'))
        buses.each do |detail|
          ftp.getbinaryfile(detail.split.last)
          ftp.delete(detail.split.last)
        end
        Dir.chdir(Rails.root.join('public','uploads', 'discs'))
        discs.each do |detail|
          ftp.getbinaryfile(detail.split.last)
          ftp.delete(detail.split.last)
        end
        Dir.chdir(Rails.root.join('public','uploads', 'acb'))
        batteries.each do |detail|
          ftp.getbinaryfile(detail.split.last)
          ftp.delete(detail.split.last)
        end
        Dir.chdir(Rails.root.join('public','uploads', 'lambs'))
        lambs.each do |detail|
          ftp.getbinaryfile(detail.split.last)
          ftp.delete(detail.split.last)
        end
        
        Dir.chdir(Rails.root.join('public','uploads', 'instruments'))
        instruments.each do |detail|
          ftp.getbinaryfile(detail.split.last)
          ftp.delete(detail.split.last)
        end

        Dir.chdir(Rails.root.join('public','uploads', 'autocosmetics'))
        autocosmetics.each do |file|
          ftp.getbinaryfile(file.split.last)
          ftp.delete(file.split.last)
        end

        Dir.chdir(Rails.root.join('public','uploads', 'catalogs'))
        catalogs.each do |catalog|
          ftp.getbinaryfile(catalog.split.last)
          ftp.delete(catalog.split.last)
        end

        Dir.chdir(Rails.root.join('public','uploads', 'catalog_updates'))
        catalog_updates.each do |catalog|
          ftp.getbinaryfile(catalog.split.last)
          ftp.delete(catalog.split.last)
        end

        Dir.chdir(Rails.root.join('public','uploads', 'hoods'))
        hoods.each do |file|
          ftp.getbinaryfile(file.split.last)
          ftp.delete(file.split.last)
        end
        Dir.chdir(Rails.root.join('public','uploads', 'categories'))
        categories.each do |file|
          ftp.getbinaryfile(file.split.last)
          ftp.delete(file.split.last)
        end

        Dir.chdir(Rails.root.join('public','uploads', 'quantity'))
        quantity.each do |file|
          ftp.getbinaryfile(file.split.last)
          ftp.delete(file.split.last)
        end
        Dir.chdir(Rails.root.join('public','uploads', 'backorder_tie'))
        backorder_tie.each do |file|
          ftp.getbinaryfile(file.split.last)
          ftp.delete(file.split.last)
        end
        
        Dir.chdir(Rails.root.join('public','uploads', 'backorder_disk'))
        backorder_disk.each do |file|
          ftp.getbinaryfile(file.split.last)
          ftp.delete(file.split.last)
        end
        
        Dir.chdir(Rails.root.join('public','uploads', 'backorder_catalog'))
        backorder_catalog.each do |file|
          ftp.getbinaryfile(file.split.last)
          ftp.delete(file.split.last)
        end
        puts 'End downloading'
        ftp.close
      end

  end
end

