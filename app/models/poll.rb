class Poll < ApplicationRecord
  belongs_to :constituency,
             class_name: "OnsConstituency",
             foreign_key: "constituency_ons_id",
             primary_key: "ons_id",
             inverse_of: "polls",
             optional: true
  belongs_to :party

  class << self
    # For each combination of party and constituency we figure out how close that party is to tipping the balance
    # in that constituency.
    #
    # Method: Take the party of interest, and find their predicted (by Electoral Calculus) vote share in that
    # constituency.
    # Then take the rest of the parties in that constituency and find the maximum vote share amongst them.
    # Then find the difference and save it as an absolute value.
    #
    # Now we can offer voters an attractive constituency to swap with, by preferring constituencies where their
    # preferred party has a low marginal score ... meaning the party either needs a bit of help getting over
    # the line, or it needs its expected majority bolstering to safe levels. I'm proposing that when we offer
    # potential swaps, 50% of those will be random, and 50% will be from marginals as defined above.
    #
    # Big marginal score implies the preferred party is either way out in front and a safe seat, or way behind
    # without a chance
    #
    def calculate_marginal_score(progress: false)
      # rubocop:disable Rails/FindEach
      OnsConstituency.all.each do |constituency|
      # rubocop:enable Rails/FindEach
        polls = constituency.polls

        polls.each do |poll|
          party_votes = poll.votes
          max_votes = polls.select { |p| p.id != poll.id }.map(&:votes).max
          poll.update(marginal_score: (max_votes - party_votes).abs)
          print "." if progress
        end
      end
      puts if progress
    end
  end

  private def all_polls
    return @all_polls if defined?(@all_polls)
    return @all_polls = [] unless constituency
    @all_polls = constituency.polls
  end

  def effort_to_win
    return @effort_to_win if defined?(@effort_to_win)
    # puts "all_polls is #{all_polls.all.to_a}"
    # raise "all_polls is #{all_polls}"
    best_vote = all_polls.select { |p| p.id != id }.map(&:votes).max

    return @effort_to_win = 0 if !best_vote # if this is the only party, it's clearly the winner

    # this_vote = votes || 0

    return @effort_to_win = (best_vote - safe_votes) / 2.0 if (safe_votes > best_vote) # negative effort if this is the winner

    votes_to_beat = all_polls.select { |p| p.id != id && p.votes > safe_votes }.map(&:votes)
    votes_needed = (votes_to_beat.sum + safe_votes) / Float(votes_to_beat.count + 1)

    # puts "effort #{votes_needed - votes}" if votes_to_beat.count > 1

    @effort_to_win = votes_needed - safe_votes
  end

  def marginal_for_party?
    marginal_score <= OnsConstituency::MARGINAL_THRESHOLD
    # marginal_score <= 1000
  end

  def safe_votes
    return votes if votes
    return 0
    # return 0 if constituency.polls.count > 0 # if there are other polls, safe to assume this party has no votes
    # return nil
  end
  class Cache
    class << self
      @initialized = false

      def initialize
        return if @initialized
        @@polls_cache = {}
        @@constituencies_cache = {}
        polls = Poll.eager_load(:constituency).limit(13_000)
        polls.each do |poll|
          key = { party_id: poll.party_id, constituency_ons_id: poll.constituency_ons_id }
          # puts key
          @@polls_cache[key] = poll
          @@constituencies_cache[poll.constituency_ons_id] = poll.constituency
        end
        @initialized = true
      end

      def get(key)
        initialize
        @@polls_cache[key] ||= Poll.new(party_id: key[:party_id], constituency: get_constituency(key[:constituency_ons_id]))
      end

      def get_constituency(ons_id)
        initialize
        @@constituencies_cache[ons_id] ||= OnsConstituency.find_by(ons_id: ons_id)
      end
    end
  end
end
