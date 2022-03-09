require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"

root = File.expand_path("..", __FILE__)

configure do
  enable :sessions
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml",__FILE__)
  end
  YAML.load_file(credentials_path)
end

helpers do
  def render_markdown(text)
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    markdown.render(text)
  end
end

get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map { |file| File.basename(file) }
  erb :index
end

def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    erb render_markdown(content)
  end
end

# Sign In Page
get "/users/signin" do
  erb :signin
end

def signed_in?
  session[:username]
end

def redirect_to_signin
  session[:message] = "You must be signed in to do that."
  redirect "/"
end

def valid_user?(user, password)
  credentials = load_user_credentials
  
  if credentials.include?(user)
    BCrypt::Password.new(credentials[user]) == password
  else
    false
  end
end

post "/users/signin" do
  user = params[:username]
  password = params[:password]

  if valid_user?(user, password)
    session[:message] = "Welcome!"
    session[:username] = user
    redirect "/"
  else
    session[:message] = "Invalid Credentials"
    status 422
    erb :signin
  end
end

post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end

# Create a new document
get "/new" do

  unless signed_in?
    redirect_to_signin
  end

  erb :new
end

def filename_error(file)
  return "name error" if file.size < 1
  return "type error" unless file.include?(".txt") || file.include?(".md")
end

post "/new" do
  filename = params[:name].strip
  error = filename_error(filename)

  unless signed_in?
    redirect_to_signin
  end

  if error
    case error
    when "name error"
      session[:message] = "A name is required"
    when "type error"
      session[:message] = "File must be a '.txt' or '.md' file."
    end
    erb :new
  else
    File.open(data_path + "/" + params[:name], "w") {}
    session[:message] = "'#{params[:name]}' was created successfully!"
    redirect "/"
  end
end

# View file in browser
get "/:file_name" do
  file = File.basename(params[:file_name])
  file_path = File.join(data_path, file)
  error = !File.file?(root + "/data/" + file)

  if error
    session[:message] = "'#{file}' does not exist."
    redirect "/"
  else
    load_file_content(file_path)
  end
end

# Edit file in browser
get "/:file_name/edit" do
  @file = params[:file_name]
  file_path = File.join(data_path, @file)
  @content = File.read(file_path)

  unless signed_in?
    redirect_to_signin
  end

  erb :edit
end

post "/:file_name" do
  @file = params[:file_name]
  file_path = File.join(data_path, @file)

  unless signed_in?
    redirect_to_signin
  end

  File.write(file_path, params[:content])

  session[:message] = "'#{@file}' has been successfully updated!"
  redirect "/"
end

# Delete file
post "/:file_name/delete" do
  @file = params[:file_name]
  file_path = File.join(data_path, @file)

  unless signed_in?
    redirect_to_signin
  end

  File.delete(file_path)

  session[:message] = "'#{@file}' has been successfully deleted!"
  redirect "/"
end



