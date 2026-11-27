extends RefCounted
## H5 (Stage 2): the Market's words. Every word the Market's window and its two helpers (market_trade_tab.gd,
## market_companions.gd) show comes from balance.json "windows" through Data.word. A word that is not there yet falls
## back to H5_WORDS below, so the window never shows a bare key; once the word is added to balance.json "windows" (same
## key), that one is used and the fallback is never read again.
## Used by: ui/windows/market_window.gd, market_trade_tab.gd, market_companions.gd, the tests.
## Uses: Data (word). No class_name: preload it.

# H5 words: player words the Market needs that balance.json "windows" does not have yet (same keys to add there).
const H5_WORDS := {
	"market_sub": "Bramble's trades, and %s",            # the Market's header line (Q5: no level in it any more)
	"timber_name": "Timber",                             # timber's name in its trade popup
	"timber_desc": "For building and growing",           # what timber is for (the H4 tile's words)
	"ride_skills": "%d skills in use",                   # the Ride row: how many skills sit in the mount's circles
	"market_empty": "Nothing to trade right now",        # a trade tab with no offer at all (malformed data only)
}


## The word for key: balance.json "windows" first, else the H5_WORDS fallback above, else the key itself.
static func say(key: String) -> String:
	var w: String = Data.word(key)
	if w != key:
		return w
	return String(H5_WORDS.get(key, key))


## "honey" -> "Honey": a thing's name as a title (the Bag's names are written for the middle of a line).
static func title_case(s: String) -> String:
	return s if s == "" else s.substr(0, 1).to_upper() + s.substr(1)
