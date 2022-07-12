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
    @polls_by_marginal_score = polls.order(:marginal_score)
  end

  def marginal?
    polls_by_marginal_score.first.marginal_score <= 1000
  end

  def winner_for_user?(user)
    !marginal? && parties_by_marginal_score.first == user.preferred_party
  end

  def marginal_for_user?(user)
    marginal? && parties_by_marginal_score[0..1].include?(user.preferred_party)
  end

  def voter_type(user)
    if marginal_for_user?(user)
      return "fighting"
    elsif winner_for_user?
      return "winning"
    end
    return "losing"
  end

  def constituency_type
    marginal ? "marginal" : "safe"
  end

  def combined_type(u)
    voter_type(u) + "-" + constituency_type
  end
end
