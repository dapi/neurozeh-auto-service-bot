# frozen_string_literal: true

class Model < ApplicationRecord
  acts_as_model

  # Ассоциации автоматически добавлены acts_as_model:
  # - has_many :chats (через model_id в таблице chats)

  # Валидации
  validates :model_id, presence: true, uniqueness: true
  validates :provider, presence: true

  # Scopes
  scope :by_provider, ->(provider) { where(provider: provider) }
  scope :supports_functions, -> { where(supports_functions: true) }
  scope :supports_vision, -> { where(supports_vision: true) }
  scope :supports_streaming, -> { where(supports_streaming: true) }
  scope :by_context_window, ->(min = nil) { min ? where('context_window >= ?', min) : all }

  # Методы для удобной работы
  def display_name
    name || model_id
  end

  def supports_function_calling?
    supports_functions?
  end

  def supports_image_input?
    supports_vision?
  end

  def max_tokens
    context_window
  end

  def cost_per_input_token
    input_cost
  end

  def cost_per_output_token
    output_cost
  end

  # Методы для совместимости с ruby_llm
  def family
    # Извлекаем семейство из model_id или используем значение по умолчанию
    case model_id
    when /claude-/
      'claude'
    when /gpt-/
      'gpt'
    when /gemini-/
      'gemini'
    when /deepseek/
      'deepseek'
    else
      model_id.split('-').first
    end
  end

  def model_created_at
    created_at
  end

  def max_output_tokens
    # Для большинства моделей используем 1/4 от context_window
    context_window ? context_window / 4 : nil
  end

  def knowledge_cutoff
    nil # У нас нет этой информации
  end

  def modalities
    {
      'input' => supports_vision ? ['text', 'image'] : ['text'],
      'output' => ['text']
    }
  end

  def capabilities
    caps = []
    caps << 'function_calling' if supports_functions
    caps << 'vision' if supports_vision
    caps << 'streaming' if supports_streaming
    caps
  end

  def pricing
    {
      'text_tokens' => {
        'standard' => {
          'input_per_million' => input_cost ? (input_cost * 1_000_000).to_i : nil,
          'output_per_million' => output_cost ? (output_cost * 1_000_000).to_i : nil
        }
      }
    }
  end

  def metadata
    {}
  end

  # Class methods
  def self.find_by_model_id(id)
    find_by(model_id: id)
  end

  def self.by_provider_with_capabilities(provider)
    by_provider(provider).includes(:chats)
  end

  # Для совместимости с ruby_llm
  def to_s
    model_id
  end

  def inspect
    "#<Model id: #{id}, model_id: #{model_id}, provider: #{provider}, name: #{name}>"
  end
end