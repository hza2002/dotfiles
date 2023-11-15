reload("user.plugins.override")

local ui              = reload("user.plugins.ui")
local editor          = reload("user.plugins.editor")
local tool            = reload("user.plugins.tool")
local code            = reload("user.plugins.code")

--#######################################
--## Ui
--#######################################
local ui_plugins      = {

  {
    "catppuccin/nvim",
    lazy = false,
    priority = 1000,
    name = "catppuccin",
    opts = ui.catppuccin,
  },                                                                                                              -- Color Scheme
  { "wfxr/minimap.vim",              build = "cargo install --locked code-minimap", cmd = { "MinimapToggle" }, }, -- Blazing fast minimap/scrollbar written in Rust
  { "simrat39/symbols-outline.nvim", cmd = { "SymbolsOutline" },                    opts = ui.symbols_outline, }, -- A tree like view for symbols in Neovim using LSP
  { "nacro90/numb.nvim",             event = { "BufRead" },                         opts = ui.numb, },            -- numb.nvim 可以以非侵入性的方式查看缓冲区的行
  { "aserowy/tmux.nvim",             event = { "VeryLazy" },                        opts = ui.tmux, },            -- Vim 和 Tmux 导航
  { "nvim-focus/focus.nvim",         event = { "VeryLazy" },                        config = ui.focus, },         -- Auto-Focusing and Auto-Resizing Splits/Windows
  { "sindrets/winshift.nvim",        cmd = { "WinShift" }, },                                                     -- Rearrange your windows with ease
  { "kevinhwang91/rnvimr",           cmd = { "RnvimrToggle" },                      config = ui.rnvimr, },        -- ranger file explorer window
  { "s1n7ax/nvim-window-picker",     lazy = true, },                                                              -- jump to any window using a selector like the one nvim-tree uses
  {
    "norcalli/nvim-colorizer.lua",
    opts = ui.colorizer,
    ft = { "css", "scss", "html", "javascript", },
  }, -- color highlighter 代码着色
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    opts = ui.noice,
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify",
    }
  }, -- Highly experimental plugin that completely replaces the UI for messages, cmdline and the popupmenu.
}

--#######################################
--## Editor
--#######################################
local editor_plugins  = {
  { "tpope/vim-surround", },                                                                          -- mappings to delete, change and add surroundings
  { "tpope/vim-repeat", },                                                                            -- 使用'.'启用重复支持的插件映射
  { "lambdalisue/suda.vim",    cmd = { "SudaRead", "SudaWrite" }, },                                  -- Read or Write files with sudo command.
  -- { "rainbowhxch/accelerated-jk.nvim", event = { "VeryLazy" }, },                                     -- 滚动增强
  { "windwp/nvim-spectre",     lazy = true,                       opts = editor.spectre, },           -- Search and replace
  { "ibhagwan/smartyank.nvim", event = { "BufReadPost" },         opts = editor.smartyank, },         -- Smark powerful yank
  {
    "windwp/nvim-ts-autotag",
    ft = { 'html', 'javascript', 'typescript', 'javascriptreact', 'typescriptreact', 'svelte', 'vue', 'tsx', 'jsx',
      'rescript', 'xml', 'php', 'markdown', 'astro', 'glimmer', 'handlebars', 'hbs' },
  }, -- autoclose and autorename html tag
  {
    "andymass/vim-matchup",
    event = { "VeryLazy" },
    config = function() vim.g.matchup_matchparen_offscreen = { method = "popup" } end,
  },
  {
    "junegunn/vim-easy-align",
    cmd  = { "EasyAlign" },
    keys = { { "ga", "<Plug>(EasyAlign)", mode = { "n", "x" }, desc = "Align with delimiter" } }
  },
  {
    "ggandor/leap.nvim",
    event = { "VeryLazy" },
    config = function() require("leap").add_default_mappings() end,
  }, -- Neovim's answer to the mouse
}

--#######################################
--## Tool
--#######################################
local tool_plugins    = {
  { "jghauser/mkdir.nvim",                       event = "BufWrite", },                              -- creates missing folders on save.
  { "axieax/urlview.nvim",                       cmd = { "UrlView" },        opts = tool.urlview, }, -- Find Url
  { "nvim-telescope/telescope-media-files.nvim", lazy = true, },                                     -- Preview media files using Ueberzug.
  { "chip/telescope-software-licenses.nvim",     lazy = true, },                                     -- Find licenses
  { "debugloop/telescope-undo.nvim",             cmd = { "Telescope undo" }, },                      -- A telescope extension to view and search your undo tree
  {
    "iamcco/markdown-preview.nvim",
    ft = "markdown",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    build = function() vim.fn["mkdp#util#install"]() end,
    config = function()
      vim.g.mkdp_echo_preview_url = 1
      -- vim.g.mkdp_open_to_the_world = 1
      vim.gmkdp_open_ip = '127.0.0.1'
      vim.g.mkdp_port = 7086
    end,
  }, -- Markdown 预览
  {
    "coffebar/neovim-project",
    opts = tool.neovim_project,
    init = function()                          -- enable saving the state of plugins in the session
      vim.opt.sessionoptions:append("globals") -- save global variables that start with an uppercase letter and contain at least one lowercase letter.
    end,
    dependencies = {
      { "nvim-lua/plenary.nvim" },
      { "nvim-telescope/telescope.nvim" },
      { "Shatur/neovim-session-manager" },
    },
    lazy = false,
    priority = 100,
  }, -- Maintains your recent project history and uses Telescope to select from autosaved sessions.
}

--#######################################
--## Code
--#######################################
local code_plugins    = {
  { "folke/trouble.nvim", cmd = { "TroubleToggle" }, opts = code.trouble, }, -- diagnostics, references, telescope results, quickfix and location lists
  {
    "rmagatti/goto-preview",
    opts = code.goto_preview,
    keys = {
      { "gpd", function() require("goto-preview").goto_preview_definition() end,     desc = "Goto preview definition" },
      { "gpD", function() require('goto-preview').goto_preview_declaration() end,    desc = "Goto preview declaration" },
      { "gpr", function() require('goto-preview').goto_preview_references() end,     desc = "Goto preview references" },
      { "gpI", function() require('goto-preview').goto_preview_implementation() end, desc = "Goto preview implementation" },
      { "gP",  function() require('goto-preview').close_all_win() end,               desc = "Close all preview windows" },
    },
  }, -- Previewing goto definition calls
  {
    "kevinhwang91/nvim-ufo",
    event = { "InsertEnter" },
    dependencies = { "kevinhwang91/promise-async" },
    config = code.ufo,
    keys = {
      { "zR", function() require("ufo").openAllFolds() end,               desc = "Open all folds" },
      { "zM", function() require("ufo").closeAllFolds() end,              desc = "Close all folds" },
      { "zr", function() require("ufo").openFoldsExceptKinds() end,       desc = "Fold less" },
      { "zm", function() require("ufo").closeFoldsWith() end,             desc = "Fold more" },
      { "zp", function() require("ufo").peekFoldedLinesUnderCursor() end, desc = "Peek fold" },
    },
  }, -- Better Folder
  {
    "folke/todo-comments.nvim",
    cmd = { "TodoTrouble", "TodoTelescope" },
    event = "BufRead",
    keys = {
      { "]t", function() require("todo-comments").jump_next() end, desc = "Next todo comment" },
      { "[t", function() require("todo-comments").jump_prev() end, desc = "Previous todo comment" },
    },
  }, -- Finds and lists all of the TODO, HACK, BUG, etc comment
  {
    "jackMort/ChatGPT.nvim",
    cmd = { "ChatGPT", "ChatGPTActAs", "ChatGPTEditWithInstructions", "ChatGPTRun", },
    config = code.ChatGPT,
    dependencies = {
      "MunifTanjim/nui.nvim",
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim"
    }
  }, -- Effortless Natural Language Generation with OpenAI's ChatGPT API
}

--#######################################
--## USELESS PLAY
--#######################################
local useless_plugins = {
  { "Eandrju/cellular-automaton.nvim", cmd = "CellularAutomaton", }, -- Aesthetically pleasing, cellular automaton animations.
}

local mergedTables    = { ui_plugins, editor_plugins, tool_plugins, code_plugins, useless_plugins }

for _, pluginsTable in ipairs(mergedTables) do
  for _, plugin in ipairs(pluginsTable) do
    table.insert(lvim.plugins, plugin)
  end
end
