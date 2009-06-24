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
		count = 20
		hash = self.class.get("/tag/#{tags.join('+')}?count=#{count}")
		handle_response hash
	end

	def get_urlinfo(url)
		json_format("/urlinfo/#{Digest::MD5.hexdigest(url)}").first #will always return one result
	end

	def get_popular(tag = nil)
		hash = self.class.get("/popular/#{tag ? tag : ''}")
		handle_response hash
	end

	def get_userposts(user, tag = nil)
		hash = get("/#{user}/#{tag ? tag : ''}")
		handle_response hash
	end

	def get_urlposts(url)
		hash = get("/url/#{Digest::MD5.hexdigest(url)}")
		handle_response hash
	end

	def get(*params)
		self.class.get(*params)
	end

	def initialize_user_hash(user, tag, count = 5)
		puts 'init user hash'
		user_hash = {}
		get_popular(tag).first(count).each do |post|
				get_urlposts(post['link']).each do |post2|
					creator = post2['dc:creator']
					user_hash[creator] = {}
				end
		end
		user_hash[user] = {}
		user_hash
	end
	
	def fill_items(user_hash, tag)
		puts 'fill items'
		all_items = {}

		user_hash.keys.each do |user|
			posts = get_userposts(user, tag)

			posts.each do |post|
				url = post['link']
				user_hash[user][url] = 1.0
				all_items[url] = 1
			end
		end

		user_hash.each_pair do |user, ratings|
			all_items.each do |item|
				ratings[item] = 0.0 unless user_hash[user].keys.include? item 
			end
		end
	end

	def get_recommendations(user, tag, search_for = :user, similarity = :sim_distance)
		recommender = Recommendations.new
		if search_for == :user
			return user_recommendations(user, tag, similarity)
		elsif search_for == :tag
		end
	end

	private
	def user_recommendations(user, tag, similarity)
		user_hash = initialize_user_hash(user, tag)
		fill_items(user_hash, tag)
		@recommender.get_recommendations(user_hash, user, similarity)
	end


	def tag_recommendations(tag, count = 10)
		tag_hash = initialize_tag_hash(tag, count)

	end
	
	def json_format(url)
		self.class.format :json
		self.class.base_uri 'http://feeds.delicious.com/v2/'
		
		prefix = '/json'
		prefix += '/' if url.each_char.first != '/'

		response = self.class.get('/json' + url)
		self.class.format :xml
		self.class.base_uri 'http://feeds.delicious.com/v2/xml'
		return response
	end
	
	def handle_response(response_hash)
		response = response_hash['rss']['channel']['item']
		response = [response] if response.is_a? Hash 
		response ||= []
		response
	end
end

