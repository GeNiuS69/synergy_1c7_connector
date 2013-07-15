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
        def parse_with_ftp_copy(path)
            FtpSynch::Get.new.dowload_dir(path)
            self.parse_xml
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
                  taxon = taxons.where(:parent_id => parent, :name => agr_lev, :permalink => arg_lev_to_url + '-' + car.id.to_s).first_or_create
                  parent = taxon.id
                end

                taxon.products << detail
            end
            end


            File.delete("#{Rails.root}/public/uploads/#{filename}")
        end

        def discharge(order)
            order.discharge = true
            order.save
            if order.user.juridical
                if !File.exist?('fromur.xml')
                    File.open('fromur.xml', 'w') {|f| f.write('') }
                end
                xml if File.read('fromur.xml').blank?
                create_ur_xml_discharge(order)
            else
                if !File.exist?('from.xml')
                    File.open('from.xml', 'w') {|f| f.write('') }
                end
                xml if File.read('from.xml').blank?
                create_xml_discharge(order)
            end
        end

        protected

        def tag(tag, attrs={}, &block)
            @xml_string << "<#{tag}"
            text = attrs.delete(:text)
            @xml_string << " " if not attrs.empty?
            attrs.each_pair do |key, value|
                @xml_string << "#{key.to_s}=\"#{value.to_s}\""
                @xml_string << " " if key != attrs.keys.last
            end
            @xml_string << ">"
            if block_given?
                block.arity < 1 ? self.instance_eval(&block) : block.call(self)
            end
            @xml_string << text.to_s
            @xml_string << "</#{tag}>"
        end

        private

        def xml
            @xml_string << "<?xml version=\"1.0\" encoding=\"windows-1251\"?><КоммерческаяИнформация ВерсияСхемы=\"2.04\" ДатаФормирования=\"#{Time.now.strftime('%F')}\">"
        end

        def get_property_values(xml_values)
            property_values = Hash.new
            xml_values.each do |xml_value|
                property_values["#{xml_value.css('ИдЗначения').text}"] = "#{xml_value.css('Значение').text}"
            end
            return property_values
        end

        def create_properties(xml_properties)
            xml_properties.each do |xml_property|
                property = Property.find_or_initialize_by_code_1c(xml_property.css("Ид").first.text)
                property.name = xml_property.css("Наименование").first.text
                property.presentation = property.name
                property.save
            end
        end

        def create_similar_taxons(taxon, taxon_copy_from)
            taxon_copy_from.children.each do |taxon_copy_from_child|
                name = taxon_copy_from_child.name
                if name.first.to_i != 0
                    if name.split.second == "PE"
                        name = name.split[2..10].join(" ")
                    else
                        name = name.split[1..10].join(" ")
                    end
                end
                new_taxon = Taxon.find_or_initialize_by_name_and_parent_id(name, taxon.id)
                new_taxon.parent_id = taxon.id
                new_taxon.taxonomy_id = taxon.taxonomy_id
                taxon_copy_from_child.products.each do |product|
                    if new_taxon.products.where(:id => product.id).blank?
                        new_taxon.products << product
                    end
                end
                new_taxon.save
                create_similar_taxons(new_taxon, taxon_copy_from_child)
            end
            Taxon.where(:name => 'РАСПРОДАЖА').where('taxons.parent_id is not null').destroy_all
        end
#########################################################

        def create_ur_xml_discharge(order)
            tag "Документ" do
                tag "Номер", :text => order.number
                tag "Дата", :text => order.created_at.strftime('%F')
                tag "ХозОперация", :text => "Заказ товара"
                tag "Роль", :text => "ПолныеПрава"
                tag "Валюта", :text => "руб"
                tag "Курс", :text => "1"
                tag "Сумма", :text => (order.total.to_s << "0").gsub(".", ",")
                tag "Контрагенты" do
                    tag "Контрагент" do
                        tag "Наименование", :text => order.user.recipient
                        tag "ОфициальноеНаименование", :text => order.user.recipient
                        tag "Роль", :text => "Клиент"
                        tag "ПолноеНаименование", :text => order.user.recipient
                        tag "АдресРегистрации" do
                            tag "Представление", :text => order.ship_address.address1
                            tag "АдресноеПоле" do
                                tag "Тип", :text => "Почтовый индекс"
                                tag "Значение", :text => order.ship_address.zipcode
                            end
                        end
                        tag "ИНН", :text => order.user.inn
                        tag "КПП", :text => order.user.kpp
                    end
                end
                # TODO: use strftime!!!
                hour = order.created_at.hour.to_s.size == 1 ? "0" << order.created_at.hour.to_s : order.created_at.hour.to_s
                min = order.created_at.min.to_s.size == 1 ? "0" << order.created_at.min.to_s : order.created_at.min.to_s

                sec = order.created_at.sec.to_s.size == 1 ? "0" << order.created_at.sec.to_s : order.created_at.sec.to_s
                time = hour << ":" << min << ":" << sec
                tag "Время", :text => time
                tag "Товары" do
                    order.line_items.each do |line_item|
                        tag "Товар" do
                            tag "Ид", :text => line_item.variant.code_1c
                            tag "Группы", :text => line_item.product.taxons.where("taxons.code_1c is not NULL").first.code_1c
                            tag "Наименование", :text => line_item.product.name.gsub("#{line_item.product.sku} ", '')
                            tag "БазоваяЕдиница", {"Код" => "796", "НаименованиеПолное" => "Штука", "МеждународноеСокращение" => "PCE", :text => "шт" }
                            tag "ЦенаЗаЕдиницу", :text => (line_item.price.to_s << "0").gsub(".", ",")
                            tag "Количество", :text => line_item.quantity
                            tag "Сумма", :text => ((line_item.quantity.to_f * line_item.price.to_f).to_s << "0").gsub(".", ",")
                            tag "ЗначенияРеквизитов" do
                                tag "ЗначениеРеквизита" do
                                    tag "Наименование", :text => "ВидНоменклатуры"
                                    tag "Значение", :text => "Бельё и колготки"
                                end
                                tag "ЗначениеРеквизита" do
                                    tag "Наименование", :text => "ТипНоменклатуры"
                                    tag "Значение", :text => "Товар"
                                end
                            end
                            tag "ХарактеристикиТовара" do
                                line_item.variant.option_values.each do |value|
                                    tag "ХарактеристикаТовара" do
                                        tag "Наименование", :text => value.option_type.name
                                        tag "Значение", :text => value.name
                                    end
                                end
                            end
                        end
                    end
                end
            end
            string = File.read("#{Rails.root}/fromur.xml")
            string << @xml_string
            File.open("#{Rails.root}/fromur.xml", 'w') { |f| f.write(string) }
        end

##########################################################
        def create_xml_discharge(order)
            tag "Документ" do
                tag "Номер", :text => order.number
                tag "Дата", :text => order.created_at.strftime('%F')
                tag "ХозОперация", :text => "Заказ товара"
                tag "Роль", :text => "ПолныеПрава"
                tag "Валюта", :text => "руб"
                tag "Курс", :text => "1"
                tag "Сумма", :text => (order.total.to_s << "0").gsub(".",",")
                tag "Контрагенты" do
                    tag "Контрагент" do
                        tag "Наименование", :text =>  (order.ship_address.try(:lastname) || "") + " " + (order.ship_address.try(:firstname) || "") + " " + (order.ship_address.try(:secondname) || "")
                        tag "Роль", :text => "Покупатель"
                        tag "ПолноеНаименование", :text => (order.ship_address.try(:lastname) || "") + " " + (order.ship_address.try(:firstname) || "") + " " + (order.ship_address.try(:secondname) || "")
                        tag "Фамилия", :text => order.ship_address.try(:lastname)
                        tag "Имя", :text => order.ship_address.try(:firstname)
                        tag "АдресРегистрации" do
                            tag "Представление", :text => order.ship_address.try(:address1)
                            tag "АдресноеПоле" do
                                tag "Тип", :text => "Почтовый индекс"
                                tag "Значение", :text => order.ship_address.try(:zipcode)
                            end
                        end
                    end
                end
                hour = order.created_at.hour.to_s.size == 1 ? "0" << order.created_at.hour.to_s : order.created_at.hour.to_s
                min = order.created_at.min.to_s.size == 1 ? "0" << order.created_at.min.to_s : order.created_at.min.to_s

                sec = order.created_at.sec.to_s.size == 1 ? "0" << order.created_at.sec.to_s : order.created_at.sec.to_s
                time = hour << ":" << min << ":" << sec
                tag "Время", :text => time
                tag "Товары" do
                    order.line_items.each do |line_item|
                        tag "Товар" do
                            tag "Ид", :text => line_item.variant.code_1c
                            tag "Группы", :text => line_item.product.taxons.where("taxons.code_1c is not NULL").first.code_1c
                            tag "Наименование", :text => line_item.product.name.gsub("#{line_item.product.sku} ", '')
                            tag "БазоваяЕдиница", {"Код" => "796", "НаименованиеПолное" => "Штука", "МеждународноеСокращение" => "PCE", :text => "шт" }
                            tag "ЦенаЗаЕдиницу", :text => (line_item.price.to_s << "0").gsub(".", ",")
                            tag "Количество", :text => line_item.quantity
                            tag "Сумма", :text => ((line_item.quantity.to_f * line_item.price.to_f).to_s << "0").gsub(".", ",")
                            tag "ЗначенияРеквизитов" do
                                tag "ЗначениеРеквизита" do
                                    tag "Наименование", :text => "ВидНоменклатуры"
                                    tag "Значение", :text => "Бельё и колготки"
                                end
                                tag "ЗначениеРеквизита" do
                                    tag "Наименование", :text => "ТипНоменклатуры"
                                    tag "Значение", :text => "Товар"
                                end
                            end
                            tag "ХарактеристикиТовара" do
                                line_item.variant.option_values.each do |value|
                                    tag "ХарактеристикаТовара" do
                                        tag "Наименование", :text => value.option_type.name
                                        tag "Значение", :text => value.name
                                    end
                                end
                            end
                        end
                    end
                end
            end
            string = File.read("#{Rails.root}/from.xml")
            string << @xml_string
            File.open("#{Rails.root}/from.xml", 'w') { |f| f.write(string) }
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

        def parse_groups_from_import_xml(groups, taxon)
            puts "parsing taxons for taxonomy: #{taxon.taxonomy.name} with id: #{taxon.taxonomy_id}"
            groups.each do |group|
                puts "parsing taxon: #{group.css("Наименование").first.text}"
                new_taxon = Taxon.find_or_create_by_code_1c(:code_1c => group.css("Ид").first.text, :name => group.css("Наименование").first.text, :taxonomy_id => taxon.taxonomy_id) {|t| t.parent = taxon }
                parse_groups_from_import_xml(group.css("Группы Группа"), new_taxon) if !group.css("Группы Группа").blank?
            end
        end

        def parse_products_offers_xml(products)
            products.each do |xml_product|
                product = Product.find_by_code_1c(xml_product.css("Ид").text.split('#').first)
                if !product.blank?

                    variant = Variant.find_or_initialize_by_code_1c(xml_product.css("Ид").text)
                    variant.product_id = product.id
                    prices = Array.new
                    prices << xml_product.css("ЦенаЗаЕдиницу").first.text.to_f
                    prices << xml_product.css("ЦенаЗаЕдиницу").last.text.to_f
                    prices.sort!
                    variant.cost_price = prices.first
                    variant.price = prices.last
                    if xml_product.css("Количество").text.blank?
                        puts "#{variant.product.name} count 0"
                        variant.count_on_hand = 0
                    else
                        variant.count_on_hand = xml_product.css("Количество").text if not xml_product.css("Количество").text.blank?
                        variant.deleted_at = nil
                        variant.product.update_attribute(:deleted_at, nil)
                    end
                    if variant.new_record?
                        xml_product.css("ХарактеристикаТовара").each do |option|
                            if ProductOptionType.where(:product_id => product.id, :option_type_id => OptionType.find_by_name(option.css("Наименование").text).id).blank?
                                product_option_type = ProductOptionType.new(:product => product, :option_type => OptionType.find_by_name(option.css("Наименование").text))
                                product_option_type.save
                            end
                            if OptionValue.find_by_name_and_option_type_id(option.css("Значение").text, OptionType.find_by_name(option.css("Наименование").text).id)
                                option_value = OptionValue.find_by_name_and_option_type_id(option.css("Значение").text, OptionType.find_by_name(option.css("Наименование").text).id)
                            else
                                option_value = OptionValue.create(:option_type_id => OptionType.find_by_name(option.css("Наименование").text).id, :name => option.css("Значение").text,:presentation => option.css("Значение").text)
                            end
                            variant.option_values << option_value
                        end
                    end
                    variant.save
                end
            end
        end

        def parse_products(products, property_values)
            products.each do |xml_product|
                product_if = Product.where(:code_1c => xml_product.css("Ид").first.text)
                product = Product.find_or_initialize_by_code_1c(xml_product.css("Ид").first.text)
                if product_if.blank? && !xml_product.css("Артикул").first.blank?
                    product.sku = xml_product.css("Артикул").first.text
                    product.name = product.sku + " " + xml_product.css("Наименование").first.text
                    puts "Parse product #{product.sku + " " + product.name}"
                    xml_product.css("ЗначенияСвойства").each do |xml_property|
                        property = product.product_properties.find_or_initialize_by_product_id_and_property_id(product.id, Property.find_by_code_1c(xml_property.css("Ид").text).id)
                        value = xml_property.css("Значение").text
                        property.value = value if not value.blank?
                        if not value.blank?
                            if property.value.length == 36
                                property.value = property_values.values_at(property.value).first
                            end
                        end
                        property.save
                    end
                    product.price = 0
                    images = xml_product.css("Картинка")
                    product.images.destroy_all if images.present?
                    images.each do |image|
                        puts "Parse image in path #{image.text}"
                        filename = image.text.split('/').last
                        image = File.open("#{Rails.root}/webdata/" + image.text)
                        puts filename
                        puts image
                        new_image = product.images.find_or_initialize_by_attachment_file_name(filename, :attachment => image)
                        puts new_image.save
                        puts new_image.errors
                        new_image.save
                        product.save
                    end
                    description = xml_product.css("Описание").first
                    if !description.blank?
                        product.description = description.text
                    end
                    product.available_on = Time.now
                    xml_product.css("Группы Ид").each do |xml_taxon|
                        if product.taxons.where(:code_1c => xml_taxon.text).blank?
                            product.taxons << Taxon.where(:code_1c => xml_taxon.text)
                        end
                    end
                    product.save!
                elsif !xml_product.css("Артикул").first.blank?
                    product.sku = xml_product.css("Артикул").first.text
                    product.name = product.sku + " " + xml_product.css("Наименование").first.text
                    xml_product.css("ЗначенияСвойства").each do |xml_property|
                        property = product.product_properties.find_or_initialize_by_product_id_and_property_id(product.id, Property.find_by_code_1c(xml_property.css("Ид").text).id)
                        value = xml_property.css("Значение").text
                        property.value = value
                        if not value.blank?
                            if property.value.length == 36
                                property.value = property_values.values_at(property.value).first
                            end
                        end
                        property.save if not value.blank?
                    end
                    images = xml_product.css("Картинка")
                    puts "Parse product #{product.sku + " " + product.name}"
                    product.images.destroy_all if images.present?
                    images.each do |image|
                        puts "Parse image in path #{image.text}"
                        filename = image.text.split('/').last
                        image = File.open("#{Rails.root}/webdata/" + image.text)
                        puts filename
                        puts image
                        new_image = product.images.find_or_initialize_by_attachment_file_name(filename, :attachment => image)
                        puts new_image.save
                        puts new_image.errors
                        new_image.save
                        product.save
                    end

                    description = xml_product.css("Описание").first
                    if !description.blank?
                        product.description = description.text
                    end
                    # Update taxon only have non-empty code_1c attribute
                    xml_product.css("Группы Ид").each do |xml_taxon|
                        if product.taxons.where(:code_1c => xml_taxon.text).blank?
                            product.taxons << Taxon.where(:code_1c => xml_taxon.text)
                        end
                    end
                    product.save
                end
            end
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
