require 'sinatra'
require 'sinatra/reloader' if development?
require 'active_support/all'
require 'nationbuilder'

configure { set :server, :puma }

nation_builder_client = NationBuilder::Client.new(ENV['NATION_NAME'], ENV['NATION_API_TOKEN'])

# some options here:
# - pull all membership at app start and do fuzzy-matches in-memory
#     - check tags/signed in status on "select"
# - search by exact email
# - search by last name only?

get '/' do
  erb :index
end

post '/lookup' do
  @search_params = {}
  @search_params[:email] = params[:email] if params[:email].present?
  @search_params[:last_name] = params[:last_name] if params[:last_name].present?

  @results = nation_builder_client.call(:people, :search, @search_params)['results']
  erb :results
end
