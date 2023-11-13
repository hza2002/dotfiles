if not vim.g.vscode then
  -- LSP
  lvim.builtin.which_key.mappings.l.o  = { "<cmd>SymbolsOutline<cr>", "Symbols Outline" }

  -- Projects and sessions
  lvim.builtin.which_key.mappings["p"] = {
    name = "Projects",
    f = { "<cmd>Telescope neovim-project discover<cr>", "Find" },
    l = { "<cmd>NeovimProjectLoadRecent<cr>", "Load recent" },
    p = { "<cmd>Telescope neovim-project history<cr>", "History" },
  }

  -- Lunarvim
  lvim.builtin.which_key.mappings.L.C  = { "<cmd>Telescope colorscheme<cr>", "Colorschemes" }

  -- Files
  lvim.builtin.which_key.mappings["f"] = {
    name = "Files",
    b    = { "<cmd>Telescope current_buffer_fuzzy_find<cr>", "Find in current buffer" },
    f    = { function() require("lvim.core.telescope.custom-finders").find_project_files() end, "Find File", },
    g    = { "<cmd>Telescope live_grep<cr>", "Grep text" },
    n    = { "<cmd>enew<cr>", "New File" },
    r    = { "<cmd>Telescope oldfiles<cr>", "Open Recent File" },
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
end

-- Visual Block --
-- 同步选取范围给vscode😅
-- keymap("x", "`", "<Cmd>call VSCodeNotifyVisual('noop', 1)<CR>", opts)

-- vim.cmd([[
--         " choose all
--         nmap <D-a> ggVG<Cmd>call VSCodeNotifyVisual('noop', 1)<CR>
--         xmap <D-a> ggVG<Cmd>call VSCodeNotifyVisual('noop', 1)<CR>

--         " Bind D-/ to C-/ to comment
--         nmap <D-/> <C-/>
--         xmap <D-/> <C-/>
--     ]])


local keymaps = {
  insert_mode = {
    -- Better Editor
    ["<C-e>"] = "<esc>A",
    ["<C-a>"] = "<esc>I",
    -- Move current line / block with Alt-j/k ala vscode.
    ["<A-j>"] = "<Esc>:m .+1<CR>==gi",
    -- Move current line / block with Alt-j/k ala vscode.
    ["<A-k>"] = "<Esc>:m .-2<CR>==gi",
    -- navigation
    ["<C-h>"] = "<esc><C-w>h",
    ["<C-j>"] = "<esc><C-w>j",
    ["<C-k>"] = "<esc><C-w>k",
    ["<C-l>"] = "<esc><C-w>l",
  },

  normal_mode = {
    -- Better Editor
    ["$"]          = "g$",
    ["^"]          = "g^",
    ["K"]          = "<Cmd>call VSCodeNotify('lineBreakInsert')<CR>",
    ["<Esc><Esc>"] = '<cmd>let @/=""<cr>',

    -- Better window movement
    ["<C-h>"]      = "<C-w>h",
    ["<C-j>"]      = "<C-w>j",
    ["<C-k>"]      = "<C-w>k",
    ["<C-l>"]      = "<C-w>l",

    -- Resize with arrows
    ["<C-Up>"]     = "<C-w>+",
    ["<C-Down>"]   = "<C-w>-",
    ["<C-Left>"]   = "<C-w><",
    ["<C-Right>"]  = "<C-w>>",
    -- keymap("n", "<C-Up>", ":resize +2<CR>", opts)
    -- keymap("n", "<C-Down>", ":resize -2<CR>", opts)
    -- keymap("n", "<C-Left>", ":vertical resize -2<CR>", opts)
    -- keymap("n", "<C-Right>", ":vertical resize +2<CR>", opts)

    -- Move current line / block with Alt-j/k a la vscode.
    ["<A-j>"]      = ":m .+1<CR>==",
    ["<A-k>"]      = ":m .-2<CR>==",

    -- QuickFix
    ["]q"]         = ":cnext<CR>",
    ["[q"]         = ":cprev<CR>",
    ["<C-q>"]      = ":call QuickFixToggle()<CR>",

    -- BufferLine Cycle
    ["H"]          = "<Cmd>call VSCodeNotify('workbench.action.previousEditorInGroup')<CR>",
    ["L"]          = "<Cmd>call VSCodeNotify('workbench.action.nextEditorInGroup')<CR>",

    -- folding
    ["za"]         = "<Cmd>call VSCodeNotify('editor.toggleFold')<CR>",
    ["zp"]         = "<Cmd>call VSCodeNotify('editor.gotoParentFold')<CR>",
    ["zj"]         = "<Cmd>call VSCodeNotify('editor.gotoNextFold')<CR>",
    ["zk"]         = "<Cmd>call VSCodeNotify('editor.gotoPreviousFold')<CR>",
    ["zC"]         = "<Cmd>call VSCodeNotify('editor.foldAll')<CR>",
    ["z0"]         = "<Cmd>call VSCodeNotify('editor.unfoldAll')<CR>",

    -- Lsp
    ["gh"]         = "vim.lsp.buf.hover",
    ["gr"]         = "<Cmd>call VSCodeNotify('editor.action.goToReferences')<CR>",

    -- terminal
    ["<C-\\>"]     = "<Cmd>call VSCodeNotify('workbench.action.terminal.toggleTerminal')<CR>",
    ["<M-h>"]      = "Horizontal Terminal",
    ["<M-v>"]      = "Vertical Terminal",
    ["<M-f>"]      = "Float Terminal",
  },

  term_mode = {
    -- Terminal window navigation
    ["<C-h>"] = "<C-\\><C-N><C-w>h",
    ["<C-j>"] = "<C-\\><C-N><C-w>j",
    ["<C-k>"] = "<C-\\><C-N><C-w>k",
    ["<C-l>"] = "<C-\\><C-N><C-w>l",
  },

  visual_mode = {
    -- Better indenting
    ["<"] = "<gv",
    [">"] = ">gv",

    -- ["p"] = '"0p',
    -- ["P"] = '"0P',
  },

  visual_block_mode = {
    ["p"]     = 'p:let @+=@0<cr>:let @"=@0<cr>',
    -- Move current line / block with Alt-j/k ala vscode.
    ["<A-j>"] = ":m '>+1<CR>gv-gv",
    ["<A-k>"] = ":m '<-2<CR>gv-gv",
  },

  command_mode = {
    ['<C-a>'] = { "<C-b>" },

    -- navigate tab completion with <c-j> and <c-k>
    -- runs conditionally
    ["<C-j>"] = { 'pumvisible() ? "\\<C-n>" : "\\<C-j>"', { expr = true, noremap = true } },
    ["<C-k>"] = { 'pumvisible() ? "\\<C-p>" : "\\<C-k>"', { expr = true, noremap = true } },
  },
}

local leader = {
  insert_mode = {
  },

  normal_mode = {
    ["q"] = "<cmd>confirm q<CR>",
    ["/"] = "<Cmd>call VSCodeNotify('editor.action.commentLine')<CR>",
    ["e"] = "<Cmd>call VSCodeNotify('workbench.view.explorer')<CR>",
    ["c"] = "<Cmd>call VSCodeNotify('workbench.action.closeActiveEditor')<CR>",
    -- file
    ["f"] = "<Cmd>call VSCodeNotify('workbench.action.quickOpen')<CR>",
    ["r"] = "<Cmd>call VSCodeNotify('workbench.action.openRecent')<CR>",
    -- window
    ["w"] = "<Cmd>call VSCodeNotify('workbench.action.closeActiveEditor')<CR>",
    ["h"] = "<Cmd>call VSCodeNotify('workbench.action.moveActiveEditorGroupLeft')<CR>",
    ["j"] = "<Cmd>call VSCodeNotify('workbench.action.moveActiveEditorGroupDown')<CR>",
    ["k"] = "<Cmd>call VSCodeNotify('workbench.action.moveActiveEditorGroupUp')<CR>",
    ["l"] = "<Cmd>call VSCodeNotify('workbench.action.moveActiveEditorGroupRight')<CR>",



  },

  term_mode = {
  },

  visual_mode = {
    ["/"] = { "<Plug>(comment_toggle_linewise_visual)", "Comment toggle linewise (visual)" },
  },

  visual_block_mode = {
    ["/"] = { "<Plug>(comment_toggle_linewise_visual)", "Comment toggle linewise (visual)" },
  },

  command_mode = {
  },
}

local generic_opts_any = { noremap = true, silent = true }

local generic_opts = {
  insert_mode = generic_opts_any,
  normal_mode = generic_opts_any,
  visual_mode = generic_opts_any,
  visual_block_mode = generic_opts_any,
  command_mode = generic_opts_any,
  operator_pending_mode = generic_opts_any,
  term_mode = { silent = true },
}

local mode_adapters = {
  insert_mode = "i",
  normal_mode = "n",
  term_mode = "t",
  visual_mode = "v",
  visual_block_mode = "x",
  command_mode = "c",
  operator_pending_mode = "o",
}

-- Set key mappings individually
-- @param mode The keymap mode, can be one of the keys of mode_adapters
-- @param key The key of keymap
-- @param val Can be form as a mapping or tuple of mapping and user defined opt
local function set_keymaps(mode, key, val)
  local opt = generic_opts[mode] or generic_opts_any
  if type(val) == "table" then
    opt = val[2]
    val = val[1]
  end
  if val then
    vim.keymap.set(mode, key, val, opt)
  else
    pcall(vim.api.nvim_del_keymap, mode, key)
  end
end

-- Load key mappings for a given mode
-- @param mode The keymap mode, can be one of the keys of mode_adapters
-- @param keymaps The list of key mappings
local function load_mode(mode, keymaps)
  mode = mode_adapters[mode] or mode
  for k, v in pairs(keymaps) do
    set_keymaps(mode, k, v)
  end
end

-- Load key mappings for all provided modes
-- @param keymaps A list of key mappings for each mode
local function load(keymaps)
  keymaps = keymaps or {}
  for mode, mapping in pairs(keymaps) do
    load_mode(mode, mapping)
  end
end

load(keymaps)
load(leader)
