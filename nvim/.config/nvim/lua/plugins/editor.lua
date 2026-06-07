-- Editor plugins not covered by LazyVim defaults.
return {
  -- Auto-switch macOS input method back to ABC on leaving insert mode
  {
    "keaising/im-select.nvim",
    event = "InsertEnter",
    opts = {
      default_im_select = "com.apple.keylayout.ABC",
      default_command = "macism",
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
