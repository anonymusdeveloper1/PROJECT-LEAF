extends RefCounted
## H5 (Stage 2; Stage 3: every word is in balance.json "windows" now): the Market's words. Every word the Market's window and
## its two helpers (market_trade_tab.gd, market_companions.gd) show comes from balance.json "windows" through Data.word.
## Used by: ui/windows/market_window.gd, market_trade_tab.gd, market_companions.gd, the tests.
## Uses: Data (word). No class_name: preload it.

## The word for key from balance.json "windows" (the key itself when it is not there).
static func say(key: String) -> String:
	return Data.word(key)


## "honey" -> "Honey": a thing's name as a title (the Bag's names are written for the middle of a line).
static func title_case(s: String) -> String:
	return s if s == "" else s.substr(0, 1).to_upper() + s.substr(1)
