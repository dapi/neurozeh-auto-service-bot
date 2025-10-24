# frozen_string_literal: true

require 'csv'

class CostCalculator
  def initialize(price_list_path, logger = nil)
    @price_list_path = price_list_path
    @logger = logger || Logger.new(IO::NULL)
    @price_list = load_price_list
    @logger.info "CostCalculator initialized with #{@price_list.size} services"
  end

  # Основной метод расчета стоимости
  def calculate_cost(services, car_class)
    return nil unless services && services.any?
    return nil unless car_class

    @logger.debug "Calculating cost for #{services.size} services, car class #{car_class}"

    total = 0
    calculated_services = []

    services.each do |service|
      price_info = find_price(service, car_class)
      if price_info
        calculated_services << {
          name: "#{service} (#{car_class_description(car_class)})",
          price: format_price(price_info[:price]),
          original_name: service,
          price_raw: price_info[:price]
        }
        total += price_info[:price]
      else
        @logger.warn "Service not found in price list: #{service}"
        # Добавляем услугу с пометкой "по запросу"
        calculated_services << {
          name: "#{service} (расчет по запросу)",
          price: "по запросу",
          original_name: service,
          price_raw: 0
        }
      end
    end

    result = {
      services: calculated_services,
      total: total > 0 ? format_price(total) : "расчет по запросу",
      total_raw: total,
      note: "Окончательная стоимость определяется после диагностики",
      car_class: car_class
    }

    @logger.debug "Cost calculation result: #{result.inspect}"
    result
  end

  # Поиск услуги в прайс-листе
  def find_price(service_name, car_class)
    return nil unless @price_list[car_class]

    # Сначала ищем точное совпадение
    @price_list[car_class].each do |service|
      if service_matches?(service[:name], service_name)
        return service
      end
    end

    # Если точного совпадения нет, ищем по ключевым словам
    @price_list[car_class].each do |service|
      if fuzzy_service_match?(service[:name], service_name)
        return service
      end
    end

    nil
  end

  # Получение списка всех доступных услуг
  def available_services
    all_services = []
    @price_list.each do |car_class, services|
      services.each do |service|
        all_services << {
          name: service[:name],
          class: car_class,
          price: service[:price]
        }
      end
    end
    all_services
  end

  # Поиск услуг по ключевому слову
  def search_services(keyword)
    keyword_lower = keyword.downcase
    found_services = []

    available_services.each do |service|
      if service[:name].downcase.include?(keyword_lower)
        found_services << service
      end
    end

    found_services
  end

  private

  # Загрузка прайс-листа из CSV файла
  def load_price_list
    price_list = { 1 => [], 2 => [], 3 => [] }

    return price_list unless File.exist?(@price_list_path)

    begin
      CSV.foreach(@price_list_path, headers: false, encoding: 'UTF-8') do |row|
        next if row.empty? || row.all?(&:nil?)
        next if row[0]&.start_with?('Прайс лист', 'Все цены указаны', 'ПОКРАСКА', 'АНТИКОР', 'АНТИХРОМ', 'ДОПОЛНИТЕЛЬНЫЕ УСЛУГИ', 'ДОПОЛНИТЕЛЬНЫЕ РАБОТЫ')

        # Ищем строки с услугами
        if row[0] && !row[0].strip.empty? && row[1] && !row[1].strip.empty?
          service_name = row[0].strip
          prices = []

          # Собираем цены для всех классов
          (1..3).each do |class_num|
            price_cell = row[class_num]
            if price_cell && !price_cell.strip.empty?
              price_str = price_cell.strip
              price_num = parse_price(price_str)
              prices << price_num if price_num
            else
              prices << nil
            end
          end

          # Добавляем услугу в соответствующие классы
          (1..3).each do |class_num|
            if prices[class_num - 1]
              price_list[class_num] << {
                name: service_name,
                price: prices[class_num - 1],
                raw_price: row[class_num]&.strip
              }
            end
          end
        end
      end

      @logger.info "Loaded price list: #{price_list[1].size} services for class 1, #{price_list[2].size} for class 2, #{price_list[3].size} for class 3"
    rescue StandardError => e
      @logger.error "Error loading price list: #{e.message}"
    end

    price_list
  end

  # Парсинг цены из строки
  def parse_price(price_str)
    return nil unless price_str

    # Убираем "от" и другие префиксы
    clean_price = price_str.gsub(/^от\s*/i, '').gsub(/[^\d]/, '')

    # Преобразуем в число
    clean_price.to_i if clean_price.match(/^\d+$/)
  end

  # Проверка соответствия услуги
  def service_matches?(service_name, search_name)
    return false unless service_name && search_name
    service_name.downcase.strip == search_name.downcase.strip
  end

  # Нечеткое соответствие услуги
  def fuzzy_service_match?(service_name, search_name)
    return false unless service_name && search_name

    service_lower = service_name.downcase
    search_lower = search_name.downcase

    # Разбиваем на слова и проверяем вхождение
    search_words = search_lower.split(/\s+/)
    service_words = service_lower.split(/\s+/)

    # Проверяем, что все слова из поиска содержатся в названии услуги
    search_words && service_words && search_words.all? { |word| service_words.any? { |service_word| service_word.include?(word) || word.include?(service_word) } }
  end

  # Описание класса автомобиля
  def car_class_description(car_class)
    case car_class
    when 1
      "малые и средние авто"
    when 2
      "бизнес-класс и кроссоверы"
    when 3
      "представительские, внедорожники"
    else
      "неизвестный класс"
    end
  end

  # Форматирование цены
  def format_price(price)
    return "по запросу" if price.nil? || price.zero?

    # Форматируем число с пробелами
    formatted = price.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1 ').reverse
    "#{formatted} руб."
  end
end