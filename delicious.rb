require 'rubygems'
require 'httparty'
require 'digest/md5' 
require 'recommendations.rb'

class DeliciousRecommender
	include HTTParty
	base_uri 'http://feeds.delicious.com/v2/xml'
	format :xml

	def initialize(user, tag, nlinks = 10, count = 5)
		@user = user
		@user_hash = initialize_user_hash(user, tag, count)
		fill_items(@user_hash, tag)
	end

	def get_popular(options)
		hash = self.class.get('/popular')
		hash['rss']['channel']['item']
	end

	def get_userposts(user, tag = nil)
		hash = get("/#{user}/#{!tag.nil? ? tag : ''}")
		hash['rss']['channel']['item']
	end

	def get_urlposts(url)
		hash = get("/url/#{Digest::MD5.hexdigest(url)}")
		hash['rss']['channel']['item']
	end

	def get(*params)
		self.class.get(*params)
	end

	def initialize_user_hash(user, tag, count = 5)
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
		all_items = {}

		user_hash.keys.each do |user|
			posts = get_userposts(user, tag)

			posts ||= [] #returned no results
			if posts.is_a? Hash #returned only one result, makes it look like a set
				posts = [posts]
			end
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

	def get_recomentadions(similarity = :sim_distance)
		recommender = Recommendations.new
		recommender.get_recommendations(@user_hash, @user, similarity)
	end
end

