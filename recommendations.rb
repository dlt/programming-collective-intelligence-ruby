class Recommendations 
  require 'enumerator'
	require 'utils'
  include Utils

	def self.critics
		Utils::Critics
	end

  def sim_distance(prefs, person1, person2)
    return 0 if common_preferences(prefs, person1, person2).size.zero?
    coordinates = paired_preferences_scores(prefs, person1, person2)
    euclidean_distance(*coordinates)
  end

  def sim_pearson(prefs, person1, person2)
    common_prefs = common_preferences(prefs, person1, person2)
    n = common_prefs.size
    return 0 if n.zero? 

    # Selecting ratings for uncommon preferences
    p1_prefs = prefs[person1].dup.delete_if {|k, v| !common_prefs.include? k }
    p2_prefs = prefs[person2].dup.delete_if {|k, v| !common_prefs.include? k }
    
    # Add up all the preferences
    p1_ratings = p1_prefs.values
    p2_ratings = p2_prefs.values
    sum1, sum2 = p1_ratings.sum, p2_ratings.sum

    # Sum up the squares
    sum_sqr1 = p1_ratings.collect {|rating| rating ** 2 }.sum
    sum_sqr2 = p2_ratings.collect {|rating| rating ** 2 }.sum
  
    # Sum up the products
    products = []
    p1_ratings.each_index {|i| products << p1_ratings[i] * p2_ratings[i] } 
    p_sum = products.sum

    # Calculate Pearson score
    num = p_sum - (sum1 * sum2 / n)
    den = Math.sqrt((sum_sqr1 - (sum1 ** 2) / n) * (sum_sqr2 - (sum2 ** 2) / n))
    
    return 0 if den.zero? 
    num / den
  end
	
	def get_recommendations(prefs, person, similarity = :sim_pearson)
		#prevents from calling non-existend methods
		similarity = :sim_pearson unless self.respond_to? similarity
		totals = Hash.new 0
		sim_sums = Hash.new 0

		others = prefs.keys - [person]
		others.each do |other|	
			sim = self.send(similarity, prefs, person, other)
			next if sim <= 0

			prefs[other].keys.each do |pref|
				if !prefs[person].keys.include?(pref) || prefs[person][pref].zero?
					totals[pref]   += prefs[other][pref] * sim
					sim_sums[pref] += sim
				end
			end
		end

		rankings = totals.keys.collect do |pref|
			[totals[pref] / sim_sums[pref], pref]
		end
		rankings.sort_by {|r| r[0] }.reverse
	end

  def top_matches(prefs, person, n = 5, similarity = :sim_pearson)
		#prevents from calling non-existend methods
		similarity = :sim_pearson unless self.respond_to? similarity
    others = prefs.keys - [person]
    scores = others.collect do |other|
      [self.send(similarity, prefs, person, other), other]
    end
    scores = scores.sort_by { |s| s[0] } 
    scores.reverse.first n
  end

	def calculate_similar_items(prefs, n = 10)
		result = {}
		item_prefs = transform_prefs(prefs)
		id = 0
		item_prefs.each_key do |item|
			# Status updates for large datasets
			id += 1
			puts "%d\t/%d" % [id, item.size] if id % 100 == 0

			scores = top_matches(item_prefs, item, n, :sim_distance)
			result[item] = scores
		end
		result
	end

	def get_recommended_items(prefs, item_match, user)
		user_ratings = prefs[user]
		scores = Hash.new 0
		total_sim = Hash.new 0

		user_ratings.each do |item, rating|
			item_match[item].each do |item2, similarity|
				next if user_ratings.include?(item2)

				# Weighted sum of rating times similarity
				scores[item2] += similarity * rating

				# Sum of all the similarities
				total_sim[item2] += similarity
			end
		end

		rankings = Hash.new 0
		scores.each do |item, score|
			rankings[item] = score / total_sim[item]
		end
		rankings
	end

	def transform_prefs(prefs)
		result = Hash.new
		prefs.keys.each do |person|
			prefs[person].keys.each do |item|
				result[item] ||= {}
				result[item][person] = prefs[person][item]
			end
		end
		result
	end

	def load_movie_lens(path = '../movielens/ml-data/')
		movies = {} 
		File.open(path + 'u.item').each_line do |line|
			id, item = line.split('|')[0, 2]
			movies[id.to_i] = item
		end

		prefs = {} 
		File.open(path + 'u.data').each_line do |line|
			userid, movieid, rating = line.split(/\t/)[0, 3]
			userid, movieid, rating = userid.to_i, movieid.to_i, rating.to_f

			prefs[userid.to_i] ||= {}
			movie_name = uniq_symbol(movies[movieid])
			prefs[userid][movie_name] = rating
		end

		return prefs
	end

	private
	def euclidean_distance(*coordinates)
    Raise 'Wrong number of coordinates' if coordinates.size % 2 != 0
    squares = []
    coordinates.each_slice(2) {|c1, c2| squares.push((c1 - c2) ** 2) }
    1 / (1 + Math.sqrt(squares.sum))
  end

	# jaccard distance function implementation as explained in the Introduction to Data Mining lecture notes from Tan, Steinbach, Kumar 
	# http://www-users.cs.umn.edu/~kumar/dmbook/dmslides/chap2_data.pdf 
	def jaccard_distance(prefs, person1, person2)
		d1, d2 = [], []

		all_prefs = all_preferences(prefs, person1, person2)
		all_prefs.each do |item|
			if prefs[person1].has_key? item
				d1 << prefs[person1][item]
			else
				d1 << 0
			end
			
			if prefs[person2].has_key? item
				d2 << prefs[person2][item]
			else
				d2 << 0
			end
		end

		d3 = []
		d1.each_index do |idx|
			d3 << d1[idx] * d2[idx]
		end

		d1_squares_sum = d1.collect {|val| val ** 2}.sum
		d2_squares_sum = d2.collect {|val| val ** 2}.sum
		
		d1xd2  = d3.sum
		return d1xd2 / (Math.sqrt(d1_squares_sum) * Math.sqrt(d2_squares_sum))
	end
	
	def tanimoto(a, b)
		c = (a & b)
		c.size / (a.size + b.size - c.size)
	end

	def uniq_symbol(name)
		name.downcase.gsub(/[,\s']/,'_').gsub(/[().:!?]/,'').to_sym
	end

  def common_preferences(prefs, person1, person2)
    prefs[person1].keys & prefs[person2].keys
  end

	def all_preferences(prefs, person1, person2)
		(prefs[person1].keys | prefs[person2].keys).uniq
	end

	def different_preferences(prefs, other, person)
		p1_prefs = prefs[person].keys
		diff = p1_prefs.select {|pref| prefs[person][pref].zero? || prefs[other][pref] }
		diff
	end

	# Return an array containing preference scores to preferences common to both users, paired two-by-two.
	#
	# Example:
	#	Given that p1 represents the set of preferences of Tom and p2 the set of preferences of Bill
	#
	# p1 = {'Superman Returns' => 3.5, 'Matrix' => 5.0, 'Titanic' => 0.1}
	# p2 = {'Matrix' => 3.5, 'Plan 9 From Outer Space' => 5.0, 'Titanic' => 0.1}
	# paired_preferences_scores(prefs, 'Tom', 'Bill') => [3.5, 5.0, 0.1, 0.1]
	#
	def paired_preferences_scores(prefs, person1, person2)
    paired = []
    common_preferences(prefs, person1, person2).each do |pref|
      paired.push(prefs[person1][pref])
      paired.push(prefs[person2][pref])
    end
		paired
	end
end

