local Declarations = require("lib.declarations")

-- No `order`: no two of these share a candidate type and input_name, so their
-- registration order decides nothing.
local function action(name, data)
  data.contract_version = Declarations.CONTRACT_VERSION
  return { type = "mod-data", name = name, data_type = Declarations.ACTION_DATA_TYPE, data = data }
end

data:extend({
  action("quidquid-open-remote-view", {
    types = { "surface", "resource" },
    label = { "quidquid.action-open-remote-view" },
    input_name = "quidquid-open-remote-view",
    interface = "quidquid.open-remote-view-action",
  }),
  action("quidquid-open-factoriopedia", {
    types = { "item", "fluid", "recipe", "surface", "resource" },
    label = { "quidquid.action-open-factoriopedia" },
    input_name = "quidquid-open-factoriopedia",
    interface = "quidquid.open-factoriopedia-action",
  }),
  -- On the Factoriopedia input for technology candidates: the technology screen is
  -- the more useful destination for a technology than its Factoriopedia page.
  action("quidquid-open-technology", {
    types = { "technology" },
    label = { "quidquid.action-open-technology" },
    input_name = "quidquid-open-factoriopedia",
    interface = "quidquid.open-technology-action",
  }),
  action("quidquid-add-to-research-queue", {
    types = { "technology" },
    label = { "quidquid.action-add-to-research-queue" },
    input_name = "quidquid-add-to-research-queue",
    interface = "quidquid.research-queue-action",
  }),
  action("quidquid-craft-1", {
    types = { "item", "recipe" },
    label = { "quidquid.action-craft-1" },
    input_name = "quidquid-craft-1",
    interface = "quidquid.craft-1-action",
  }),
  action("quidquid-craft-5", {
    types = { "item", "recipe" },
    label = { "quidquid.action-craft-5" },
    input_name = "quidquid-craft-5",
    interface = "quidquid.craft-5-action",
  }),
  action("quidquid-craft-all", {
    types = { "item", "recipe" },
    label = { "quidquid.action-craft-all" },
    input_name = "quidquid-craft-all",
    interface = "quidquid.craft-all-action",
  }),
  action("quidquid-pipette", {
    types = { "item", "recipe" },
    label = { "controls.pipette" },
    input_name = "quidquid-pipette",
    interface = "quidquid.pipette-action",
  }),
  action("quidquid-pin-resource", {
    types = { "resource" },
    label = { "quidquid.action-pin-resource" },
    input_name = "quidquid-pin-resource",
    interface = "quidquid.pin-resource-action",
  }),
  action("quidquid-temporary-request", {
    types = { "item", "recipe" },
    label = { "quidquid.action-temporary-request" },
    input_name = "quidquid-temporary-request",
    interface = "quidquid.temporary-request-action",
  }),
  action("quidquid-hold-blueprint", {
    types = { "blueprint" },
    label = { "quidquid.action-hold-blueprint" },
    input_name = "quidquid-hold-blueprint",
    interface = "quidquid.hold-blueprint-action",
  }),
  action("quidquid-copy-blueprint", {
    types = { "blueprint" },
    label = { "quidquid.action-copy-blueprint" },
    input_name = "quidquid-copy-blueprint",
    interface = "quidquid.copy-blueprint-action",
  }),
  action("quidquid-export-blueprint", {
    types = { "blueprint" },
    label = { "quidquid.action-export-blueprint" },
    input_name = "quidquid-export-blueprint",
    interface = "quidquid.export-blueprint-action",
  }),
})
