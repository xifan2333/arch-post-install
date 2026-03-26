return {
  "3rd/image.nvim",
  lazy = false,
  opts = {
    backend = "kitty",
    hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif" },
    max_width = 100,
    max_height = 50,
    editor_only_render_when_focused = true,
    window_overlap_clear_enabled = true,
  },
}
