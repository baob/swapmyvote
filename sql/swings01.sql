select users.id, name, email, swaps.id AS swaps_id
from users, swaps
left join parties as partyup on users.willing_party_id = partyup.id
left join parties as partydown on users.preferred_party_id = partydown.id
left join ons_constituencies on users.constituency_ons_id = ons_constituencies.ons_id
where ((users.swap_id = swaps.id) or (users.id = swaps.chosen_user_id))
and swaps.confirmed = true
and email is not null and email != ''




select count(users.id, name, email, swaps.id)
from users, swaps
left join parties as partyup on users.willing_party_id = partyup.id
left join parties as partydown on users.preferred_party_id = partydown.id
left join ons_constituencies on users.constituency_ons_id = ons_constituencies.ons_id
where ((users.swap_id = swaps.id) or (users.id = swaps.chosen_user_id))
and swaps.confirmed = true
and email is not null and email != ''



select users.id, swaps.id, willing_party_id, preferred_party_id
from users, swaps
where ((users.swap_id = swaps.id) or (users.id = swaps.chosen_user_id))
and swaps.confirmed = true


select swing_raw.ons_id, parties.id as party_id,
  sum(CASE WHEN parties.id = willing_party_id THEN 1 else 0 end) as partyup,
  sum(CASE WHEN parties.id = preferred_party_id THEN 1 else 0 end) as partydown
from (
  select users.id as user_id, swaps.id as swap_id, willing_party_id, preferred_party_id, constituency_ons_id as ons_id
  from users, swaps
  where ((users.swap_id = swaps.id) or (users.id = swaps.chosen_user_id))
  and swaps.confirmed = true
) as swing_raw
left join parties  on swing_raw.willing_party_id = parties.id or swing_raw.preferred_party_id = parties.id
left join ons_constituencies on swing_raw.ons_id = ons_constituencies.ons_id
group by swing_raw.ons_id, party_id
