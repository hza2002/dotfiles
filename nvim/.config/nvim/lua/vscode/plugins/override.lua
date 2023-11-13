-- Disabling core plugins
lvim.builtin.project.active = false
lvim.builtin.nvimtree.active = false

-- Telescope
lvim.builtin.telescope.extensions.media_files = {
  filetypes = { "ico", "png", "webp", "jpg", "jpeg", "mp4", "webm", "pdf" },
  find_cmd = "rg",
}

lvim.builtin.telescope.on_config_done = function(telescope)
  pcall(telescope.load_extension, "notify")
  pcall(telescope.load_extension, "noice")
  pcall(telescope.load_extension, "undo")
  pcall(telescope.load_extension, "media_files")
  pcall(telescope.load_extension, "software-licenses")
end
lvim.builtin.telescope.defaults.layout_strategy = "horizontal"
lvim.builtin.telescope.defaults.layout_config = {
  horizontal = {
    prompt_position = "top",
    preview_width = 0.55,
    results_width = 0.8,
  },
  vertical = {
    mirror = false,
  },
  width = 0.87,
  height = 0.80,
  preview_cutoff = 120,
}

-- Treesitter
lvim.builtin.treesitter.matchup.enable = true
