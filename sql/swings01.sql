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


select user_id, swap_id, willing_party_id, preferred_party_id, swing_raw.ons_id, parties.id as party_id
from (
  select users.id as user_id, swaps.id as swap_id, willing_party_id, preferred_party_id, constituency_ons_id as ons_id
  from users, swaps
  where ((users.swap_id = swaps.id) or (users.id = swaps.chosen_user_id))
  and swaps.confirmed = true
  limit 10
) as swing_raw
left join parties  on swing_raw.willing_party_id = parties.id or swing_raw.preferred_party_id = parties.id
left join ons_constituencies on swing_raw.ons_id = ons_constituencies.ons_id
