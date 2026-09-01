return {
  {
    "ellisonleao/gruvbox.nvim",
    lazy = true,
    opts = {
      transparent_mode = true,
    },
  },
  -- Tell LazyVim to use gruvbox as the active colorscheme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "gruvbox",
    },
  },
}
