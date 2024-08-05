vim.g.mapleader = " "

-- synchronously executes a vscode command.
local function call(action)
  return string.format("<Cmd>lua require('vscode-neovim').call('%s')<CR>", action)
end

-- Asynchronously executes a vscode command.
-- local function action(action)
--   return string.format("<Cmd>lua require('vscode-neovim').call('%s')<CR>", action)
-- end

local keymaps = {
  insert_mode = {
    -- Editor
    ["<C-e>"] = "<esc>A",
    ["<C-a>"] = "<esc>I",
    ["<C-o>"] = call('lineBreakInsert'),
  },

  normal_mode = {
    -- Editor
    ["<Esc><Esc>"] = '<cmd>let @/=""<cr>',
    ["j"]          = "gj",
    ["k"]          = "gk",
    -- Split window
    ["ss"]         = call('workbench.action.splitEditorRight'),
    ["sv"]         = call('workbench.action.splitEditorDown'),
    -- Fold
    ["zd"]         = call('editor.removeManualFoldingRanges'),
    ["zo"]         = call('editor.unfold'),
    ["zO"]         = call('editor.unfoldRecursively'),
    ["zc"]         = call('editor.fold'),
    ["zC"]         = call('editor.foldRecursively'),
    ["za"]         = call('editor.toggleFold'),
    ["zM"]         = call('editor.foldAll'),
    ["zR"]         = call('editor.unfoldAll'),
    ["zp"]         = call('editor.gotoParentFold'),
    ["zj"]         = call('editor.gotoNextFold'),
    ["zk"]         = call('editor.gotoPreviousFold'),
    -- Lsp
    ["gr"]         = call('editor.action.goToReferences'),
    ["gR"]         = call('editor.action.referenceSearch.trigger'),
  },

  visual_mode = {
    -- Fold
    ["zf"] = call('editor.createFoldingRangeFromSelection'),
    -- Indent
    ["<"]  = call('editor.action.outdentLines'),
    [">"]  = call('editor.action.indentLines'),
  },

  visual_block_mode = {
    ["p"] = 'p:let @+=@0<cr>:let @"=@0<cr>',
  },
}

local leader = {
  normal_mode = {
    -- Editor
    ["<leader>."] = call('breadcrumbs.toggleToOn'),
    ["<leader>/"] = call('editor.action.commentLine'),
    ["<leader>:"] = call('workbench.action.gotoLine'),
    ["<leader>c"] = call('workbench.action.closeActiveEditor'),
    ["<leader>q"] = call('editor.action.quickFix'),
    -- file
    ["<leader>f"] = call('workbench.action.quickOpen'),
    ["<leader>r"] = call('workbench.action.openRecent'),
    --Lsp
    ["<leader>lr"] = call('editor.action.rename'),
    ["<leader>lf"] = call('editor.action.formatDocument'),
    ["<leader>ls"] = call('workbench.action.gotoSymbol'),
    -- window
    ["<leader>wm"] = call('workbench.action.toggleEditorWidths'), -- max/min
    ["<leader>we"] = call('workbench.action.evenEditorWidths'),   -- equal
  },

  visual_mode = {
    ["<leader>/"] = "<Cmd>lua require('vscode-neovim').call('editor.action.commentLine')<CR>",
  },

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
