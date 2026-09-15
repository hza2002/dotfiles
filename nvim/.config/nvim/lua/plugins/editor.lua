-- Editor plugins not covered by LazyVim defaults.
return {
  -- Auto-switch macOS input method back to ABC on leaving insert mode.
  -- macism-nvim (~/.local/bin, from the bin package) wraps macism with its
  -- delay arg so CJKV input methods are not bounced back to ABC on restore.
  {
    "keaising/im-select.nvim",
    enabled = vim.fn.has("macunix") == 1,
    vscode = true,
    event = "InsertEnter",
    opts = {
      default_im_select = "com.apple.keylayout.ABC",
      default_command = "macism-nvim",
    },
  },

  -- Highlight and navigate matching words/delimiters
  {
    "andymass/vim-matchup",
    event = "BufReadPost",
    init = function()
      vim.g.matchup_matchparen_offscreen = { method = "popup" }
    end,
  },

  -- Align text around a delimiter
  {
    "junegunn/vim-easy-align",
    keys = {
      { "ga", "<Plug>(EasyAlign)", mode = { "n", "x" }, desc = "Easy Align" },
    },
  },

  -- Write/read files with sudo
  {
    "lambdalisue/suda.vim",
    cmd = { "SudaWrite", "SudaRead" },
  },
}
