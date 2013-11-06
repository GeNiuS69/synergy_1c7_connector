#encoding: UTF-8
require 'spree_core'

module Synergy1c7Connector
  class Engine < Rails::Engine



    uploads_root = 

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
      # FtpSynch::Get.new.try_download
      Dir.chdir(Rails.root.join('public','uploads'))

      # files = Dir.glob('*.xml')
      # files.each do |file|
      #   self.parse_xml(file)
      # end

      details = Dir.glob('details/**.xlsx')
      oils = Dir.glob("oils/**.xlsx")
      buses = Dir.glob("bus/**.xlsx")
      discs = Dir.glob("discs/**.xlsx")
      batteries = Dir.glob("acb/**.xlsx")
      lambs = Dir.glob("lambs/**.xlsx")
      instruments = Dir.glob("instruments/**.xlsx")
      rus = Dir.glob("rus/**.xlsx")


      details.each do |file|
        self.parse_detail(file)
      end

      oils.each do |file|
        self.parse_oil(file)
      end

      buses.each do |file|
        self.parse_bus(file)
      end

      discs.each do |file|
        self.parse_disc(file)
      end

      batteries.each do |file|
        self.parse_battery(file)
      end

      lambs.each do |file|
        self.parse_lamb(file)
      end

      instruments.each do |file|
        self.parse_instrument(file)
      end

      rus.each do |file|
        self.parse_detail(file)
      end

    end

    def initialize
      @xml_string = ""
    end


    ########################Parsers################################


    def parse_detail(filename)

      puts "Begin parse details XLSX: " + filename
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

      detail = init_detail(table)

      parse_original_numbers(detail,table["ориг. номера"])
      parse_analogs(detail,table["код аналога"])

      if table["агрегатный уровень"].first
        agr_levels = table["агрегатный уровень"].first.split(/[\\]/)
      else
        agr_levels = []
      end

      parse_agr_levels(detail, agr_levels, table)

      File.delete("#{Rails.root}/public/uploads/#{filename}")
      puts "End parse details XLSX: " + filename

    end

    def parse_oil(filename)
      puts "Begin parse oils XLSX: " + filename

      xls = RubyXL::Parser.parse("#{Rails.root}/public/uploads/#{filename}")[0]
      table = xls.get_table(["код","наименование","аналог","оригинальный номер", "тип","производитель","состав","вязкость","объем,л"])
     
      oil = self.init_detail(table)
      parse_original_numbers(oil, table["оригинальный номер"])
      parse_analogs(oil, table["аналог"])

      taxon_type_name = oil_type_taxon(table["тип"].first)
      maker = table["производитель"].first
      agip = table["вязкость"].first

      params = [taxon_type_name, maker, agip]

      get_taxons("Масла", params, oil)

      File.delete("#{Rails.root}/public/uploads/#{filename}")
      puts "End parse oils XLSX: " + filename

    end 

    def parse_bus(filename)
      puts "Begin parse bus XLSX: " + filename
      xls = RubyXL::Parser.parse("#{Rails.root}/public/uploads/#{filename}")[0]
      table = xls.get_table(["код","наименование","артикул","код аналога", "ориг. номера","производитель","профиль","высота","диаметр", "сезонность"])

      bus = self.init_detail(table)
      parse_original_numbers(bus, table["ориг. номера"])

      parse_analogs(bus, table ["код аналога"])

      root = "шины"
      width = table["диаметр"].first.to_s
      profile = table["профиль"].first.to_s
      height = table["высота"].first.to_s
      season = table["сезонность"].first

      params = [root, width, height, profile, season]

      get_taxons("колеса", params, bus)

      File.delete("#{Rails.root}/public/uploads/#{filename}")
      puts "End parse bus XLSX: " + filename
    end

    def parse_disc(filename)
      puts "Begin parse disc XLSX: " + filename
      xls = RubyXL::Parser.parse("#{Rails.root}/public/uploads/#{filename}")[0]
      table = xls.get_table(["код","наименование","артикул","код аналога",
       "оригинальный номер","производитель","тип","диаметр","ширина", "PCD", "вылет (ET)", "ДЦО"])

      disc = self.init_detail(table)
      parse_original_numbers(disc, table["оригинальный номер"])
      parse_analogs(disc, table["код аналога"])

      root = "диски"
      diameter = table["диаметр"].first.to_s
      width = table["ширина"].first.to_s
      pcd = table["PCD"].first.to_s
      et = table["вылет (ET)"].first.to_s
      dco = table["ДЦО"].first.to_s
      
      params = [root, diameter, width, pcd, et, dco]

      get_taxons("колеса", params, disc)


      File.delete("#{Rails.root}/public/uploads/#{filename}")
      puts "End parse disc XLSX: " + filename
    end

    def parse_battery(filename)
      puts "Begin parse battery XLSX: " + filename

      xls = RubyXL::Parser.parse("#{Rails.root}/public/uploads/#{filename}")[0]
      table = xls.get_table(
        ["код","наименование","артикул","код аналога",
          "оригинальный номер","производитель","полярность","емкость","длина",
            "ширина", "высота", "вес", "Пусковой ток"])

      battery = self.init_detail(table)
      parse_original_numbers(battery, table["оригинальный номер"])
      parse_analogs(battery, table["код аналога"])

      params = [table["емкость"].first.to_s, table["полярность"].first]

      get_taxons("Аккумаляторные батареи", params, battery)



      properties = {
        "емкость" => table["емкость"].first.to_s,
        "длина" => table["длина"].first.to_s,
        "ширина" => table["ширина"].first.to_s,
        "высота" => table["высота"].first.to_s,
        "вес" => table["вес"].first.to_s
      }

      self.add_properties(battery, properties)

      File.delete("#{Rails.root}/public/uploads/#{filename}")
      puts "End parse battery XLSX: " + filename

    end

    def parse_lamb(filename)
      puts "Begin parse lamb XLSX: " + filename

      xls = RubyXL::Parser.parse("#{Rails.root}/public/uploads/#{filename}")[0]
      table = xls.get_table(        
        ["код","наименование","артикул","код аналога", 
          "оригинальный номер","производитель","тип1","тип2","V",
            "W", "Патрон"])


      lamb = self.init_detail(table)

      parse_original_numbers(lamb, table["оригинальный номер"])
      parse_analogs(lamb, table["код аналога"])    

      type2 = table["тип2"].first

      table[:table].each do |table|
        unless table.empty?        
          unless table["тип2"].nil?
            type2 = table["тип2"]
          end
          params = [table["тип1"], type2]
          get_taxons("Лампы", params, lamb)
        end
      end



      properties = {
        "напряжение" => table["V"].first.to_s,
        "мощность" => table["W"].first.to_s
      }

      add_properties(lamb, properties)

      File.delete("#{Rails.root}/public/uploads/#{filename}")
      puts "End parse lamb XLSX: " + filename    
    end

    def parse_instrument(filename)
      puts "Begin parse instrument XLSX: " + filename

      xls = RubyXL::Parser.parse("#{Rails.root}/public/uploads/#{filename}")[0]
      table = xls.get_table(        
        ["код","наименование","артикул","код аналога", 
          "оригинальный номер","производитель"])

      instrument = init_detail(table)

      parse_original_numbers(instrument, table["оригинальный номер"])
      parse_analogs(instrument, table["код аналога"])    

      params = xls[1][6].value.split(/[\\]/)

      get_taxons("Инструмент", params, instrument)


      File.delete("#{Rails.root}/public/uploads/#{filename}")
      puts "End parse instrument XLSX: " + filename    
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
        if(number.to_s.include? "+e")
            return
        end
        number = Spree::OriginalNumber.where(:number => number.to_s).first_or_create
        unless product.original_numbers.find_by_id(number.id)

          product.original_numbers << number
        end
      end
    end

    def parse_agr_levels(detail, agr_levels, table)

      table[:table].each do |auto|
        unless auto.empty?
          region = maker_country(auto["марка"])

          if region == :eng
            car = Spree::CarMaker.find_or_create_by_name(auto["марка"]).car_models.find_or_create_by_name(auto["модель"]).car_modifications.where(:name => auto["модификация"], :engine_displacement => auto["объем двигателя см3"],:volume => auto["объем двигателя, л"], :engine_type => auto["топливо"], :hoursepower => auto["л.с."], :power => auto["кВт"], :body_style => auto["тип кузова"], :start_production => Date.strptime(auto["начало выпуска"],'%Y.%m'), :end_production => auto["конец выпуска"].eql?('-') ? nil : Date.strptime(auto["конец выпуска"],'%Y.%m')).first_or_create
          else
            maker = rus_maker_name(auto["марка"])
            car = Spree::CarMaker.find_or_create_by_name(maker.to_s).car_models.find_or_create_by_name("отечественная").car_modifications.where(:name => auto["модификация"].to_s).first_or_create
          end
          detail.car_modifications << car


          if car.taxonomy_id.nil? 
            if region == :eng
              taxonomy = Spree::Taxonomy.create(:name => " #{car.car_model.car_maker.name} #{car.car_model.name} #{car.name}")
            else
              taxonomy = Spree::Taxonomy.create(:name => " #{car.car_model.car_maker.name} #{car.name}")
            end
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

      puts "getting taxons"
      get_taxons("Аггрегатный уровень", agr_levels, detail)
    end

    def get_taxons(taxonomy_name, params, item)
      
      taxonomy = Spree::Taxonomy.find_or_create_by_name(taxonomy_name)
      taxons = taxonomy.taxons
      root_taxon = taxons.where('parent_id IS ?',nil).first

      first_level = params.shift
      unless first_level.nil?
        taxon = taxons.where(:parent_id => root_taxon, :name => first_level, :permalink => root_taxon.permalink + '/' + first_level.to_url).first_or_create
        parent = taxon
      end

      params.each do |param|
        unless param.nil?
          taxon = taxons.where(:parent_id => parent.id, :name => param, :permalink => parent.permalink + '/' + param.to_url).first_or_create
          parent = taxon
        end
      end  

      taxon.products << item

    end

    def add_properties(item, properties)
      properties.each { |key, value| item.set_property(key, value) }
    end
      
    def init_detail(table)
      detail = Spree::Product.where(:code_1c => table["код"].first.to_s).first_or_initialize
      detail.name = table["наименование"].first
      detail.permalink = table["наименование"].first.to_url

      unless table["артикул"].nil?
        detail.sku = table["артикул"].first || ''
      end

      detail.price ||= 0
      detail.available_on = Time.now
      detail.save
      return detail
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

    def oil_type_taxon(cell)
      case cell
        when "моторное"
          return "Моторные масла"
        when "трансмиссионное"
          return "Трансмиссионные масла"
        when "тосол"
          return "Тосол"
        when "антифриз"
          return "Антифриз"
        else "стеклоомывающая жидкость"
          return "Стеклоомывающая жидкость"
      end
    end

    def maker_country(maker)
      rus = ["камаз", "kamaz", "автоваз", "avtovaz", "lada", "uaz", "уаз",
              "газ", "gaz", "ваз"]
      rus.include?(maker.strip.mb_chars.downcase) ? :ru : :eng
    end

    def rus_maker_name(maker)
      vaz = ["ваз", "автоваз", "lada"]
      vaz.include?(maker.strip.mb_chars.downcase) ? "автоваз" : maker
    end

  end
end
