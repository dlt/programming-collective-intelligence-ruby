require 'rubygems'
require 'httparty'
require 'digest/md5' 
require 'recommendations.rb'

class DeliciousRecommender
	include HTTParty
	base_uri 'http://feeds.delicious.com/v2/xml'
	format :xml

	def initialize
		@recommender = Recommendations.new
	end

	def get_tagurls(*tags)
		count = 10
		hash = self.class.get("/tag/#{tags.join('+')}?count=#{count}")
		handle_response hash
	end

	def get_urlinfo(url)
		json_format("/urlinfo/#{Digest::MD5.hexdigest(url)}").first #will always return one result
	end

	def get_popular(tag = nil, count = 5)
		hash = self.class.get("/popular#{query_string(tag, count)}")
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

	def get_recommendations(tag, user = nil, search_for = :user, similarity = :sim_distance)
		if search_for == :user
      Raise 'Have to provide user param.' unless user
			user_recommendations(user, tag, similarity)
		elsif search_for == :tag
      tag_recommendations(tag, similarity)
		end
	end
	
	private
	def user_recommendations(user, tag, similarity)
		user_hash = initialize_user_hash(user, tag)
		fill_items(user_hash) {|user| get_userposts(user, tag, 10) } 
		@recommender.get_recommendations(user_hash, user, similarity)
	end

	def tag_recommendations(tag, similarity, count = 10)
		tag_hash = init_tag_hash(tag, count)
    fill_tag_items(tag_hash)
    @recommender.get_recommendations(tag_hash, tag, :sim_distance)
	end

	def init_tag_hash(tag, count = 10)
		categories = [tag]
		get_popular(tag, count).each do |post|
			categs = post['category']
			categs = [categs] unless categs.is_a? Array
			categories += categs
		end
		init_hash_with_keys(categories)
	end

	def initialize_user_hash(user, tag, count = 5)
		creators = [user]
		get_popular(tag, count).each do |post|
      Thread.new do
				get_urlposts(post['link']).each do |post2|
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
      popular_posts = get_popular(tag)
      popular_posts.each do |post|
        url = post['link']
        top_tags = get_urlinfo(url)['top_tags']
        hash[url] = top_tags
      end
    end
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

	def get(*params)
		self.class.get(*params)
	end

	def query_string(tag, count)
		query = '' 
		query << '/' + tag if tag
		query << "?count=#{count}"
		query
	end

	def init_hash_with_keys(keys)
    hash = {}
		keys.uniq.each { |k| hash[k] = {} }
		hash
	end

	def json_format(url)
		self.class.format :json
		self.class.base_uri 'http://feeds.delicious.com/v2/'
		
		prefix = '/json'
		prefix += '/' if url.each_char.first != '/'

		response = self.class.get(prefix + url)
		self.class.format :xml
		self.class.base_uri 'http://feeds.delicious.com/v2/xml'
		return response
	end
	
	def handle_response(response_hash)
		response = response_hash['rss']['channel']['item']
		
		# if returned 1 or 0 items in the response, makes it look like an array
		response = [response] if response.is_a? Hash 
		response ||= []
		response
	end
  
  def join_all
    Thread.list.each {|t| t.join unless t == Thread.current || t == Thread.main }
  end
end

