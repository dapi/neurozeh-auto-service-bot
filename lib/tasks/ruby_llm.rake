# frozen_string_literal: true

namespace :ruby_llm do
  desc "Load models from ruby_llm models.json into database"
  task load_models: :environment do
    puts "Loading RubyLLM models into database..."

    # Find models.json in ruby_llm gem
    gem_spec = Gem::Specification.find_by_name('ruby_llm')
    models_file = File.join(gem_spec.gem_dir, 'lib', 'ruby_llm', 'models.json')

    unless File.exist?(models_file)
      puts "Error: models.json not found in ruby_llm gem at #{models_file}"
      exit 1
    end

    puts "Reading models from: #{models_file}"
    models_data = JSON.parse(File.read(models_file))

    loaded_count = 0
    updated_count = 0

    models_data.each do |model_data|
      model_id = model_data['id']
      provider = model_data['provider']

      # Find or create model
      model = Model.find_or_initialize_by(model_id: model_id)

      # Extract capabilities
      capabilities = model_data['capabilities'] || []
      supports_functions = capabilities.include?('function_calling') || capabilities.include?('tool_calling')
      supports_vision = model_data.dig('modalities', 'input')&.include?('image') || false
      supports_streaming = model_data.dig('capabilities')&.include?('streaming') != false

      # Extract pricing
      pricing = model_data['pricing'] || {}
      input_cost = pricing.dig('text_tokens', 'standard', 'input_per_million')
      output_cost = pricing.dig('text_tokens', 'standard', 'output_per_million')

      # Update model attributes
      model.assign_attributes(
        provider: provider,
        name: model_data['name'],
        description: model_data.dig('metadata', 'description'),
        context_window: model_data['context_window'],
        input_cost: input_cost ? input_cost / 1_000_000.0 : nil, # Convert to per-token cost
        output_cost: output_cost ? output_cost / 1_000_000.0 : nil,
        supports_functions: supports_functions,
        supports_vision: supports_vision,
        supports_streaming: supports_streaming,
        capabilities: capabilities
      )

      if model.new_record?
        model.save!
        loaded_count += 1
        puts "✓ Loaded: #{model_id} (#{provider})"
      elsif model.changed?
        model.save!
        updated_count += 1
        puts "✓ Updated: #{model_id} (#{provider})"
      end
    end

    puts "\nCompleted!"
    puts "New models loaded: #{loaded_count}"
    puts "Models updated: #{updated_count}"
    puts "Total models in database: #{Model.count}"

    # Show deepseek models specifically
    deepseek_models = Model.where(provider: 'deepseek')
    puts "\nDeepSeek models found: #{deepseek_models.count}"
    deepseek_models.each do |model|
      puts "  - #{model.model_id}: #{model.name} (context: #{model.context_window})"
    end
  end

  desc "Show models database statistics"
  task stats: :environment do
    puts "RubyLLM Models Database Statistics"
    puts "================================="
    puts "Total models: #{Model.count}"
    puts "Providers: #{Model.distinct.pluck(:provider).sort.join(', ')}"

    Model.group(:provider).count.each do |provider, count|
      puts "#{provider}: #{count} models"
    end

    puts "\nFunction calling support: #{Model.where(supports_functions: true).count}"
    puts "Vision support: #{Model.where(supports_vision: true).count}"
    puts "Streaming support: #{Model.where(supports_streaming: true).count}"
  end
end