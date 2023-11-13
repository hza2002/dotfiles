local opts = { noremap = true, silent = true }
local remap = { noremap = false, silent = true }

-- Shorten function name
local keymap = vim.api.nvim_set_keymap

-- general mappings --
-- Remap space as leader key
keymap("", "<Space>", "<Nop>", opts)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Modes
--   normal_mode = "n",
--   insert_mode = "i",
--   visual_mode = "v",
--   visual_block_mode = "x",
--   term_mode = "t",
--   command_mode = "c",

-- Normal --
-- better window navigation
keymap("n", "<C-h>", "<C-w>h", remap)
keymap("n", "<C-j>", "<C-w>j", remap)
keymap("n", "<C-k>", "<C-w>k", remap)
keymap("n", "<C-l>", "<C-w>l", remap)

-- window split
keymap("n", "ss", "<C-w>v", remap)
keymap("n", "sv", "<C-w>s", remap)

-- better editor
keymap("n", "j", "gj", remap)
keymap("n", "k", "gk", remap)
keymap("n", "$", "g$", remap)
keymap("n", "^", "g^", remap)

keymap("n", "<Esc><Esc>", '<Cmd>let @/=""<CR>', opts) -- no highlight

-- Visual --
keymap("v", "p", '"_dP', opts)
-- Stay in indent mode
keymap("n", "<", "<<", opts)
keymap("n", ">", ">>", opts)
keymap("v", "<", "<gv", opts)
keymap("v", ">", ">gv", opts)
