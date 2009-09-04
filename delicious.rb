require 'rubygems'
require 'httparty'
require 'digest/md5' 
require 'recommendations.rb'
require '../rublicious/rublicious.rb'

class DeliciousRecommender

  def initialize
    @recommender = Recommendations.new
    @api         = Rublicious::Feeds.new
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
    @api.xml_client.add_response_handler do |response|
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
      categs = post.category
      categs = [categs] unless categs.is_a? Array
      categories += categs
    end

    init_hash_with_keys(categories)
  end

  def initialize_user_hash(user, tag, count = 5)
    creators = [user]
    
    @api.get_popular(tag, count).each do |post|
      Thread.new do
        @api.get_urlposts(post.link).each do |post2|
          creator = post2.dc_creator
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
          Thread.new do
            top_tags = @api.get_urlinfo(post.link).top_tags
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
