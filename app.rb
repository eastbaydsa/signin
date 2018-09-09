require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/flash'
require 'active_support/all'
require 'nationbuilder'

configure { set :server, :puma }
enable :sessions

use Rack::Auth::Basic, "Restricted Area" do |username, password|
  username == ENV['USERNAME'] and password == ENV['PASSWORD']
end

helpers do
  def nation_builder_client
    unless @nation_builder_client
      p 'building nb client'
      @nation_builder_client = NationBuilder::Client.new(
        ENV['NATION_NAME'],
        ENV['NATION_API_TOKEN']
      )
    end
    @nation_builder_client
  end

  def signed_in_tag
    ENV['SIGN_IN_TAG']
  end

  def signin_total
    unless @total
      @total = 0

      members_result = nation_builder_client.call(
        :people_tags,
        :people,
        {tag: signed_in_tag, limit: 100}
      )
      members_page = NationBuilder::Paginator.new(nation_builder_client, members_result)

      loop do
        @total += members_page.body['results'].count
        if members_page.next?
          members_page = members_page.next
        else
          break
        end
      end

    end

    @total
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
  @search_params = {limit: 100}
  @search_params[:email] = params[:email] if params[:email].present?
  @search_params[:last_name] = params[:last_name] if params[:last_name].present?

  @results = nation_builder_client.call(
    :people,
    :search,
    @search_params
  )['results']

  erb :results
end

get '/quorum' do
  erb :quorum
end

post '/signin' do
  begin
    person = nation_builder_client.call(
      :people,
      :show,
      id: params[:id]
    )['person']

    tags = [signed_in_tag]
    if (!person['tags'].include? 'national_member')
      tags += ['national_member', 'provisional_member']
    end

    resp = nation_builder_client.call(
      :people,
      :tag_person,
      id: params[:id],
      tagging: {
        tag: tags
      }
    )

    flash[:success] = "#{person['full_name']} has signed in. Thanks!"
  rescue StandardError
    flash[:error] = 'There was a problem signing in.'
  end

  redirect '/'
end

get '/register' do
  erb :new_member
end

post '/register' do
  begin
    person = nation_builder_client.call(
      :people,
      :create,
      {
        person: {
          email: params[:email],
          first_name: params[:first_name],
          last_name: params[:last_name],
          phone: params[:phone],
          note: params[:note],
          tags: [signed_in_tag, 'national_member', 'provisional_member']
        }
      }
    )['person']

    flash[:success] = "#{person['full_name']} has signed in. Thanks!"
    redirect '/'
  rescue NationBuilder::ClientError => e
    error_message = 'There was an error registering this member'
    response = JSON.parse(e.message)
    if response['validation_errors']
      error_message += ": #{response['validation_errors'].join(', ').sub('base ', '')}"
    else
      error_message += ': they may already be registerd in NationBuilder'
    end
    flash.now[:error] = error_message

    search_params = {limit: 100}
    search_params[:email] = params[:email] if params[:email].present?
    search_params[:last_name] = params[:last_name] if params[:last_name].present?
    unless (search_params.blank?)
      @possible = nation_builder_client.call(
          :people,
          :search,
          search_params
        )['results']
    end

    erb :new_member
  end
end
