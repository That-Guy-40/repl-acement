# jqrepl - try different filters above the #DATA marker
#
# Uncomment any example below to try it out, or write your own.
#
# .[] | .name
# [.[] | select(.age >= 18)] | length
# .[] | {name, adult: (.age >= 18)}
# map(select(.city == "Chicago"))
# sort_by(.age) | reverse
# group_by(.city) | map({city: .[0].city, count: length})

.[] | .name

#DATA
[
  {"name": "Alice", "age": 30, "city": "New York"},
  {"name": "Bob",   "age": 17, "city": "Boston"},
  {"name": "Carol", "age": 25, "city": "Chicago"},
  {"name": "Dave",  "age": 42, "city": "Chicago"}
]
