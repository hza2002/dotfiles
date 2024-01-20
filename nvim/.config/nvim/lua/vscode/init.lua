-- Visual Block -- 同步选取范围给vscode😅
-- keymap("x", "`", "<Cmd>call VSCodeNotifyVisual('noop', 1)<CR>", opts)

-- vim.cmd([[
--         " choose all
--         nmap <D-a> ggVG<Cmd>call VSCodeNotifyVisual('noop', 1)<CR>
--         xmap <D-a> ggVG<Cmd>call VSCodeNotifyVisual('noop', 1)<CR>

--         " Bind D-/ to C-/ to comment
--         nmap <D-/> <C-/>
--         xmap <D-/> <C-/>
--     ]])

vim.g.mapleader = " "

local keymaps = {
  insert_mode = {
    -- Better Editor
    ["<C-e>"] = "<esc>A",
    ["<C-a>"] = "<esc>I",
  },

  normal_mode = {
    -- Better Editor
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
  },

  visual_mode = {
    -- Better indenting
    ["<"] = "<gv",
    [">"] = ">gv",
  },

  visual_block_mode = {
    ["p"] = 'p:let @+=@0<cr>:let @"=@0<cr>',
  },
}

local leader = {
  -- insert_mode = {
  -- },

  normal_mode = {
    ["<leader>q"] = "<cmd>confirm q<CR>",
    ["<leader>/"] = "<Cmd>call VSCodeNotify('editor.action.commentLine')<CR>",
    ["<leader>e"] = "<Cmd>call VSCodeNotify('workbench.view.explorer')<CR>",
    ["<leader>c"] = "<Cmd>call VSCodeNotify('workbench.action.closeActiveEditor')<CR>",
    -- file
    ["<leader>f"] = "<Cmd>call VSCodeNotify('workbench.action.quickOpen')<CR>",
    ["<leader>r"] = "<Cmd>call VSCodeNotify('workbench.action.openRecent')<CR>",
    -- window
    ["<leader>w"] = "<Cmd>call VSCodeNotify('workbench.action.closeActiveEditor')<CR>",
    -- ["<leader>h"] = "<Cmd>call VSCodeNotify('workbench.action.moveActiveEditorGroupLeft')<CR>",
    -- ["<leader>j"] = "<Cmd>call VSCodeNotify('workbench.action.moveActiveEditorGroupDown')<CR>",
    -- ["<leader>k"] = "<Cmd>call VSCodeNotify('workbench.action.moveActiveEditorGroupUp')<CR>",
    -- ["<leader>l"] = "<Cmd>call VSCodeNotify('workbench.action.moveActiveEditorGroupRight')<CR>",
  },

  -- visual_mode = {
  -- },

  -- visual_block_mode = {
  -- },
}

local generic_opts_any = { noremap = false, silent = true }

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
    vim.api.nvim_set_keymap(mode, key, val, opt)
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
