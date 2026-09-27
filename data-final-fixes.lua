-- In data-final-fixes so declarations other mods add or edit in their data.lua and
-- data-updates.lua are all in place before they are checked.
require("lib.declarations").validate(data.raw)
