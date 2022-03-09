ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms.rb"

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { username: "admin" } }
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"

    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
  end

  def test_data
    create_document "changes.txt", "sample changes text"

    get "/changes.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "changes text"
  end

  def test_nonexistent
    get "/something.txt"
    assert_equal 302, last_response.status
    assert_equal "'something.txt' does not exist.", session[:message]
  end

  def test_markdown
    create_document "about.md", "# Ruby is..."
    get "/about.md"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end

  def test_edit
    create_document "changes.txt", "no content"
    get "/changes.txt/edit", {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_updating
    create_document "changes.txt"

    post "/changes.txt", { content: "new content" }, admin_session

    assert_equal 302, last_response.status
    assert_equal "'changes.txt' has been successfully updated!", session[:message]

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def test_new
    get "/new", {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
  end

  def test_create_new
    post "/new", { name: "test" }, admin_session
    assert_includes last_response.body, "File must be a '.txt' or '.md' file."

    post "/new", name: ""
    assert_includes last_response.body, "A name is required"
    
    post "/new", name: "test.txt"
    assert_equal 302, last_response.status
    assert_equal "'test.txt' was created successfully!", session[:message]
  end

  def test_delete
    create_document "test.txt"

    post "/test.txt/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "'test.txt' has been successfully deleted!", session[:message]
  end

  def test_signin_valid
    post "/users/signin", username: "admin", password: "secret"

    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    assert_equal "admin", session[:username]
  end

  def test_signin_invalid
    post "/users/signin", username: "admin", password: "password"

    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid Credentials"
    assert_nil session[:username]
  end

  def test_signout
    post "/users/signout"

    assert_equal 302, last_response.status
    assert_equal "You have been signed out.", session[:message]
    assert_nil session[:username]
  end


  def teardown
    FileUtils.rm_rf(data_path)
  end
end