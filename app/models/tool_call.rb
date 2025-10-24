# frozen_string_literal: true

class ToolCall < ApplicationRecord
  belongs_to :message

  validates :name, presence: true
  validates :arguments, presence: true

  def arguments_hash
    arguments.is_a?(Hash) ? arguments : JSON.parse(arguments || '{}')
  rescue JSON::ParserError
    {}
  end
end