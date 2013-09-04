#encoding: UTF-8
require 'spree_core'

module Synergy1c7Connector
  class Engine < Rails::Engine

    config.autoload_paths += %W(#{config.root}/lib)

    def self.activate
      Dir.glob(File.join(File.dirname(__FILE__), "../app/**/*_decorator*.rb")) do |c|
        Rails.env.production? ? require(c) : load(c)
      end
    end

    config.to_prepare &method(:activate).to_proc
  end

  class Connection
    def parse_with_ftp_copy
      FtpSynch::Get.new.try_download
      Dir.chdir(Rails.root.join('public','uploads'))

      files = Dir.glob('*.xml')
      files.each do |file|
        self.parse_xml(file)
      end

      files = Dir.glob('*.xlsx')
      files.each do |file|
        self.parse_xls(file)
      end

    end
    def initialize
      @xml_string = ""
    end
    def parse_xml(filename)
      set_product_price
      puts 'Begin parse XML: ' + filename
      xml = Nokogiri::XML.parse(File.read("#{Rails.root}/public/uploads/#{filename}"))
      # Parsing
      details = xml.css("ДЕТАЛЬ")
      details.each do |detail|

        code_1c = detail.css("КОД").first.text
        product = Spree::Product.where(:code_1c => code_1c).first_or_initialize
        product.name ||= code_1c
        product.permalink ||= code_1c

        #product.name = detail.css("НАЗВАНИЕ").first.text
        #product.sku = detail.css("АРТИКУЛ").first.text
        product.price = detail.css("ЦЕНА").first.text.to_d
        #product.permalink = detail.css("АРТИКУЛ").first.text + detail.css("НАЗВАНИЕ").first.text.to_url
        #product.deleted_at = nil
        #product.available_on = Time.now
        product.save(:validate => false)
        product.stock_items.first.update_attribute(:count_on_hand,detail.css("ОСТАТОК").first.text.to_i)
        #parse_analogs(product,detail.css("АНАЛОГИ"))
        #parse_original_numbers(product,detail.css("ОРИГИНАЛЬНЫЕ_НОМЕРА"))

      end
      File.delete("#{Rails.root}/public/uploads/#{filename}")
      puts "End parse XML: " + filename
    end


    def parse_xls(filename)
      puts "Begin parse XLSX: " + filename
      xls = RubyXL::Parser.parse("#{Rails.root}/public/uploads/#{filename}")[0]
      if xls.sheet_data[0].compact.empty?
        xls.delete_row(0)
      end
      if xls.sheet_data[1].compact.empty?
        xls.delete_row(1)
      end
      if xls.sheet_data[2].compact.empty?
        xls.delete_row(2)
      end

      table = xls.get_table(["марка","модель","модификация","начало выпуска","конец выпуска","кВт","л.с.","объем двигателя, л","объем двигателя см3","топливо","тип кузова"])

      detail = Spree::Product.where(:code_1c => table["код"].first.to_s).first_or_initialize
      detail.name = table["наименование"].first
      detail.permalink = table["наименование"].first.to_url
      detail.sku = table["артикул"].first || ''
      detail.price ||= 0
      detail.available_on = Time.now
      detail.save

      parse_original_numbers(detail,table["ориг. номера"])
      parse_analogs(detail,table["код аналога"])

      if table["агрегатный уровень"]
        agr_levels = table["агрегатный уровень"].first.split(/[\\]/)
      else
        agr_levels = []
      end

      table[:table].each do |auto|
        unless auto.empty?
          car = Spree::CarMaker.find_or_create_by_name(auto["марка"]).car_models.find_or_create_by_name(auto["модель"]).car_modifications.where(:name => auto["модификация"], :engine_displacement => auto["объем двигателя см3"],:volume => auto["объем двигателя, л"], :engine_type => auto["топливо"], :hoursepower => auto["л.с."], :power => auto["кВт"], :body_style => auto["тип кузова"], :start_production => Date.strptime(auto["начало выпуска"],'%Y.%m'), :end_production => auto["конец выпуска"].eql?('-') ? nil : Date.strptime(auto["конец выпуска"],'%Y.%m')).first_or_create

          detail.car_modifications << car
          if car.taxonomy_id.nil?
            taxonomy = Spree::Taxonomy.create(:name => " #{car.car_model.car_maker.name} #{car.car_model.name} #{car.name}")
            car.update_attributes(:taxonomy_id => taxonomy.id)
          end

          taxons = car.taxonomy.taxons

          taxon = taxons.where('parent_id IS ?',nil).first
          parent = taxon.id

          agr_levels.each do |agr_lev|
            taxon = taxons.where(:parent_id => parent, :name => agr_lev, :permalink => agr_lev.to_url + '-' + car.id.to_s).first_or_create
            parent = taxon.id
          end

          taxon.products << detail
        end
      end


      File.delete("#{Rails.root}/public/uploads/#{filename}")
      puts "End parse XLSX: " + filename
    end

    def set_product_price
      Spree::Product.all.each do |product|
        unless product.variants.blank?
          price = 0
          cost_price = 0
          product.variants.each do |var|
            price = var.price if var.price.to_i != 0
            cost_price = var.cost_price if var.cost_price.to_i != 0
          end
          product.price = price
          product.cost_price = cost_price
          product.save
        end
      end
    end




    ########################Autoshop################################



    def parse_analogs(product,analogs)
      analogs.each_with_index do |analog,ind|
        analog_product = Spree::Product.find_by_code_1c(analog.to_s)
        if analog_product.nil?
          analog_product = Spree::Product.new(:name => 'temporarily-' + ind.to_s + '-' + product.code_1c, :permalink => 'temporarily-' + ind.to_s + '-' + product.code_1c, :code_1c => analog.to_s, :deleted_at => nil, :price => 0)
          analog_product.save(:validate => false)
        end
        unless product.products.find_by_id(analog_product.id)
          product.products << analog_product
        end
      end
    end

    def parse_original_numbers(product,originals)
      originals.each do |number|
        number = Spree::OriginalNumber.where(:number => number.to_s).first_or_create
        unless product.original_numbers.find_by_id(number.id)
          product.original_numbers << number
        end
      end
    end

  end
end
