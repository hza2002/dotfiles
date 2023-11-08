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

if vim.g.vscode then
    -- Normal --
    -- Resize with arrows
    keymap("n", "<C-Up>", "<C-w>+", remap)
    keymap("n", "<C-Down>", "<C-w>-", remap)
    keymap("n", "<C-Left>", "<C-w><", remap)
    keymap("n", "<C-Right>", "<C-w>>", remap)

    -- folding
    keymap("n", "za", "<Cmd>call VSCodeNotify('editor.toggleFold')<CR>", opts)
    keymap("n", "zp", "<Cmd>call VSCodeNotify('editor.gotoParentFold')<CR>", opts)
    keymap("n", "zj", "<Cmd>call VSCodeNotify('editor.gotoNextFold')<CR>", opts)
    keymap("n", "zk", "<Cmd>call VSCodeNotify('editor.gotoPreviousFold')<CR>", opts)
    keymap("n", "zC", "<Cmd>call VSCodeNotify('editor.foldAll')<CR>", opts)
    keymap("n", "z0", "<Cmd>call VSCodeNotify('editor.unfoldAll')<CR>", opts)

    -- go to reference
    keymap("n", "gr", "<Cmd>call VSCodeNotify('editor.action.goToReferences')<CR>", opts)
    -- line break insert
    keymap("n", "K", "<Cmd>call VSCodeNotify('lineBreakInsert')<CR>", opts)

    -- switch tab
    keymap("n", "H", "<Cmd>call VSCodeNotify('workbench.action.previousEditorInGroup')<CR>", opts)
    keymap("n", "L", "<Cmd>call VSCodeNotify('workbench.action.nextEditorInGroup')<CR>", opts)

    -- Visual Block --
    -- 同步选取范围给vscode😅
    keymap("x", "`", "<Cmd>call VSCodeNotifyVisual('noop', 1)<CR>", opts)

    vim.cmd([[
        " choose all
        nmap <D-a> ggVG<Cmd>call VSCodeNotifyVisual('noop', 1)<CR>
        xmap <D-a> ggVG<Cmd>call VSCodeNotifyVisual('noop', 1)<CR>

        " Bind D-/ to C-/ to comment
        nmap <D-/> <C-/>
        xmap <D-/> <C-/>
    ]])
else
    -- Normal --
    -- Resize with arrows
    keymap("n", "<C-Up>", ":resize +2<CR>", opts)
    keymap("n", "<C-Down>", ":resize -2<CR>", opts)
    keymap("n", "<C-Left>", ":vertical resize -2<CR>", opts)
    keymap("n", "<C-Right>", ":vertical resize +2<CR>", opts)

    -- Move text up and down
    keymap("n", "<A-DOWN>", ":m .+1<CR>==", opts)
    keymap("n", "<A-UP>", ":m .-2<CR>==", opts)

    -- Navigate buffers
    keymap("n", "L", ":bnext<CR>", opts)
    keymap("n", "H", ":bprevious<CR>", opts)

    -- Visual --
    -- Move text up and down
    keymap("v", "<A-DOWN>", ":m .+1<CR>==", opts)
    keymap("v", "<A-UP>", ":m .-2<CR>==", opts)

    -- Visual Block --
    -- Move text up and down
    keymap("x", "<A-Down>", ":move '>+1<CR>gv-gv", opts)
    keymap("x", "<A-UP>", ":move '<-2<CR>gv-gv", opts)
end
