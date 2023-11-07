-- insert_mode           = "i"
-- normal_mode           = "n"
-- term_mode             = "t"
-- visual_mode           = "v"
-- visual_block_mode     = "x"
-- command_mode          = "c"
-- operator_pending_mode = "o"


-- Quit
lvim.keys.normal_mode["<C-q>"] = "<cmd>qa<cr>"

-- Accelerated jk/DownUp
vim.api.nvim_set_keymap('n', 'j',
  "v:count || mode(1)[0:1] == 'no' ? '<Plug>(accelerated_jk_j)' : '<Plug>(accelerated_jk_gj)'",
  { expr = true, noremap = true, silent = true, })
vim.api.nvim_set_keymap('n', 'k',
  "v:count || mode(1)[0:1] == 'no' ? '<Plug>(accelerated_jk_k)' : '<Plug>(accelerated_jk_gk)'",
  { expr = true, noremap = true, silent = true, })

-- Save
lvim.keys.insert_mode["<D-s>"]       = "<cmd>w<cr>"
lvim.keys.normal_mode["<D-s>"]       = "<cmd>w<cr>"
lvim.keys.visual_mode["<D-s>"]       = "<cmd>w<cr><esc>"
lvim.keys.visual_block_mode["<D-s>"] = "<cmd>w<cr><esc>"
-- Copy
lvim.keys.visual_mode["<D-c>"]       = '"+y'
lvim.keys.visual_block_mode["<D-c>"] = '"+y'
-- Paste
lvim.keys.normal_mode["<D-v>"]       = '"+P'
lvim.keys.visual_mode["<D-v>"]       = '"+P'
lvim.keys.insert_mode["<D-v>"]       = '<C-R>+'
lvim.keys.command_mode["<D-v>"]      = '<C-R>+'
lvim.keys.term_mode["<D-v>"]         = '<C-R>+'

-- Editor
lvim.keys.normal_mode["$"]           = "g$"
lvim.keys.normal_mode["^"]           = "g^"
lvim.keys.normal_mode["K"]           = "i<cr><esc>"
lvim.keys.normal_mode["<Esc><Esc>"]  = '<cmd>let @/=""<cr>'
lvim.keys.visual_block_mode["p"]     = 'p:let @+=@0<cr>:let @"=@0<cr>'
lvim.keys.insert_mode["<C-e>"]       = "<esc>A"
lvim.keys.insert_mode["<C-a>"]       = "<esc>I"
vim.api.nvim_set_keymap('c', '<C-a>', "<C-b>", { noremap = true })

-- Navigation
lvim.keys.insert_mode["<C-h>"]                       = "<esc><C-w>h"
lvim.keys.insert_mode["<C-j>"]                       = "<esc><C-w>j"
lvim.keys.insert_mode["<C-k>"]                       = "<esc><C-w>k"
lvim.keys.insert_mode["<C-l>"]                       = "<esc><C-w>l"

-- Resize
lvim.keys.normal_mode["<C-Left>"]                    = "<cmd>lua require('tmux').resize_left()<cr>"
lvim.keys.normal_mode["<C-Down>"]                    = "<cmd>lua require('tmux').resize_bottom()<cr>"
lvim.keys.normal_mode["<C-Up>"]                      = "<cmd>lua require('tmux').resize_top()<cr>"
lvim.keys.normal_mode["<C-Right>"]                   = "<cmd>lua require('tmux').resize_right()<cr>"

-- BufferLine Cycle
lvim.keys.normal_mode["L"]                           = "<cmd>BufferLineCycleNext<cr>"
lvim.keys.normal_mode["H"]                           = "<cmd>BufferLineCyclePrev<cr>"

-- Terminal
lvim.builtin.terminal.execs                          = {
  { nil, "<M-h>", "Horizontal Terminal", "horizontal", 0.3 },
  { nil, "<M-v>", "Vertical Terminal",   "vertical",   0.4 },
  { nil, "<M-f>", "Float Terminal",      "float",      nil },
}

-- Alpha
lvim.builtin.alpha.dashboard.section.buttons.entries = {
  { "e", lvim.icons.ui.Watches .. "  Explorer",     "<cmd>RnvimrToggle<CR>" },
  { "f", lvim.icons.ui.FindFile .. "  Find File",   "<CMD>Telescope find_files<CR>" },
  { "n", lvim.icons.ui.NewFile .. "  New File",     "<CMD>ene!<CR>" },
  { "p", lvim.icons.ui.Project .. "  Projects ",    "<cmd>Telescope neovim-project<cr>" },
  { "r", lvim.icons.ui.History .. "  Recent files", "<cmd>Telescope oldfiles <CR>" },
  { "t", lvim.icons.ui.FindText .. "  Find Text",   "<CMD>Telescope live_grep<CR>" },
  { "q", lvim.icons.ui.Close .. "  Quit",           "<CMD>quit<CR>" },
}

-- LSP Bindings
-- To modify your LSP keybindings use lvim.lsp.buffer_mappings.[normal|visual|insert]_mode
lvim.lsp.buffer_mappings.normal_mode["K"]            = nil
lvim.lsp.buffer_mappings.normal_mode["gh"]           = { vim.lsp.buf.hover, "Show documentation" }

-- Telescope
local _, actions                                     = pcall(require, "telescope.actions")
lvim.builtin.telescope.defaults.mappings             = { i = { ["<Esc>"] = actions.close, }, }

-- Ranger
lvim.builtin.which_key.mappings.e                    = { "<cmd>RnvimrToggle<CR>", "Explorer" }

-- LSP
lvim.builtin.which_key.mappings.l.o                  = { "<cmd>SymbolsOutline<cr>", "Symbols Outline" }

-- Buffer
lvim.builtin.which_key.mappings.b.b                  = { "<cmd>Telescope buffers<cr>", "Search" }
lvim.builtin.which_key.mappings.b.p                  = { "<cmd>BufferLineCyclePrev<cr>", "Previous" }

-- Search
lvim.builtin.which_key.mappings["s"]                 = {
  name = "Search",
  C    = { "<cmd>Telescope commands<cr>", "Commands" },
  H    = { "<cmd>Telescope highlights<cr>", "Highlight groups" },
  L    = { "<cmd>Telescope software-licenses find<cr>", "Licenses" },
  M    = { "<cmd>Telescope man_pages<cr>", "Man Pages" },
  R    = { "<cmd>Telescope registers<cr>", "Registers" },
  T    = { "<cmd>TodoTelescope keywords=TODO,FIX,FIXME<cr>", "Todo/Fix/Fixme" },
  U    = { "<cmd>UrlView<cr>", "View buffer URLs", },
  h    = { "<cmd>Telescope help_tags<cr>", "Help" },
  k    = { "<cmd>Telescope keymaps<cr>", "Keymaps" },
  m    = { "<cmd>Telescope marks<cr>", "Marks" },
  r    = {
    function()
      require("spectre").toggle({
        path = vim.fn.fnameescape(vim.fn.expand("%:p:.")),
        search_text = vim.fn.expand("<cword>")
      })
    end, "Replace on current file" },
  s    = { "<cmd>Telescope resume<cr>", "Resume last search" },
  t    = { "<cmd>TodoTelescope<cr>", "Todo" },
  u    = { function() require("telescope").extensions.undo.undo() end, "Undo tree" },
}

-- Projects and sessions
lvim.builtin.which_key.mappings["p"]                 = {
  name = "Projects",
  f = { "<cmd>Telescope neovim-project discover<cr>", "Find" },
  l = { "<cmd>NeovimProjectLoadRecent<cr>", "Load recent" },
  p = { "<cmd>Telescope neovim-project history<cr>", "History" },
}

-- Plugins
lvim.builtin.which_key.mappings["P"]                 = {
  name = "Plugins",
  S = { "<cmd>Lazy clear<cr>", "Status" },
  c = { "<cmd>Lazy clean<cr>", "Clean" },
  d = { "<cmd>Lazy debug<cr>", "Debug" },
  i = { "<cmd>Lazy install<cr>", "Install" },
  l = { "<cmd>Lazy log<cr>", "Log" },
  p = { "<cmd>Lazy profile<cr>", "Profile" },
  s = { "<cmd>Lazy sync<cr>", "Sync" },
  u = { "<cmd>Lazy update<cr>", "Update" },
}

-- Lunarvim
lvim.builtin.which_key.mappings.L.C                  = { "<cmd>Telescope colorscheme<cr>", "Colorschemes" }

-- Files
lvim.builtin.which_key.mappings["f"]                 = {
  name = "Files",
  b    = { "<cmd>Telescope current_buffer_fuzzy_find<cr>", "Find in current buffer" },
  f    = { function() require("lvim.core.telescope.custom-finders").find_project_files() end, "Find File", },
  g    = { "<cmd>Telescope live_grep<cr>", "Grep text" },
  n    = { "<cmd>enew<cr>", "New File" },
  r    = { "<cmd>Telescope oldfiles<cr>", "Open Recent File" },
}

-- Messages
lvim.builtin.which_key.mappings["m"]                 = {
  name = "Messages",
  c = { function() require("noice").cmd("dismiss") end, "Clear all" },
  m = { "<cmd>Telescope notify<cr>", "History" },
}

-- Windows
function PickWindow()
  local picked_window_id = require('window-picker').pick_window({
    include_current_win = false,
    hint = 'floating-big-letter',
  }) or vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(picked_window_id)
end

lvim.keys.normal_mode["<M-w>"]       = "<cmd>lua PickWindow()<cr>"

lvim.builtin.which_key.mappings["w"] = {
  name = "Windows",
  M = { "<cmd>MinimapToggle<cr>", "Minimap" },
  c = { "<C-w>c", "Close" },
  m = { "<cmd>FocusMaxOrEqual<cr>", "Max or Equal" },
  s = { "<C-w>s", "Split Horizontally" },
  v = { "<C-w>v", "Split Vertically" },
  w = { "<cmd>WinShift<cr>", "Rearrange" },
  x = { function()
    local window = require('window-picker').pick_window({
      include_current_win = false,
      hint = 'floating-big-letter',
    })
    local target_buffer = vim.fn.winbufnr(window)
    if target_buffer ~= nil then
      vim.api.nvim_win_set_buf(window, 0)        -- Set the target window to contain current buffer
      vim.api.nvim_win_set_buf(0, target_buffer) -- Set current window to contain target buffer
    end
  end,
    "Swap",
  },
}

-- Trouble
lvim.builtin.which_key.mappings["t"] = {
  name = "Diagnostics",
  d = { "<cmd>TroubleToggle document_diagnostics<cr>", "document" },
  l = { "<cmd>TroubleToggle loclist<cr>", "loclist" },
  q = { "<cmd>TroubleToggle quickfix<cr>", "quickfix" },
  r = { "<cmd>TroubleToggle lsp_references<cr>", "references" },
  t = { "<cmd>TroubleToggle<cr>", "trouble" },
  w = { "<cmd>TroubleToggle workspace_diagnostics<cr>", "workspace" },
}
