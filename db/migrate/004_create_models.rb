# frozen_string_literal: true

class CreateModels < ActiveRecord::Migration[7.0]
  def change
    create_table :models do |t|
      t.string :model_id, null: false, index: { unique: true }
      t.string :provider, null: false
      t.string :name
      t.text :description
      t.integer :context_window
      t.decimal :input_cost, precision: 10, scale: 8
      t.decimal :output_cost, precision: 10, scale: 8
      t.boolean :supports_functions, default: false
      t.boolean :supports_vision, default: false
      t.boolean :supports_streaming, default: true
      t.json :capabilities
      t.timestamps
    end

    add_index :models, :provider
    add_index :models, [:provider, :model_id]
    add_index :models, :supports_functions
    add_index :models, :supports_vision
  end
end