-- prototypes/sprites.lua
-- Icons for the temporary-request editor's stack +/- buttons: the base game's
-- stack-size signal icon with a plus/minus glyph baked into the bottom-right corner.
--
-- Pre-composited into a single flat PNG (via a throwaway script, not checked in) rather
-- than expressed as a two-layer `sprite` prototype (`layers = {base, glyph}`): the
-- layered approach rendered the glyph layer centered instead of at its authored
-- position, for reasons that weren't worth chasing further -- a single flat image sidesteps
-- Factorio's layer-compositing behavior entirely and is guaranteed pixel-exact.
--
-- The glyph itself is this mod's own art, not the base game's signal-plus/signal-minus:
-- those are baked onto the same opaque colored-badge background every virtual-signal
-- icon uses, which would have hidden the stack-size icon underneath. Ours is a white
-- glyph with a thick opaque black outline (for contrast against the badge) on an
-- otherwise transparent canvas.
data:extend({
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
