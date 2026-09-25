data:extend({
  {
    type = "custom-input",
    name = "quidquid-open-palette",
    key_sequence = "COMMAND + K",
  },
  {
    type = "custom-input",
    name = "quidquid-craft-1",
    key_sequence = "mouse-button-1",
  },
  {
    type = "custom-input",
    name = "quidquid-add-to-research-queue",
    key_sequence = "mouse-button-1",
  },
  {
    type = "custom-input",
    name = "quidquid-open-remote-view",
    key_sequence = "mouse-button-1",
  },
  {
    type = "custom-input",
    name = "quidquid-craft-5",
    key_sequence = "mouse-button-2",
  },
  {
    type = "custom-input",
    name = "quidquid-craft-all",
    key_sequence = "SHIFT + mouse-button-1",
  },
  {
    type = "custom-input",
    name = "quidquid-open-factoriopedia",
    key_sequence = "ALT + mouse-button-1",
  },
  {
    type = "custom-input",
    name = "quidquid-temporary-request",
    key_sequence = "COMMAND + mouse-button-1",
  },
  {
    -- Same sequence as quidquid-temporary-request. Two custom-inputs may share one
    -- sequence: both fire, and Registry:resolve_actions keys by (candidate type,
    -- input_name), so only the action registered for the candidate under the cursor
    -- runs. The two never apply to the same candidate type -- resources have no
    -- logistics request, items have no patch to pin.
    type = "custom-input",
    name = "quidquid-pin-resource",
    key_sequence = "COMMAND + mouse-button-1",
  },
  {
    -- Not a SHIFT combo: SHIFT is Factorio's own reserved "place as ghost" modifier
    -- while holding a real item, and a SHIFT-bound key here showed that mode's ghost
    -- icon for as long as SHIFT stayed held after triggering this action, even
    -- though a real item was correctly in the cursor (confirmed in-game).
    type = "custom-input",
    name = "quidquid-pipette",
    key_sequence = "ALT + mouse-button-2",
  },
  {
    type = "custom-input",
    name = "quidquid-temporary-request-editor-confirm",
    key_sequence = "E",
  },
  {
    type = "custom-input",
    name = "quidquid-palette-up",
    key_sequence = "K",
    consuming = "game-only",
  },
  {
    type = "custom-input",
    name = "quidquid-palette-down",
    key_sequence = "J",
    consuming = "game-only",
  },
})
