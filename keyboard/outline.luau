--!nonstrict
-- Keyboard move outline: a plain frame the size of the on-screen keyboard, at the place it
-- would take. The layer lets the pointer through, so the move grid under it reads the
-- pointer. The on-screen keyboard places, shows and hides it.

layer.render(ui.box({
  flexGrow = 1,
  fill = "primary/0.18",
  border = "primary",
  borderWidth = 2,
  radius = 12,
}))
