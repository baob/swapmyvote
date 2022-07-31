class OnsConstituency < ApplicationRecord
  NUMBER_OF_UK_CONSTITUENCIES = 650
  MARGINAL_THRESHOLD = 1000

  has_many :polls,
           foreign_key: "constituency_ons_id",
           primary_key: "ons_id",
           dependent: :destroy

  has_many :recommendations,
           primary_key: "ons_id",
           foreign_key: "constituency_ons_id",
           dependent: :destroy

  def polls_count
    return @polls_count if defined?(@polls_count)
    @polls_count = polls.count || 0
  end

  def parties_by_marginal_score
    polls_by_marginal_score.map(&:party)
  end

  def polls_by_marginal_score
    return @polls_by_marginal_score if defined? @polls_by_marginal_score
    @polls_by_marginal_score = polls.order(:marginal_score).all
  end

  def polls_by_votes
    return @polls_by_votes if defined? @polls_by_votes
    @polls_by_votes = polls.order(votes: :desc).all
  end

  def marginal?
    return @is_marginal if defined?(@is_marginal)
    @is_marginal = polls_by_marginal_score.first.marginal_score <= MARGINAL_THRESHOLD
  end

  def marginal_known?
    return @marginal_known if defined?(@marginal_known)
    @marginal_known = polls_count > 0
  end

  def winner_for_user?(user)
    marginal_known? && !marginal? && polls_by_votes.first.party_id == user.preferred_party_id
  end

  def loser_for_user?(user)
    marginal_known? && !winner_for_user?(user) && !marginal_for_user?(user)
  end

  def marginal_for_user?(user)
    marginal_known? && marginal? && polls_by_votes[0..1].map(&:party_id).include?(user.preferred_party_id)
  end

  def voter_type(user)
    # return "wfl_unknown_" + user.preferred_party.name if !marginal_known?
    return "unknown" unless marginal_known?
    if winner_for_user?(user)
      return "win"
    elsif marginal_for_user?(user)
      return "fight"
    elsif loser_for_user?(user)
      return marginal? ? "loseM" : "loseS"
      # return "lose"
    end
  end

  def voter_may_have_defeat_strategy?(user)
    return false unless marginal_known?

    top_two = polls_by_votes[0..1].map(&:party_id)

    marginal_known? &&
        loser_for_user?(user) &&
        top_two.last == user.willing_party_id &&
        top_two.first != user.preferred_party_id
  end

  def voter_is_primarily_defeater?(user)
    marginal_known? && !winner_for_user?(user) && !marginal_for_user?(user) && voter_may_have_defeat_strategy?(user)
  end
end
