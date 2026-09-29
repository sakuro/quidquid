local Declarations = require("lib.declarations")

-- `order` fixes registration order, which breaks score ties between sources (see
-- lib/palette_logic.lua). The letters keep item results ahead of fluids, fluids
-- ahead of recipes, and so on.
local function source(name, order, data)
  data.contract_version = Declarations.CONTRACT_VERSION
  return { type = "mod-data", name = name, order = order, data_type = Declarations.SOURCE_DATA_TYPE, data = data }
end

data:extend({
  source("quidquid-items", "a", {
    type = "item",
    label = { "quidquid.source-items" },
    prefixes = { "i", "item" },
    in_default_search = true,
    interface = "quidquid.item-source",
  }),
  source("quidquid-fluids", "b", {
    type = "fluid",
    label = { "quidquid.source-fluids" },
    prefixes = { "f", "fluid" },
    in_default_search = true,
    interface = "quidquid.fluid-source",
  }),
  source("quidquid-recipes", "c", {
    type = "recipe",
    label = { "quidquid.source-recipes" },
    prefixes = { "r", "recipe" },
    in_default_search = true,
    interface = "quidquid.recipe-source",
  }),
  source("quidquid-technologies", "d", {
    type = "technology",
    label = { "quidquid.source-technologies" },
    prefixes = { "t", "technology" },
    in_default_search = true,
    interface = "quidquid.technology-source",
  }),
  source("quidquid-surfaces", "e", {
    type = "surface",
    label = { "quidquid.source-surfaces" },
    prefixes = { "s", "surface" },
    in_default_search = true,
    interface = "quidquid.surface-source",
  }),
  -- Out of the default search: every query would otherwise be handed to the
  -- expression evaluator.
  source("quidquid-calculator", "f", {
    type = "calculation",
    label = { "quidquid.source-calculator" },
    prefixes = { "=" },
    in_default_search = false,
    interface = "quidquid.calculator-source",
  }),
})
