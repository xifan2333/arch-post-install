return {
  "3rd/image.nvim",
  event = "BufReadPre",
  opts = {
    backend = "kitty",
    max_width = 100,
    max_height = 50,
    editor_only_render_when_focused = true,
    window_overlap_clear_enabled = true,
  },
}
