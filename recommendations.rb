class Recommendations 
  require 'enumerator'
	require 'utils'
  include Utils

	def self.critics
		Utils::Critics
	end

  def sim_distance(prefs, person1, person2)
    p1_prefs = prefs[person1]
    p2_prefs = prefs[person2]

    common_prefs = common_preferences(prefs, person1, person2)
    return 0 if common_prefs.size.zero? 

    coordinates = []
    common_prefs.each do |pref|
      coordinates.push(p1_prefs[pref])
      coordinates.push(p2_prefs[pref])
    end

    euclidean_distance(*coordinates)
  end

  def euclidean_distance(*coordinates)
    Raise 'Wrong number of coordinates' if coordinates.size % 2 != 0
    squares = []
    coordinates.each_slice(2) {|c1, c2| squares.push((c1 - c2) ** 2) }
    1 / (1 + Math.sqrt(squares.sum))
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
				if !prefs[person].keys.include? pref || prefs[person][pref].zero?
					totals[pref] += prefs[other][pref] * sim
					sim_sums[pref] += sim
				end
			end
		end

		rankings = totals.keys.collect do |pref|
			[totals[pref] / sim_sums[pref], pref]
		end

		rankings.sort_by { |r| r[0] }.reverse
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
	
	private
  def common_preferences(prefs, person1, person2)
    prefs[person1].keys & prefs[person2].keys
  end

	def different_preferences(prefs, other, person)
		p1_prefs = prefs[person].keys
		diff = p1_prefs.select {|pref| prefs[person][pref].zero? || prefs[other][pref] }
		diff
	end

end

