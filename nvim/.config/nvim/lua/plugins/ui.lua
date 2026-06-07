-- UI plugins not covered by LazyVim defaults.
return {
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        preset = {
          header = [[
     ___  _____
 .'/,-Y"     "~-.
 l.Y             ^.
 /\               _\_
i            ___/"   "\
|          /"   "\   o !
l         ]     o !__./
 \ _  _    \.___./    "~\
  X \/ \            ___./
 ( \ ___.   _..--~~"   ~`-.
  ` Z,--   /               \
    \__.  (   /       ______)
      \   l  /-----~~" /
       Y   \          /
       |    "x______.^
       |           \
       |            \
]],
        },
      },
    },
  },

  -- Peek line contents while typing `:<number>`
  {
    "nacro90/numb.nvim",
    event = "CmdlineEnter",
    opts = {
      show_numbers = true,
      show_cursorline = true,
      hide_relativenumbers = true,
      number_only = false,
      centered_peeking = true,
    },
  },

  -- tmux pane navigation and resize from Neovim.
  {
    "aserowy/tmux.nvim",
    opts = {
      navigation = { enable_default_keybindings = false },
      resize = { enable_default_keybindings = false },
    },
    -- stylua: ignore start
    keys = {
      { "<C-h>", function() require("tmux").move_left() end, mode = { "n", "i", "t" }, desc = "Go to left window/pane" },
      { "<C-j>", function() require("tmux").move_bottom() end, mode = { "n", "i", "t" }, desc = "Go to lower window/pane" },
      { "<C-k>", function() require("tmux").move_top() end, mode = { "n", "i", "t" }, desc = "Go to upper window/pane" },
      { "<C-l>", function() require("tmux").move_right() end, mode = { "n", "i", "t" }, desc = "Go to right window/pane" },
      { "<C-Left>", function() require("tmux").resize_left() end, desc = "Resize window left" },
      { "<C-Down>", function() require("tmux").resize_bottom() end, desc = "Resize window down" },
      { "<C-Up>", function() require("tmux").resize_top() end, desc = "Resize window up" },
      { "<C-Right>", function() require("tmux").resize_right() end, desc = "Resize window right" },
    },
    -- stylua: ignore end
  },

  -- Auto-resize the focused split so the active window grows a bit.
  {
    "nvim-focus/focus.nvim",
    event = "VeryLazy",
    opts = {
      autoresize = {
        enable = true,
        minwidth = 10,
        minheight = 10,
        height_quickfix = 10,
      },
      ui = { hybridnumber = true },
    },
    config = function(_, opts)
      local ignore_buftypes = { "nofile", "prompt", "popup", "terminal" }
      local ignore_filetypes = {
        "neo-tree",
        "snacks_terminal",
        "toggleterm",
        "Trouble",
        "trouble",
        "lazy",
        "mason",
        "help",
        "noice",
        "qf",
      }
      local augroup = vim.api.nvim_create_augroup("FocusDisable", { clear = true })
      vim.api.nvim_create_autocmd("WinEnter", {
        group = augroup,
        callback = function()
          vim.w.focus_disable = vim.tbl_contains(ignore_buftypes, vim.bo.buftype)
        end,
        desc = "Disable focus autoresize for buftype",
      })
      vim.api.nvim_create_autocmd("FileType", {
        group = augroup,
        callback = function()
          vim.b.focus_disable = vim.tbl_contains(ignore_filetypes, vim.bo.filetype)
        end,
        desc = "Disable focus autoresize for filetype",
      })
      require("focus").setup(opts)
    end,
  },
}
