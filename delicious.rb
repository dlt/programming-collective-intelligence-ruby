require 'rubygems'
require 'httparty'
require 'digest/md5' 
require 'recommendations.rb'

class DeliciousRecommender

	def initialize
		@recommender = Recommendations.new
    @api = DeliciousAPI.new
    set_handlers
	end

	def user_recommendations(user, tag, similarity = :sim_pearson, count = 10)
		user_hash = initialize_user_hash(user, tag)
		fill_items(user_hash) {|user| @api.get_userposts(user, tag, count) } 
		@recommender.get_recommendations(user_hash, user, similarity)
	end

	def tag_recommendations(tag, similarity = :sim_pearson, count = 10)
    tag_hash = init_tag_hash(tag, count)
    fill_tag_items(tag_hash)
    tag_hash = @recommender.transform_prefs tag_hash
    @recommender.get_recommendations(tag_hash, tag, similarity)
	end

	private
  def set_handlers
    @api.xml_client.response_handler = Proc.new do |response|
      response = response['rss']['channel']['item']
      # if returned 1 or 0 items in the response, makes it look like an array
      response = [response] if response.is_a? Hash 
      response ||= []
      response
    end
  end

	def init_tag_hash(tag, count = 10)
		categories = [tag]

		@api.get_popular(tag, count).each do |post|
			categs = post['category']
			categs = [categs] unless categs.is_a? Array
			categories += categs
		end

		init_hash_with_keys(categories)
	end

	def initialize_user_hash(user, tag, count = 5)
		creators = [user]
		@api.get_popular(tag, count).each do |post|
      Thread.new do
				@api.get_urlposts(post['link']).each do |post2|
					creator = post2['dc:creator']
					creators << creator
				end
      end
		end
    join_all
		init_hash_with_keys(creators)
	end
  
  def fill_tag_items(hash)
    copy = hash.dup
    copy.each_key do |tag|
      Thread.new do 
        popular_posts = @api.get_popular(tag)
        popular_posts.each do |post|
          url = post['link']
          Thread.new do
            top_tags = @api.get_urlinfo(url)['top_tags']
            hash[url] = top_tags
          end
        end
      end
    end
    join_all
    hash
  end

	def fill_items(hash, extract = 'link')
		all_items = []
		hash.each_key do |item|
      Thread.new do
        posts = yield(item)
        posts.each do |post|
          value = post[extract]
          hash[item][value] = 1.0
          all_items << value
        end
      end
		end
    join_all

		hash.each_pair do |key, ratings|
			all_items.each do |item|
				ratings[item] = 0.0 unless ratings.has_key? item 
			end
		end
	end

	def init_hash_with_keys(keys)
    hash = {}
		keys.uniq.each { |k| hash[k] = {} }
		hash
	end

  def join_all
    Thread.list.each {|t| t.join unless t == Thread.current || t == Thread.main }
  end
end


class DeliciousAPI
  attr_reader :xml_client, :json_client

  def initialize
    @xml_client  = XMLClient.new
    @json_client = JSONClient.new
  end

  alias old_method_missing method_missing

  def method_missing(meth, *args)
    return @xml_client.send(meth, *args) if @xml_client.respond_to? meth
    return @json_client.send(meth, *args) if @json_client.respond_to? meth 
    
    old_method_missing meth, *args
  end
end

class Client
  attr_accessor :response_handler

	def get(*params)
		self.class.get(*params)
	end

	def query_string(tag, count)
		query = '' 
		query << '/' + tag if tag
		query << "?count=#{count}"
		query
	end

	def handle_response(response)
    if @response_handler
      response = @response_handler.call(response)
    end
    response
	end
end

class XMLClient < Client
	include HTTParty
	base_uri 'http://feeds.delicious.com/v2/xml'
	format :xml

	def get_tagurls(*tags)
		count = 10
		hash = get("/tag/#{tags.join('+')}?count=#{count}")
		handle_response hash
	end

	def get_popular(tag = nil, count = 5)
		hash = get("/popular#{query_string(tag, count)}")
		handle_response hash
	end

	def get_userposts(user, tag = nil, count = 15)
		hash = get("/#{user}/#{query_string(tag, count)}")
		handle_response hash
	end

	def get_urlposts(url)
		hash = get("/url/#{Digest::MD5.hexdigest(url)}")
		handle_response hash
	end
end

class JSONClient < Client
	include HTTParty
	base_uri 'http://feeds.delicious.com/v2/json'
  format :json

	def get_urlinfo(url)
		get("/urlinfo/#{Digest::MD5.hexdigest(url)}").first #will always return one result
	end
end
