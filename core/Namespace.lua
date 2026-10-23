local addonName, NS = ...
-- core/Namespace.lua — the chat tag, the folder name, the brand and the version fallback.

-- The mandatory cyan bracketed tag (slash-commands-§4). Every tagged line leaves through NS.Print.
NS.PREFIX = "|cff00ffff[DR]|r"

NS.name = addonName

-- The brand in PLAIN TEXT (launcher-§1): the launcher label, the disabled refusal line, the debug
-- console title and the diagnostics markers all take this one spelling. Never the TOC Title.
NS.BRAND = "Ka0s DPS Race"

-- The primary slash and its long alias, both registered on the one dispatcher (settings/Slash.lua).
NS.SLASH = "/dr"
NS.SLASH_LONG = "/dpsrace"

-- What NS.version reads when the TOC cannot be asked (a library-absent load, the headless harness
-- without metadata). core/EnvSetup.lua replaces NS.version with the TOC's own value at load.
NS.FALLBACK_VERSION = "0.1.0"
NS.version = NS.FALLBACK_VERSION
