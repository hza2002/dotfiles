--[[Do not use these in vscode-neovim:
  Anything that renders decorators very often (VSCode has built-in):
      Line number extensions
      Indent guide extensions
      Brackets highlighter extensions
  VSCode extensions that delay the extension host
  VIM plugins that increase latency and cause performance problems.
      Make sure to disable unneeded plugins, as many of them don't make sense with VSCode and may cause problems.
      You don't need any code, highlighting, completion, LSP plugins as well any plugins that spawn windows/buffers (nerdtree and similar), fuzzy-finders, etc.
      Many navigation/textobject/editing plugins should be fine.
]]
local nocode = function() return not vim.g.vscode end
local fn = vim.fn

-- Automatically install packer
local install_path = fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"
if fn.empty(fn.glob(install_path)) > 0 then
  PACKER_BOOTSTRAP = fn.system({
    "git",
    "clone",
    "--depth",
    "1",
    "https://github.com/wbthomason/packer.nvim",
    install_path,
  })
  print("Installing packer close and reopen Neovim...")
  vim.cmd([[packadd packer.nvim]])
end

-- Autocommand that reloads neovim whenever you save the plugins.lua file
vim.cmd([[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins.lua source <afile> | PackerSync
  augroup end
]])

-- Use a protected call so we don't error out on first use
local status_ok, packer = pcall(require, "packer")
if not status_ok then
  return
end

-- Have packer use a popup window
packer.init({
  display = {
    open_fn = function()
      return require("packer.util").float({ border = "rounded" })
    end,
  },
})

-- Install your plugins here
packer.startup(function(use)
  use 'wbthomason/packer.nvim' -- Packer can manage itself

  use 'tpope/vim-surround'

  use {
    'phaazon/hop.nvim',
    branch = 'v2', -- optional but strongly recommended
    config = function()
      local hop = require('hop')
      hop.setup({ create_hl_autocmd = false })
      vim.keymap.set('', 'f', function() hop.hint_words() end, { remap = true })
      vim.keymap.set('', 't', function() hop.hint_lines_skip_whitespace() end, { remap = true })
      vim.cmd([[
        hi HopNextKey guifg=#ffff66
        hi HopNextKey1 guifg=#2acaea
        hi HopNextKey2 guifg=#ffa500
      ]])
    end
  }

  -- Better movement
  use {
    'PHSix/faster.nvim',
    event = { "VimEnter *" },
    config = function()
      -- vim.api.nvim_set_keymap('n', 'j', '<Plug>(faster_move_j)', { noremap = false, silent = true })
      -- vim.api.nvim_set_keymap('n', 'k', '<Plug>(faster_move_k)', { noremap = false, silent = true })
      -- or
      vim.api.nvim_set_keymap('n', 'gj', '<Plug>(faster_move_gj)', { noremap = false, silent = true })
      vim.api.nvim_set_keymap('n', 'gk', '<Plug>(faster_move_gk)', { noremap = false, silent = true })
      -- if you need map in visual mode
      -- vim.api.nvim_set_keymap('v', 'j', '<Plug>(faster_vmove_j)', {noremap=false, silent=true})
      -- vim.api.nvim_set_keymap('v', 'k', '<Plug>(faster_vmove_k)', {noremap=false, silent=true})
    end,
    cond = nocode
  }

  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if PACKER_BOOTSTRAP then
    require("packer").sync()
  end
end)
