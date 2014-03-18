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
      FtpSynch::Get.new.try_download
      Dir.chdir(Rails.root.join('public','uploads'))


      details = Dir.glob('details/**.xlsx')
      oils = Dir.glob("oils/**.xlsx")
      buses = Dir.glob("bus/**.xlsx")
      discs = Dir.glob("discs/**.xlsx")
      batteries = Dir.glob("acb/**.xlsx")
      lambs = Dir.glob("lambs/**.xlsx")
      instruments = Dir.glob("instruments/**.xlsx")
      autocosmetics = Dir.glob('autocosmetics/*.xlsx')
      hoods = Dir.glob("hoods/*xlsx")
      catalogs = Dir.glob('catalogs/*.xml')
      categories = Dir.glob('categories/*.xlsx')
      quantity = Dir.glob('quantity/*.xlsx')

      details.each_with_index do |file, index|
        self.parse_detail(file, index)
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

      autocosmetics.each do |file|
        self.parse_autocosmetic(file)
      end
      catalogs.each do |catalog|
        self.parse_xml(catalog)
      end
      hoods.each do |hood|
        self.parse_hood(hood)
      end

      categories.each do |category|
        self.parse_category(category)
      end
      quantity.each do |quantity|
        self.parse_quantity(quantity)
      end

    end


    def initialize
      @xml_string = ""
    end


    ########################Parsers################################


    def parse_detail(filename, index = 0)

      puts Time.now.strftime("%y %m %d %h:%m:%s: ") + "Begin parse details XLSX: " + filename + " (" + (index+1).to_s + ")" 

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

      table = xls.get_table(["марка","модель","модификация","начало выпуска","конец выпуска","кВт","л.с.","объем двигателя, л","объем двигателя см3","топливо","тип кузова", "агрегатный уровень"])

      if table.nil?
        puts "Wrong table format!"
        File.delete("#{Rails.root}/public/uploads/#{filename}")
        return
      end

      if check_unique(table)
        puts "Detail with same name and different 1C code!"
        File.delete("#{Rails.root}/public/uploads/#{filename}")
        return
      end

      detail = init_detail(table)
      detail.taxons.clear
      detail.car_modifications.clear
      parse_original_numbers(detail, table["ориг. номера"])
      parse_analogs(detail, table["код аналога"])

      parse_agr_levels(detail, table)
      File.delete("#{Rails.root}/public/uploads/#{filename}")
      puts "End parse details XLSX: " + filename

    end

    def parse_oil(filename)
      puts "Begin parse oils XLSX: " + filename

      xls = RubyXL::Parser.parse("#{Rails.root}/public/uploads/#{filename}")[0]
      table = xls.get_table(["код","наименование","артикул","аналог","оригинальный номер", "тип","производитель","состав","вязкость","объем,л"])
     
      if table.nil?
        puts "Wrong table format!"
        File.delete("#{Rails.root}/public/uploads/#{filename}")
        return
      end

      oil = self.init_detail(table)
      oil.set_property("объем", table["объем,л"].first)
      oil.taxons.clear
      parse_original_numbers(oil, table["оригинальный номер"])
      parse_analogs(oil, table["аналог"])

      taxon_type_name = table["тип"].first.split(/[\\]/)



      params = ["Масло", taxon_type_name]
      params = params.flatten


      params.each_with_index do |param, index|
        unless param.nil?
          params[index] = param.slice(0,1).mb_chars.capitalize.to_s + param.slice(1..-1)
        end
      end

      get_taxons("Масла, спецжидкости и автокосметика", params, oil)

      File.delete("#{Rails.root}/public/uploads/#{filename}")
      puts "End parse oils XLSX: " + filename

    end 

    def parse_autocosmetic(filename)
      puts "Begin parse autocosmetic xlsx: " + filename
      
      xls = RubyXL::Parser.parse("#{Rails.root}/public/uploads/#{filename}")[0]
      table = xls.get_table(["код","наименование", "артикул","код аналога","оригинальный номер", "производитель","группа"])
     
      if table.nil?
        puts "Wrong table format!"
        File.delete("#{Rails.root}/public/uploads/#{filename}")
        return
      end

      autocosmetic = self.init_detail(table)
      autocosmetic.taxons.clear

      parse_original_numbers(autocosmetic, table["оригинальный номер"])
      parse_analogs(autocosmetic, table["код аналога"])

      group = table["группа"].first
      params = ["Автохимия и автокосметика", group]

      params.each_with_index do |param, index|
        unless param.nil?
          params[index] = param.slice(0,1).mb_chars.capitalize.to_s + param.slice(1..-1)
        end
      end
      get_taxons("Масла, спецжидкости и автокосметика", params, autocosmetic)

      File.delete("#{Rails.root}/public/uploads/#{filename}")
      puts "End parse autocosmetics XLSX: " + filename
    end

    def parse_bus(filename)
      puts "Begin parse bus XLSX: " + filename
      xls = RubyXL::Parser.parse("#{Rails.root}/public/uploads/#{filename}")[0]
      table = xls.get_table(["код","наименование","артикул","код аналога", "ориг. номера","производитель","профиль","высота","диаметр", "сезонность", "шипы"])

      if table.nil?
        puts "Wrong table format!"
        File.delete("#{Rails.root}/public/uploads/#{filename}")
        return
      end

      bus = self.init_detail(table)
      bus.taxons.clear
      parse_original_numbers(bus, table["ориг. номера"])


      unless table["шипы"].first.nil?
        bus.set_property("шипы", "шип.")
      end

      parse_analogs(bus, table ["код аналога"])


      root = "Автошины"
      width = table["диаметр"].first.to_s
      profile = table["профиль"].first.to_s
      height = table["высота"].first.to_s
      season = table["сезонность"].first

      subtitles = [nil, "Диаметр", "Ширина", "Профиль", "Сезонность"]

      params = [root, width, profile, height, season]
      if params.any?{|param| param.nil?}
        puts 'param is empty!'
        File.delete("#{Rails.root}/public/uploads/#{filename}")

        return
      end
      if params.any?{|param| param.empty?}
        puts 'param is empty!'
        File.delete("#{Rails.root}/public/uploads/#{filename}")
        return
      end


      get_taxons("Колеса", params, bus, nil, subtitles)

      File.delete("#{Rails.root}/public/uploads/#{filename}")
      puts "End parse bus XLSX: " + filename
    end

    def parse_hood(filename)
      puts "Begin parse hood XLSX: " + filename
      xls = RubyXL::Parser.parse("#{Rails.root}/public/uploads/#{filename}")[0]
      table = xls.get_table(["код","наименование","артикул","код аналога", "оригинальный номер","производитель", "Диаметр"])

      if table.nil?
        puts "Wrong table format!"
        File.delete("#{Rails.root}/public/uploads/#{filename}")
        return
      end

      hood = self.init_detail(table)
      hood.taxons.clear
      parse_original_numbers(hood, table["оригинальный номер"])

      parse_analogs(hood, table ["код аналога"])


      root = "Колпаки"
      width = table["Диаметр"].first.to_s

      subtitles = [nil, "Диаметр"]

      params = [root, width]

      if params.any?{|param| param.nil?}
        puts 'param is empty!'
        File.delete("#{Rails.root}/public/uploads/#{filename}")

        return
      end

      if params.any?{|param| param.empty?}
        puts 'param is empty!'
        File.delete("#{Rails.root}/public/uploads/#{filename}")
        return
      end


      get_taxons("Колеса", params, hood, nil, subtitles)

      File.delete("#{Rails.root}/public/uploads/#{filename}")
      puts "End parse hood XLSX: " + filename
    end


    def parse_disc(filename)
      puts "Begin parse disc XLSX: " + filename
      xls = RubyXL::Parser.parse("#{Rails.root}/public/uploads/#{filename}")[0]
      table = xls.get_table(["код","наименование","артикул","код аналога",
       "оригинальный номер","производитель","тип","диаметр","ширина", "PCD", "вылет (ET)", "ДЦО"])

      if table.nil?
        puts "Wrong table format!"
        File.delete("#{Rails.root}/public/uploads/#{filename}")
        return
      end

      disc = self.init_detail(table)
      disc.taxons.clear
      parse_original_numbers(disc, table["оригинальный номер"])
      parse_analogs(disc, table["код аналога"])
      root = "Диски"
      diameter = table["диаметр"].first.to_s
      width = table["ширина"].first.to_s
      pcd = table["PCD"].first.to_s
      et = table["вылет (ET)"].first.to_s
      dco = table["ДЦО"].first.to_s
      
      params = [root, diameter, width, pcd, et, dco]
      subtitles = [nil, "Диаметр", "Ширина", "PCD", "Вылет (ET)", "Диаметр центрального отверстия"]


      get_taxons("Колеса", params, disc, nil, subtitles)


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


      if table.nil?
        puts "Wrong table format!"
        File.delete("#{Rails.root}/public/uploads/#{filename}")
        return
      end

      battery = self.init_detail(table)
      battery.taxons.clear
      parse_original_numbers(battery, table["оригинальный номер"])
      parse_analogs(battery, table["код аналога"])

      params = [table["емкость"].first.to_s, table["полярность"].first]
      subtitles = ["Емкость, А/Ч", "Полярность"]

      get_taxons("Аккумуляторные батареи", params, battery, nil, subtitles)



      properties = {
        "вес" => table["вес"].first.to_s,
        "высота" => table["высота"].first.to_s,
        "ширина" => table["ширина"].first.to_s,
        "длина" => table["длина"].first.to_s,
        "емкость" => table["емкость"].first.to_s
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

      if table.nil?
        puts "Wrong table format!"
        File.delete("#{Rails.root}/public/uploads/#{filename}")
        return
      end


      lamb = self.init_detail(table)
      lamb.taxons.clear
      parse_original_numbers(lamb, table["оригинальный номер"])
      parse_analogs(lamb, table["код аналога"])    

      type2 = table["тип2"].first
      params_array = []
      table["тип1"].compact.each do |type|
        params = [type, type2]
        params_array << params
      end      

      params_array.each do |params|
        get_taxons("Лампы", params, lamb)
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


      if table.nil?
        puts "Wrong table format!"
        File.delete("#{Rails.root}/public/uploads/#{filename}")
        return
      end

      instrument = init_detail(table)
      instrument.taxons.clear

      parse_original_numbers(instrument, table["оригинальный номер"])
      parse_analogs(instrument, table["код аналога"])    

      params = xls[1][6].value.split(/[\\]/)

      get_taxons("Инструмент", params, instrument)


      File.delete("#{Rails.root}/public/uploads/#{filename}")
      puts "End parse instrument XLSX: " + filename    
    end

    def parse_xml(filename)

        Spree::StockItem.update_all(:count_on_hand => 0)
        Spree::Price.update_all(:amount => 0)
        xml = Nokogiri::XML.parse(File.read("#{Rails.root}/public/uploads/#{filename}"))
        # Parsing
        details = xml.css("ДЕТАЛЬ")
        details.each_with_index do |detail, index|
          code_1c = detail.css("КОД").first.text
          product = Spree::Product.where(:code_1c => code_1c).first
          unless product.nil?
            product.price = detail.css("ЦЕНА").first.text.to_d

            product.save(:validate => false)
            unless product.stock_items.first.nil?
              product.stock_items.first.update_attribute(:count_on_hand,detail.css("ОСТАТОК").first.text.to_i) 
            end
          end

          #product.name = detail.css("НАЗВАНИЕ").first.text
          #product.sku = detail.css("АРТИКУЛ").first.text
          #product.permalink = detail.css("АРТИКУЛ").first.text + detail.css("НАЗВАНИЕ").first.text.to_url
          #product.deleted_at = nil
          #product.available_on = Time.now
          #parse_analogs(product,detail.css("АНАЛОГИ"))
          #parse_original_numbers(product,detail.css("ОРИГИНАЛЬНЫЕ_НОМЕРА"))

        end
        File.delete("#{Rails.root}/public/uploads/#{filename}")
        puts "End parse XML: " + filename
      end

      def parse_category(filename)
        puts "Begin parse categories XLSX: " + filename

        xls = RubyXL::Parser.parse("#{Rails.root}/public/uploads/#{filename}")[0]
        table = xls.get_table(["код","название", "категория"])
        table[:table].each_with_index do |t, index|
          product = Spree::Product.where(:code_1c => t["код"].to_s).first
          if product
            product.discount_category = t["категория"]
            product.save
            puts index
          end
        end
      File.delete("#{Rails.root}/public/uploads/#{filename}")
      puts "End parse instrument XLSX: " + filename    
      end

      def parse_quantity(filename)
        puts "Begin parse quantity XLSX: " + filename

          xls = RubyXL::Parser.parse("#{Rails.root}/public/uploads/#{filename}")[0]
          table = xls.get_table(["код","название", "количество"])
          table[:table].each_with_index do |t, index|
            product = Spree::Product.where(:code_1c => t["код"].to_s).first
            if product
              product.min_quantity = t["количество"]
              product.save
              puts index
            end
          end
        File.delete("#{Rails.root}/public/uploads/#{filename}")
        puts "End parse instrument XLSX: " + filename    
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

    def parse_agr_levels(detail, table)
      previous_levels = []
      table[:table].each do |auto|
         unless auto.empty?
            agr_field = auto["агрегатный уровень"]
            unless agr_field.nil?
              unless agr_field.empty?
                agr_levels = agr_field.split(/[\\]/)
                previous_levels = agr_levels.dup

              end
            else
              agr_levels = previous_levels.dup
            end


          unless auto["модификация"].nil?
            puts Time.now.strftime("%y %m %d %h:%m:%s: ") + "Start getting "  + auto["модификация"].to_s 
          end  
          region = maker_country(auto["марка"])

          unless region == :none

            if region == :eng
              start_production = auto["начало выпуска"].eql?('-') ? nil : Date.strptime(auto["начало выпуска"],'%Y.%m')
              end_production = auto["конец выпуска"].eql?('-') ? nil : Date.strptime(auto["конец выпуска"],'%Y.%m')
              maker = Spree::CarMaker.find_or_create_by_name(auto["марка"])
              model = maker.car_models.find_or_create_by_name(auto["модель"])
              car = model.car_modifications.where(:name => auto["модификация"]).first_or_create
              car.engine_displacement = auto["объем двигателя см3"].to_s
              car.volume = auto["объем двигателя, л"]
              car.engine_type = auto["топливо"]
              car.hoursepower = auto["л.с."]
              car.power = auto["кВт"]
              car.body_style = auto["тип кузова"]
              car.start_production = start_production
              car.end_production = end_production
              car.save
            elsif region == :ru
              maker = rus_maker_name(auto["марка"]).to_s
              model = auto["модель"].to_s
              modification_name = maker + ' ' + model
              car = Spree::CarMaker.find_or_create_by_name(maker).car_models.find_or_create_by_name(model).car_modifications.where(:name => modification_name).first_or_create
              maker = car.car_model.car_maker
              maker.country = 'ru'
              maker.save
            end
            detail.car_modifications << car 
          end
          get_taxons("Сборочная группа", agr_levels, detail, car)

         end 
      end



     end

    def get_taxons(taxonomy_name, params, item, modification = nil, subtitles = nil)

      if params.empty?
        puts 'No aggregate levels'
        return
      end

      taxonomy = Spree::Taxonomy.find_or_create_by_name(taxonomy_name)
      taxons = taxonomy.taxons
      root_taxon = taxons.where('parent_id IS ?',nil).first
      unless subtitles.nil?
        root_taxon.subtitle = subtitles.shift
        root_taxon.save
      end
      first_level = params.shift
      unless first_level.nil?
        taxon = taxons.where(:parent_id => root_taxon, :name => first_level, :permalink => root_taxon.permalink + '/' + first_level.to_url).first_or_create
        taxon.products << item
        taxon.car_modifications << modification unless modification.nil?
        unless subtitles.nil?
          taxon.subtitle = subtitles.shift 
          taxon.save
        end
        parent = taxon

      end
      params.each_with_index do |param, index|
        unless param.nil?
          taxon = taxons.where(:parent_id => parent.id, :name => param, :permalink => parent.permalink + '/' + param.to_url).first_or_create
          taxon.car_modifications << modification unless modification.nil?
          unless subtitles.nil?
            taxon.subtitle = subtitles[index] 
            taxon.save
          end
          taxon.products << item

          parent = taxon

        end
      end  
      taxon.products << item
      taxon
    end

    def add_properties(item, properties)
      properties.each { |key, value| item.set_property(key, value) }
    end
      
    def init_detail(table)
      detail = Spree::Product.where(:code_1c => table["код"].first.to_s).first_or_initialize
      detail.name = table["наименование"].first

      detail.permalink = table["наименование"].first.to_url
      detail.sku = ""
      unless table["артикул"].nil?
        detail.sku = table["артикул"].first.try(:to_s) unless table["артикул"].first.nil?
          table["артикул"].compact.each_with_index do |sku, index|
            sku_temp = Spree::Sku.where(:value => sku.to_s).first_or_create
            detail.skus << sku_temp
          end
      end



      detail.price ||= 0
      detail.available_on = Time.now

      detail.save
      detail
    end

    def check_unique(table)
      detail = Spree::Product.where(:code_1c => table["код"].first.to_s).first_or_initialize
      permalink = table["наименование"].first.to_url
      permalink_detail = Spree::Product.where("permalink=?", permalink).first
      return false if permalink_detail.nil?
      return false if detail.code_1c == permalink_detail.code_1c 
      true
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

    def maker_country(maker = "eng")
      rus = ["камаз", "kamaz", "автоваз", "avtovaz", "lada", "uaz", "уаз",
              "газ", "gaz", "ваз"]
      return rus.include?(maker.strip.mb_chars.downcase) ? :ru : :eng unless maker.nil?
      :none
    end

    def rus_maker_name(maker)
      vaz = ["ваз", "автоваз", "lada"]
      vaz.include?(maker.strip.mb_chars.downcase) ? "ВАЗ" : maker
    end

  end
end
