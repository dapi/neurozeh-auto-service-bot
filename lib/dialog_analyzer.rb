# frozen_string_literal: true

class DialogAnalyzer
  # Паттерны для извлечения информации из диалога
  PATTERNS = {
    # Марки автомобилей (популярные в России)
    car_brands: /\b(toyota|hyundai|kia|bmw|mercedes|lada|renault|daewoo|chevrolet|honda|nissan|volkswagen|audi|mazda|ford|mitsubishi|skoda|opel|peugeot|citroen|suzuki|subaru|lexus|infiniti|acura|jaguar|land rover|volvo|mini|smart|porsche|ferrari|lamborghini|maserati|bentley|rolls-royce|bugatti)\b/i,

    # Модели автомобилей (популярные)
    car_models: {
      'toyota' => /\b(camry|corolla|land cruiser|prado|hilux|hiace|yaris|auris|avensis|verso|rav4|highlander|sienna|sequoia|tacoma|tundra)\b/i,
      'hyundai' => /\b(solaris|creta|santa fe|elantra|i20|i30|i40|accent|sonata|genesis|equus|tucson|ix35|ix55|getz|matrix|veloster)\b/i,
      'kia' => /\b(rio|optima|sorento|sportage|ceed|pro_ceed|picanto|mohave|carnival|sedona|cerato|k2|k3|k5|k7|k9)\b/i,
      'lada' => /\b(granta|kalina|vesta|largus|priora|samara|niva|2101|2102|2103|2104|2105|2106|2107|2109|2110|2114|2115)\b/i,
      'renault' => /\b(logan|sandero|duster|megane|laguna|clio|symbol|captur|kaptur|arkana|koleos|espace|scenic|trafic|master)\b/i,
      'bmw' => /\b(1-series|2-series|3-series|4-series|5-series|6-series|7-series|x1|x2|x3|x4|x5|x6|x7|z4|i3|i8)\b/i,
      'mercedes' => /\b(a-class|b-class|c-class|e-class|s-class|cla|cls|slk|slk|sl|glc|gle|gls|gla|glk|ml|gl|viano|vito|sprinter)\b/i,
      'nissan' => /\b(almera|primera|qashqai|murano|pathfinder|x-trail|juke|note|micra|tiida|patrol|armada|frontier|terra|sentra|altima|maxima)\b/i,
      'honda' => /\b(civic|accord|cr-v|hr-v|pilot|odyssey|fit|jazz|city|br-v|hr-v|insight|legend|nsx|s2000)\b/i,
      'volkswagen' => /\b(golf|polo|passat|jetta|tiguan|touareg|bora| Santana|lavida|magotan|phaeton|up!|beetle|scirocco|eos|amarok|crafter|transporter)\b/i
    },

    # Годы выпуска
    years: /\b(19|20)\d{2}\b/,

    # Пробег
    mileage: /\b(\d{1,3}(?:[ ,]\d{3})*|\d{4,6})\s*(км|km|тыс\.?|тысяч|thousand)\b/i,

    # Типы услуг
    services: {
      'диагностика' => /\b(диагностика|проверка|осмотр|тест|компьютерная диагностика|сканирование)\b/i,
      'ремонт' => /\b(ремонт|восстановление|починка|исправление|устранение)\b/i,
      'замена' => /\b(замена|установка|монтаж|постановка|сменить)\b/i,
      'то' => /\b(то|техобслуживание|техническое обслуживание|сервис|обслуживание)\b/i,
      'покраска' => /\b(покраска|окраска|малярные работы|покрасить|окрасить)\b/i,
      'антикор' => /\b(антикор|антикоррозийная обработка|антикоррозия|обработка от коррозии)\b/i,
      'тормоза' => /\b(тормоз|тормозная система|колодки|диски|суппорт|трубки|жидкость)\b/i,
      'подвеска' => /\b(подвеска|амортизатор|рычаг|стойка|пружина|шаровой|шаровая опора|сайлентблок)\b/i,
      'двигатель' => /\b(двигатель|мотор|двс|ремонт двигателя|капитальный ремонт)\b/i,
      'трансмиссия' => /\b(коробка|кпп|акпп|мкпп|вариатор|робот|сцепление)\b/i,
      'кузов' => /\b(кузов|бампер|крыло|дверь|капот|крышка багажника|порог|крыша)\b/i,
      'электрика' => /\b(электрика|электричество|проводка|генератор|стартер|аккумулятор|батарея)\b/i,
      'шины' => /\b(шины|колеса|диски|шина|колесо|замена резины|шиномонтаж)\b/i,
      'масло' => /\b(масло|замена масла|масляный фильтр|маслосъемные)\b/i,
      'фильтры' => /\b(фильтр|воздушный фильтр|салонный фильтр|топливный фильтр|масляный фильтр)\b/i
    }
  }

  # Классификация автомобилей по марке и модели
  CAR_CLASSES = {
    1 => { # Малые и средние авто
      brands: ['lada', 'daewoo', 'renault', 'chevrolet'],
      models: ['rio', 'solaris', 'logan', 'aveo', 'granta', 'kalina', 'vesta', 'priora', 'almera', 'sandero'],
      description: 'малые и средние авто'
    },
    2 => { # Бизнес-класс и кроссоверы
      brands: ['toyota', 'honda', 'hyundai', 'kia', 'nissan'],
      models: ['camry', 'accord', 'optima', 'creta', 'qashqai', 'sorento', 'tucson', 'sportage', 'elantra', 'sonata'],
      description: 'бизнес-класс и кроссоверы'
    },
    3 => { # Представительские, внедорожники, минивены
      brands: ['bmw', 'mercedes', 'land rover', 'volvo', 'lexus'],
      models: ['7-series', 's-class', 'range rover', 'xc90', 'lx', 'land cruiser', 'prado', 'x5', 'x7', 'gle', 'gls'],
      description: 'представительские, внедорожники, минивены, микроавтобусы'
    }
  }

  def initialize(logger = nil)
    @logger = logger || Logger.new(IO::NULL)
  end

  # Основной метод извлечения информации об автомобиле
  def extract_car_info(conversation_history)
    @logger.debug "Extracting car info from conversation"

    car_info = {
      make_model: extract_make_model(conversation_history),
      year: extract_year(conversation_history),
      mileage: extract_mileage(conversation_history)
    }

    # Определяем класс автомобиля
    car_class = determine_car_class(car_info[:make_model])
    car_info[:class] = car_class[:class]
    car_info[:class_description] = car_class[:description]

    @logger.debug "Car info extracted: #{car_info.inspect}"
    car_info
  end

  # Извлечение необходимых услуг из диалога
  def extract_services(conversation_history)
    @logger.debug "Extracting services from conversation"

    services = []
    conversation_history ||= []
    conversation_history.each do |message|
      next unless message[:role] == 'user'

      message_services = extract_services_from_text(message[:content])
      services.concat(message_services)
    end

    services = services.uniq
    @logger.debug "Services extracted: #{services.inspect}"
    services
  end

  # Извлечение контекста диалога
  def extract_dialog_context(conversation_history)
    return "" if conversation_history.empty?

    # Берем только сообщения пользователя для контекста
    user_messages = conversation_history.select { |msg| msg[:role] == 'user' }
    return "" if user_messages.empty?

    # Формируем краткое описание проблемы
    last_message = user_messages.last[:content]

    # Если сообщение короткое, используем его как есть
    if last_message.length <= 200
      last_message
    else
      # Обрезаем длинное сообщение
      last_message[0..197] + "..."
    end
  end

  private

  # Извлечение марки и модели автомобиля
  def extract_make_model(conversation_history)
    make_model = { make: nil, model: nil }

    conversation_history.each do |message|
      next unless message[:role] == 'user'
      text = message[:content]

      # Ищем марку автомобиля
      brand_match = text.match(PATTERNS[:car_brands])
      if brand_match
        make_model[:make] = brand_match[1].downcase

        # Ищем модель для найденной марки
        model_pattern = PATTERNS[:car_models][make_model[:make]]
        if model_pattern
          model_match = text.match(model_pattern)
          make_model[:model] = model_match[1] if model_match
        end

        break # Нашли марку, прекращаем поиск
      end
    end

    # Формируем полное название
    if make_model[:make] && make_model[:model]
      "#{make_model[:make].capitalize} #{make_model[:model].capitalize}"
    elsif make_model[:make]
      make_model[:make].capitalize
    else
      nil
    end
  end

  # Извлечение года выпуска
  def extract_year(conversation_history)
    conversation_history.each do |message|
      next unless message[:role] == 'user'

      year_match = message[:content].match(PATTERNS[:years])
      return year_match[0] if year_match && valid_year?(year_match[0])
    end
    nil
  end

  # Извлечение пробега
  def extract_mileage(conversation_history)
    conversation_history.each do |message|
      next unless message[:role] == 'user'

      mileage_match = message[:content].match(PATTERNS[:mileage])
      if mileage_match
        # Очищаем и форматируем пробег
        mileage = mileage_match[1].gsub(/[ ,]/, '')
        if valid_mileage?(mileage)
          return format_mileage(mileage)
        end
      end
    end
    nil
  end

  # Извлечение услуг из текста
  def extract_services_from_text(text)
    services = []

    PATTERNS[:services].each do |service_type, pattern|
      if text.match(pattern)
        services << service_type.capitalize
      end
    end

    services
  end

  # Определение класса автомобиля
  def determine_car_class(make_model)
    return { class: nil, description: nil } unless make_model

    make_model_lower = make_model.downcase

    CAR_CLASSES.each do |class_num, class_info|
      # Проверяем по марке
      if class_info[:brands] && class_info[:brands].any? { |brand| make_model_lower.include?(brand) }
        return { class: class_num, description: class_info[:description] }
      end

      # Проверяем по модели
      if class_info[:models] && class_info[:models].any? { |model| make_model_lower.include?(model) }
        return { class: class_num, description: class_info[:description] }
      end
    end

    { class: nil, description: 'требуется уточнение' }
  end

  # Проверка валидности года
  def valid_year?(year)
    year_num = year.to_i
    year_num >= 1970 && year_num <= Time.now.year + 1
  end

  # Проверка валидности пробега
  def valid_mileage?(mileage)
    mileage_num = mileage.to_i
    mileage_num >= 0 && mileage_num <= 1000000
  end

  # Форматирование пробега
  def format_mileage(mileage)
    mileage_num = mileage.to_i
    if mileage_num >= 1000
      "#{mileage_num / 1000} #{mileage_num % 1000 >= 100 ? '' : ' '}000 км"
    else
      "#{mileage_num} км"
    end
  end
end