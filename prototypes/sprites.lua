data:extend({
  -- Four mip levels (64, 32, 16, 8) side by side in one 120x64 file; the engine picks the
  -- level that fits the size it draws at. mipmap_count is only honored with a gui/icon group
  -- flag, which "gui-icon" implies.
  {
    type = "sprite",
    name = "quidquid-calculator",
    filename = "__quidquid__/graphics/icons/calculator.png",
    size = 64,
    mipmap_count = 4,
    flags = { "gui-icon" },
  },
  -- Icons for the temporary-request editor's stack +/- buttons
  {
    type = "sprite",
    name = "quidquid-temporary-request-editor-stack-minus",
    filename = "__quidquid__/graphics/icons/stack-minus.png",
    size = 64,
  },
  {
    type = "sprite",
    name = "quidquid-temporary-request-editor-stack-plus",
    filename = "__quidquid__/graphics/icons/stack-plus.png",
    size = 64,
  },
})
