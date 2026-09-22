-- Shared with anything that builds rich text (e.g. a source's row/tooltip
-- annotation, see #121) so its inline [color=...] tags can't drift from what the
-- palette itself applies via style.font_color.
return {
  DEFAULT = { r = 255, g = 255, b = 255 },
  ACCENT = { r = 255, g = 142, b = 42 },
  MUTED = { r = 160, g = 160, b = 160 },
}
