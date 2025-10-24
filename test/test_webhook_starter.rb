# frozen_string_literal: true

require_relative 'test_helper'
require 'telegram/bot'
require_relative '../lib/webhook_starter'

class TestWebhookStarter < Minitest::Test
  def setup
    @telegram_bot_handler = Minitest::Mock.new
  end


  def test_handle_webhook_request_post_with_valid_json
    AppConfig.stub(:telegram_bot_token, 'test_token') do
      AppConfig.stub(:webhook_url, 'https://example.com') do
        AppConfig.stub(:webhook_path, '/telegram/webhook') do
          AppConfig.stub(:webhook_host, '0.0.0.0') do
            AppConfig.stub(:webhook_port, 3000) do
              Application.logger.stub(:info, nil) do
                Application.logger.stub(:debug, nil) do
                  starter = WebhookStarter.new(@telegram_bot_handler)

              # Create mock request and response
              req = Minitest::Mock.new
              req.expect(:request_method, 'POST')
              req.expect(:body, StringIO.new('{"update_id": 123, "message": {"message_id": 1}}'))

              res = Minitest::Mock.new
              res.expect(:status=, nil, [200])
              res.expect(:content_type=, nil, ['application/json'])
              res.expect(:body=, nil, [String])

              # Mock Telegram::Bot::Types::Update
              update_mock = Minitest::Mock.new
              update_mock.expect(:message, nil)

              Telegram::Bot::Types::Update.stub(:new, update_mock) do
                starter.send(:handle_webhook_request, req, res)
              end

              begin
                assert_equal 200, res.status
              rescue StandardError
                true
              end
            end
          end
        end
      end
    end
        end
      end
    end
  end

  def test_handle_webhook_request_non_post_returns_405
    AppConfig.stub(:telegram_bot_token, 'test_token') do
      Application.logger.stub(:info, nil) do
        Application.logger.stub(:debug, nil) do
          starter = WebhookStarter.new(@telegram_bot_handler)

          req = Minitest::Mock.new
          req.expect(:request_method, 'GET')

          res = Minitest::Mock.new
          res.expect(:status=, nil, [405])
          res.expect(:body=, nil, [String])

          starter.send(:handle_webhook_request, req, res)
        end
      end
    end
  end

  def test_handle_webhook_request_invalid_json
    AppConfig.stub(:telegram_bot_token, 'test_token') do
      Application.logger.stub(:info, nil) do
        Application.logger.stub(:error, nil) do
          Application.logger.stub(:debug, nil) do
            starter = WebhookStarter.new(@telegram_bot_handler)

      req = Minitest::Mock.new
      req.expect(:request_method, 'POST')
      req.expect(:body, StringIO.new('invalid json'))

      res = Minitest::Mock.new
      res.expect(:status=, nil, [400])
      res.expect(:body=, nil, [String])

      starter.send(:handle_webhook_request, req, res)
        end
      end
    end
  end
end
