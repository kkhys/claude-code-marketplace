# Attribution for everything posted to GitHub from this marketplace, so
# reviewers can tell an agent's comment from the user's own.
#
# jq module: load with `jq -L <lib dir> 'include "attribution"; ...'`.

def marker: "[from Claude Code]";

# Prefix a body with the marker unless it already starts with it. Null and
# empty bodies become the bare marker so a review summary is never posted
# blank.
def attribute:
  if . == null or . == "" then marker
  elif startswith(marker) then .
  else "\(marker) \(.)" end;
