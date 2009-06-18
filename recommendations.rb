module Utils
  Critics = {
    'Lisa Rose' => {
      'Lady in the Water' => 2.5,
      'Snakes on a Plane' => 3.5,
      'Just My Luck' => 3.0,
      'Superman Returns' => 3.5,
      'You, Me and Dupree' => 2.5,
      'The Night Listener'=> 3.0
    },
    'Gene Seymour' => {
      'Lady in the Water' => 3.0,
      'Snakes on a Plane' => 3.5,
      'Just My Luck' => 1.5,
      'Superman Returns' => 5.0,
      'The Night Listener' => 3.0,
     'You, Me and Dupree' => 3.5
    },
    'Michael Phillips' => {
      'Lady in the Water' => 2.5,
      'Snakes on a Plane' => 3.0,
      'Superman Returns' => 3.5,
      'The Night Listener' => 4.0
    },
    'Claudia Puig' => {
      'Snakes on a Plane' => 3.5,
      'Just My Luck' => 3.0,
      'The Night Listener' => 4.5,
      'Superman Returns' => 4.0,
     'You, Me and Dupree' => 2.5
    },
    'Mick LaSalle' => {
      'Lady in the Water' => 3.0,
      'Snakes on a Plane' => 4.0,
      'Just My Luck' => 2.0,
      'Superman Returns' => 3.0,
      'The Night Listener' => 3.0,
     'You, Me and Dupree' => 2.0
    },
    'Jack Matthews' => {
      'Lady in the Water' => 3.0,
      'Snakes on a Plane' => 4.0,
      'The Night Listener' => 3.0,
      'Superman Returns' => 5.0,
      'You, Me and Dupree' => 3.5
    },
    'Toby' => {
      'Snakes on a Plane' => 4.5,
      'You, Me and Dupree' => 1.0,
      'Superman Returns' => 4.0
    }
  }
end

class Array
  def sum
    self.inject(0) do |sum, val|
      sum += val
    end
  end

  def product
    self.inject(1) do |prod, val|
      prod * val
    end
  end
end

module SimilarityAlgorithms 
  require 'enumerator'
  include Utils

  def euclidean_distance(*coordinates)
    Raise 'Wrong number of coordinates' if coordinates.size % 2 != 0
    squares = []
    coordinates.each_slice(2) {|c1, c2| squares.push((c1 - c2) ** 2) }
    1 / (1 + Math.sqrt(squares.sum))
  end

  def sim_distance(person1, person2)
    p1_prefs = Critics[person1]
    p2_prefs = Critics[person2]

    common_prefs = common_preferences(person1, person2)
    return 0 if common_prefs.size.zero? 

    coordinates = []
    common_prefs.each do |pref|
      coordinates.push(p1_prefs[pref])
      coordinates.push(p2_prefs[pref])
    end

    euclidean_distance(*coordinates)
  end

  def sim_pearson(person1, person2)
    common_prefs = common_preferences(person1, person2)
    n = common_prefs.size
    return 0 if n.zero? 

    # Selecting ratings for uncommon preferences
    p1_prefs = Critics[person1].dup.delete_if {|k, v| !common_prefs.include? k }
    p2_prefs = Critics[person2].dup.delete_if {|k, v| !common_prefs.include? k }
    
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
    
    return 0 if den.zero? || num < 0
    num / den
  end

  def common_preferences(person1, person2)
    Critics[person1].keys & Critics[person2].keys
  end

	def different_preferences(other, person)
		p1_prefs = Critics[person].keys
		diff = p1_prefs.select {|pref| Critics[person][pref].zero? || Critics[other][pref] }
		diff
	end

  def top_matches(person, n = 5, similarity = :sim_pearson)
		#prevents from calling non-existend methods
		similarity = :sim_pearson unless self.respond_to? similarity
    others = Critics.keys - [person]
    scores = others.collect do |other|
      [self.send(similarity, person, other), other]
    end
    scores = scores.sort_by { |s| s[0] } 
    scores.reverse.first n
  end

	def get_recommendations(person, similarity = :sim_pearson)
		#prevents from calling non-existend methods
		similarity = :sim_pearson unless self.respond_to? similarity
		totals = Hash.new 0
		sim_sums = Hash.new 0

		others = Critics.keys - [person]
		others.each do |other|	
			sim = self.send(similarity, person, other)
			next if sim <= 0

			Critics[other].keys.each do |pref|
				if !Critics[person].keys.include? pref || Critics[person][pref].zero?
					totals[pref] += Critics[other][pref] * sim
					sim_sums[pref] += sim
				end
			end
		end

		rankings = totals.keys.collect do |pref|
			[totals[pref] / sim_sums[pref], pref]
		end

		rankings.sort_by { |r| r[0] }.reverse
	end

end
include SimilarityAlgorithms

