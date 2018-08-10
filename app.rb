require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/flash'
require 'active_support/all'
require 'nationbuilder'

configure { set :server, :puma }
enable :sessions

nation_builder_client = NationBuilder::Client.new(
  ENV['NATION_NAME'],
  ENV['NATION_API_TOKEN']
)

helpers do
  def signed_in_tag
    'signed_in_meeting_beta'
  end
end

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

  @results = nation_builder_client.call(
    :people,
    :search,
    @search_params
  )['results']

  erb :results
end

post '/signin' do
  begin
    person = nation_builder_client.call(
      :people,
      :show,
      id: params[:id]
    )['person']

    nation_builder_client.call(
      :people,
      :tag_person,
      id: params[:id],
      tagging: {
        tag: signed_in_tag
      }
    )

    flash[:success] = "#{person['full_name']} has signed in. Thanks!"
  rescue StandardError
    flash[:error] = 'There was a problem signing in.'
  end

  redirect '/'
end

get '/new-member' do
  erb :new_member
end
