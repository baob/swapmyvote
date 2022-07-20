class OnsConstituency < ApplicationRecord
  NUMBER_OF_UK_CONSTITUENCIES = 650
  has_many :polls,
           foreign_key: "constituency_ons_id",
           primary_key: "ons_id",
           dependent: :destroy

  has_many :recommendations,
           primary_key: "ons_id",
           foreign_key: "constituency_ons_id",
           dependent: :destroy

  def parties_by_marginal_score
    polls_by_marginal_score.map(&:party)
  end

  def polls_by_marginal_score
    return @polls_by_marginal_score if defined? @polls_by_marginal_score
    @polls_by_marginal_score = polls.order(:marginal_score).all
  end

  MARGINAL_THRESHOLD = 2500

  def marginal?
    return @is_marginal if defined?(@is_marginal)
    @is_marginal = polls_by_marginal_score.first.marginal_score <= MARGINAL_THRESHOLD
  end

  def marginal_known?
    return @marginal_known if defined?(@marginal_known)
    @marginal_known = polls_by_marginal_score.count > 0
  end

  def marginal_degree
    return ""
    # msf = polls_by_marginal_score.first.marginal_score
    # return "" if msf > 3000
    # return "-C" if msf > 2000
    # return "-B" if msf > 1000
    # return "-A"
  end


  def winner_for_user?(user)
    marginal_known? && !marginal? && polls_by_marginal_score.first.party_id == user.preferred_party_id
  end

  def loser_for_user?(user)
    marginal_known? && !winner_for_user?(user) && !marginal_for_user?(user)
  end

  def marginal_for_user?(user)
    marginal_known? && marginal? && polls_by_marginal_score[0..1].map(&:party_id).include?(user.preferred_party_id)
  end

  def user_is_primarily_defeater?(user)
    marginal_known? && !winner_for_user?(user) && !marginal_for_user?(user) && voter_may_have_defeat_strategy?(user.willing_party_id)
  end

  def voter_may_have_defeat_strategy?(party_id)
    marginal_known? &&
      (
        (marginal? && polls_by_marginal_score[0..1].map(&:party_id).include?(party_id)) ||
        (!marginal? && polls_by_marginal_score[1].party_id == party_id)
      )
  end

  def voter_type(user)
    # return "wfl_unknown_" + user.preferred_party.name if !marginal_known?
    return "unknown" if !marginal_known?
    if winner_for_user?(user)
      return "winning"
    elsif marginal_for_user?(user)
      return "fighting"
    elsif loser_for_user?(user)
      return marginal? ? "losing-m" : "losing-s"
    end
  end

  def dump_before_raise(user)
    puts "\n\n"
    puts user.attributes
    puts "marginal?", marginal? if  marginal_known?
    puts "marginal_known?", marginal_known?
    puts "winner_for_user?(user)", winner_for_user?(user)
    puts "loser_for_user?(user)", loser_for_user?(user)
    puts "marginal_for_user?(user)", marginal_for_user?(user)
    puts "user_is_primarily_defeater?(user)", user_is_primarily_defeater?(user)
    # puts user.party
    puts self.attributes
    puts polls.map(&:attributes)
  end

  def user_party_vote_share(user)
    # raise "User does not have a preferred party" if user.preferred_party.nil?
    # raise "constituency does not have poll predictions" unless marginal_known?
    return 0 if user.preferred_party_id.nil?
    return 0 unless marginal_known?
    # poll = polls.where(party_id: user.preferred_party_id).first
    poll = Poll::Cache.get(party_id: user.preferred_party_id, constituency_ons_id: ons_id)
    poll.nil? ? 0 : poll.votes
  end

  def constituency_type
    return "ms_unknown" if !marginal_known?
    (marginal? ? "marginal" : "safe") + marginal_degree
  end

  def combined_type(u)
    voter_type(u) + "-" + constituency_type
  end
end
