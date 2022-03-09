require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"

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

# Create a new document
get "/new" do
  erb :new
end

def filename_error(file)
  return "name error" if file.size < 1
  return "type error" unless file.include?(".txt") || file.include?(".md")
end

post "/new" do
  filename = params[:name].strip
  error = filename_error(filename)

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
  file = params[:file_name]
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
  erb :edit
end

post "/:file_name" do
  @file = params[:file_name]
  file_path = File.join(data_path, @file)

  File.write(file_path, params[:content])

  session[:message] = "'#{@file}' has been successfully updated!"
  redirect "/"
end

# Delete file
post "/:file_name/delete" do
  @file = params[:file_name]
  file_path = File.join(data_path, @file)

  File.delete(file_path)

  session[:message] = "'#{@file}' has been successfully deleted!"
  redirect "/"
end

