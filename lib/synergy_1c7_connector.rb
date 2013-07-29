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
      puts 'Start parse xml!'
      xml = Nokogiri::XML.parse(File.read("#{Rails.root}/public/uploads/#{filename}"))
      # Parsing
      details = xml.css("ДЕТАЛЬ")
      details.each do |detail|

        product = Spree::Product.where(:code_1c => detail.css("КОД").first.text).first_or_initialize
        product.name = detail.css("НАЗВАНИЕ").first.text
        product.sku = detail.css("АРТИКУЛ").first.text
        product.price = detail.css("ЦЕНА").first.text.to_d
        product.permalink = detail.css("АРТИКУЛ").first.text + detail.css("НАЗВАНИЕ").first.text.to_url
        product.deleted_at = nil
        product.available_on = Time.now
        product.save

        parse_analogs(product,detail.css("АНАЛОГИ"))
        parse_original_numbers(product,detail.css("ОРИГИНАЛЬНЫЕ_НОМЕРА"))

      end
      File.delete("#{Rails.root}/public/uploads/#{filename}")
    end


    def parse_xls(filename)
      xls = RubyXL::Parser.parse("#{Rails.root}/public/uploads/#{filename}")[0]

      table = xls.get_table(["марка","модель","модификация","год начала выпуска","год окончания выпуска","мощность, кВт","мощность, Л.с.","объем двигателя","топливо","тип кузова", "код двигателя"])

      detail = Spree::Product.find_by_code_1c(table["код 1С"].first.to_s)

      agr_levels = table["агрегатная сборочна группа по уровням"].first.split('; ')

      table[:table].each do |auto|
        unless auto.empty?
          car = Spree::CarMaker.find_or_create_by_name(auto["марка"]).car_models.find_or_create_by_name(auto["модель"]).car_modifications.where(:name => auto["модификация"],:engine_model => auto["код двигателя"].to_s, :engine_displacement => auto["объем двигателя"], :engine_type => auto["топливо"], :hoursepower => auto["мощность, Л.с."], :body_style => auto["тип кузова"], :start_production => Date.strptime(auto["год начала выпуска"],'%Y.%m'), :end_production => Date.strptime(auto["год окончания выпуска"],'%Y.%m')).first_or_create
          detail.car_modifications << car
          detail.update_attributes(:name => table["Наименование"])

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



    def parse_analogs(product,xml_analogs)
      xml_analogs.css("КОД").each_with_index do |analog,ind|
        analog_product = Spree::Product.find_by_code_1c(analog.text)
        if analog_product.nil?
          analog_product = Spree::Product.new(:name => 'temporarily-' + ind.to_s + '-' + product.code_1c, :permalink => 'temporarily-' + ind.to_s + '-' + product.code_1c, :code_1c => analog.text, :deleted_at => nil, :price => 0)
          analog_product.save(:validate => false)
        end
        product.products << analog_product
      end
    end

    def parse_original_numbers(product,xml_original_numbers)
      xml_original_numbers.css("НОМЕР").each do |number|
        number = Spree::OriginalNumber.create(:number => number.text, :model => number.attributes["МАРКА"].text)
        product.original_numbers << number
      end
    end



    def parse_autos(xml_autos, detail)
      arg_lev_1 = detail.css("АГРЕГАТНЫЙ_УРОВЕНЬ_1").first.text
      arg_lev_2 = detail.css("АГРЕГАТНЫЙ_УРОВЕНЬ_2").first.text
      arg_lev_3 = detail.css("АГРЕГАТНЫЙ_УРОВЕНЬ_3").first.text

      xml_autos.each do |xml_auto|
        engine = xml_auto.css("ДВИГАТЕЛЬ")
        auto = Spree::CarMaker.find_or_create_by_name(xml_auto.css("МАРКА").first.text).car_models.find_or_create_by_name(xml_auto.css("МОДЕЛЬ").first.text).car_modifications.where(:engine_model => engine.css("МОДЕЛЬ").first.text, :engine_displacement => engine.css("ОБЪЕМ").first.text, :engine_type => engine.css("ТОПЛИВО").first.css, :hoursepower => engine.css("МОЩНОСТЬ_ЛС").first.text, :body_style => xml_auto.css("КУЗОВ").first.text, :start_production => Date.strptime(xml_auto.css('ДАТА_НАЧАЛА_ПРОИЗВОДСТВА').first.text,'%Y.%m'), :end_production => Date.strptime(xml_auto.css('ДАТА_ОКОНЧАНИЯ_ПРОИЗВОДСТВА').first.text,'%Y.%m') ).first_or_create


        detail.car_modifications << auto
        taxons = auto.taxonomy.taxons
        taxon1 = taxons.where(:parent_id => taxons.first.id, :name => agr_lev_1).first_or_create
        taxon2 = taxons.where(:parent_id => taxon1.id, :name => agr_lev_2 ).first_or_create
        taxon3 = taxons.where(:parent_id => taxon2.id, :name => agr_lev_3 ).first_or_create
        taxon3.products << detail


      end
    end
  end
end
