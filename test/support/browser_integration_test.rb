#
# BrowserIntegrationTest
#
# Use this class for capybara based integration tests for the ui.
#
require 'capybara/rails'

class BrowserIntegrationTest < ActionDispatch::IntegrationTest
  # let's use dom_id inorder to identify sections
  include ActionView::RecordIdentifier

  CONFIG_RU = (Rails.root + 'config.ru').to_s
  OUTER_APP = Rack::Builder.parse_file(CONFIG_RU).first

  require 'capybara/poltergeist'

  Capybara.register_driver :rack_test do |app|
    Capybara::RackTest::Driver.new(app)
  end

  Capybara.register_driver :poltergeist do |app|
    Capybara::Poltergeist::Driver.new(app)
  end

  # this is integration testing. So let's make the whole
  # rack stack available...
  Capybara.app = OUTER_APP
  Capybara.run_server = true
  Capybara.app_host = 'http://lvh.me:3003'
  Capybara.server_port = 3003
  Capybara.javascript_driver = :poltergeist
  Capybara.default_max_wait_time = 5

  # Make the Capybara DSL available
  include Capybara::DSL

  setup do
    Capybara.current_driver = Capybara.javascript_driver
    page.driver.add_headers 'ACCEPT-LANGUAGE' => 'en-EN'
    @testcode = InviteCode.new
    @testcode.save!
  end

  teardown do
    Capybara.reset_sessions!    # Forget the (simulated) browser state
    Capybara.use_default_driver # Revert Capybara.current_driver to Capybara.default_driver
  end

  def submit_signup(username = nil, password = nil)

    with_config invite_required: true do

      username ||= "test_#{SecureRandom.urlsafe_base64}".downcase
      password ||= SecureRandom.base64
      visit '/users/new'
      fill_in 'Username', with: username
      fill_in 'Password', with: password
      fill_in 'Invite code', with: @testcode.invite_code
      fill_in 'Password confirmation', with: password
      click_on 'Sign Up'
      return username, password
    end

    with_config invite_required: false do

      username ||= "test_#{SecureRandom.urlsafe_base64}".downcase
      password ||= SecureRandom.base64
      visit '/users/new'
      fill_in 'Username', with: username
      fill_in 'Password', with: password
      fill_in 'Password confirmation', with: password
      click_on 'Sign Up'
      return username, password
    end

  end

  # currently this only works for tests with poltergeist.
  # ApiIntegrationTest has a working implementation for RackTest
  def login(user = nil)
    InviteCodeValidator.any_instance.stubs(:validate)
    @user ||= user ||= FactoryGirl.create(:user)
    token = Token.create user_id: user.id
    page.driver.add_header "Authorization", %Q(Token token="#{token}")
    visit '/'
  end

  teardown do
    if @user && @user.reload
      @user.destroy_identities
      @user.destroy
    end
  end

  teardown do
    unless self.passed?
      self.save_state
    end
  end

  def save_state
    File.open(logfile_path, 'w') do |test_log|
      test_log.puts self.class.name
      test_log.puts "========================="
      test_log.puts name
      test_log.puts Time.now
      test_log.puts current_path
      test_log.puts page.status_code
      test_log.puts page.response_headers
      test_log.puts "page.html"
      test_log.puts "------------------------"
      test_log.puts page.html
      test_log.puts "server log"
      test_log.puts "------------------------"
      test_log.puts `tail log/test.log -n 200`
    end
    page.save_screenshot screenshot_path
  # some drivers do not support screenshots
  rescue Capybara::NotSupportedByDriverError
  end

end
