# frozen_string_literal: true

# Тестовые сценарии для проверки обогащенных заявок
# Используются для валидации функциональности DialogAnalyzer и CostCalculator

module TestScenarios
  # Сценарий 1: Полная информация
  def self.full_info_scenario
    {
      description: "Полная информация об авто и услугах",
      conversation: [
        { role: "user", content: "Здравствуйте! У меня Toyota Camry 2018 года. Нужно сделать диагностику подвески и заменить передние тормозные колодки. Пробег 85 тыс. км." },
        { role: "assistant", content: "Хорошо, я помогу вам с диагностикой подвески и заменой тормозных колодок." }
      ],
      expected_car_info: {
        make_model: "Toyota Camry",
        year: "2018",
        class: 2,
        class_description: "бизнес-класс и кроссоверы",
        mileage: "85 000 км"
      },
      expected_services: [
        "Диагностика подвески",
        "Замена передних тормозных колодок"
      ],
      expected_cost: {
        services: [
          { name: "Диагностика подвески", price: "от 1000" },
          { name: "Замена передних тормозных колодок", price: "от 1500" }
        ],
        total: "от 2500",
        note: "Окончательная стоимость определяется после диагностики"
      }
    }
  end

  # Сценарий 2: Частичная информация
  def self.partial_info_scenario
    {
      description: "Только марка автомобиля и общее описание проблемы",
      conversation: [
        { role: "user", content: "Проблема с тормозами на Hyundai, нужно проверить" },
        { role: "assistant", content: "Понимаю, проблемы с тормозами нужно срочно проверить." }
      ],
      expected_car_info: {
        make_model: "Hyundai",
        class: nil, # Требуется уточнение модели
        class_description: nil,
        mileage: nil
      },
      expected_services: [
        "Проверка тормозной системы"
      ],
      expected_cost: nil # Нельзя рассчитать без класса авто
    }
  end

  # Сценарий 3: Минимальная информация
  def self.minimal_info_scenario
    {
      description: "Только запрос на диагностику без информации об авто",
      conversation: [
        { role: "user", content: "Хочу записаться на диагностику" },
        { role: "assistant", content: "Хорошо, запишу вас на диагностику." }
      ],
      expected_car_info: {
        make_model: nil,
        class: nil,
        class_description: nil,
        mileage: nil
      },
      expected_services: [
        "Диагностика"
      ],
      expected_cost: nil
    }
  end

  # Сценарий 4: Диалог с уточнением класса авто
  def self.class_clarification_scenario
    {
      description: "Пользователь не знает класс авто, бот помогает определить",
      conversation: [
        { role: "user", content: "У меня Lada, нужно сделать покраску бампера" },
        { role: "assistant", content: "Lada относится к 1 классу (малые и средние авто). Покраска бампера для 1 класса стоит 18000 руб." },
        { role: "user", content: "Хорошо, записывайте" }
      ],
      expected_car_info: {
        make_model: "Lada",
        class: 1,
        class_description: "малые и средние авто",
        mileage: nil
      },
      expected_services: [
        "Покраска бампера"
      ],
      expected_cost: {
        services: [
          { name: "Покраска бампера (1 класс)", price: "18000" }
        ],
        total: "18000",
        note: "Окончательная стоимость определяется после диагностики"
      }
    }
  end

  # Сценарий 5: Несколько услуг из разных категорий
  def self.multiple_services_scenario
    {
      description: "Несколько услуг из разных категорий прайс-листа",
      conversation: [
        { role: "user", content: "BMW X5, пробег 120 тыс. Нужно сделать антикор комплексную обработку и реставрацию фар" },
        { role: "assistant", content: "BMW X5 относится к 3 классу. Комплексная антикоррозийная обработка для 3 класса стоит 40000 руб, реставрация фар от 5000 руб." }
      ],
      expected_car_info: {
        make_model: "BMW X5",
        class: 3,
        class_description: "представительские, внедорожники, минивены, микроавтобусы",
        mileage: "120 000 км"
      },
      expected_services: [
        "Комплекс антикоррозийной обработки",
        "Реставрация фар"
      ],
      expected_cost: {
        services: [
          { name: "Комплекс НЕ РАМНЫЕ АВТО с пробегом (3 класс)", price: "40000" },
          { name: "Реставрация фар жидким полиуретаном", price: "от 5000" }
        ],
        total: "от 45000",
        note: "Окончательная стоимость определяется после диагностики"
      }
    }
  end

  # Сценарий 6: Услуга не найдена в прайс-листе
  def self.service_not_found_scenario
    {
      description: "Запрошенная услуга отсутствует в прайс-листе",
      conversation: [
        { role: "user", content: "Toyota Camry, нужна настройка карбюратора" },
        { role: "assistant", content: "К сожалению, настройка карбюратора отсутствует в нашем прайс-листе. Позвоните по телефону для консультации." }
      ],
      expected_car_info: {
        make_model: "Toyota Camry",
        class: 2,
        class_description: "бизнес-класс и кроссоверы",
        mileage: nil
      },
      expected_services: [
        "Настройка карбюратора"
      ],
      expected_cost: nil # Услуга не найдена в прайс-листе
    }
  end

  # Возвращает все сценарии для тестирования
  def self.all_scenarios
    [
      full_info_scenario,
      partial_info_scenario,
      minimal_info_scenario,
      class_clarification_scenario,
      multiple_services_scenario,
      service_not_found_scenario
    ]
  end
end