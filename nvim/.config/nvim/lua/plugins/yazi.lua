-- yazi as the file explorer, replacing LazyVim's default neo-tree.
return {
  {
    "mikavilpas/yazi.nvim",
    version = "*",
    -- Load at startup so the netrw hijack is registered before opening a directory.
    lazy = false,
    dependencies = { { "nvim-lua/plenary.nvim", lazy = true } },
    keys = {
      { "<leader>e", "<cmd>Yazi<cr>", mode = { "n", "v" }, desc = "Yazi at current file" },
      { "<leader>E", "<cmd>Yazi cwd<cr>", desc = "Yazi in working directory" },
    },
    ---@type YaziConfig
    opts = {
      open_for_directories = true, -- open yazi instead of netrw on directories
      integrations = {
        grep_in_directory = "fzf-lua", -- match LazyVim's picker (no telescope)
      },
    },
    init = function()
      -- yazi.nvim's hijack only kills FileExplorer autocmds, not the netrw plugin itself.
      -- Set this in `init` (pre-plugin-load) so netrw never loads.
      vim.g.loaded_netrwPlugin = 1
    end,
  },

  -- Disable LazyVim's default explorer; yazi takes over <leader>e / <leader>E.
  { "nvim-neo-tree/neo-tree.nvim", enabled = false },
}
