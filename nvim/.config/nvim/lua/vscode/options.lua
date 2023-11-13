local options = {
  -- DEFAULT VIM CONFIG
  backup         = false,                      -- no backup file
  clipboard      = "unnamedplus",              -- 系统剪切板
  completeopt    = { "menuone", "noselect" },  -- mostly just for cmp
  conceallevel   = 0,                          -- so that `` is visible in markdown files
  cursorline     = true,                       -- 高亮当前行
  fileencoding   = "utf-8",                    -- the encoding written to a file
  guifont        = "JetBrains_Mono_Nerd_Font", -- the font used in graphical neovim applications
  hidden         = true,                       -- required to keep multiple buffers and open multiple buffers
  hlsearch       = true,                       -- highlight all matches on previous search pattern
  ignorecase     = true,                       -- ignore case in search patterns
  laststatus     = 3,                          -- global statusline
  linebreak      = true,                       -- companion to wrap, don't split words
  more           = false,                      -- don't pause listing when screen is filled
  mouse          = "a",                        -- 鼠标可用
  pumheight      = 10,                         -- pop up menu height
  relativenumber = true,                       -- 相对行号
  scrolloff      = 8,                          -- minimal number of screen lines to keep above and below the cursor
  showmode       = false,                      -- we don't need to see things like -- INSERT -- anymore
  showtabline    = 2,                          -- always show tabs
  sidescrolloff  = 8,                          -- minimal number of screen columns either side of cursor if wrap is `false`
  signcolumn     = "yes",                      -- always show the sign column, otherwise it would shift the text each time
  smartcase      = true,                       -- smart case
  splitbelow     = true,                       -- force all horizontal splits to go below current window
  splitright     = true,                       -- force all vertical splits to go to the right of current window
  swapfile       = false,                      -- no swap file
  termguicolors  = true,                       -- set term gui colors (most terminals support this)
  timeoutlen     = 1000,                       -- time to wait for a mapped sequence to complete (in milliseconds)
  undofile       = true,                       -- enable persistent undo
  updatetime     = 100,                        -- faster completion (4000ms default)
  whichwrap      = "bs<>[]hl",                 -- which "horizontal" keys are allowed to travel to prev/next line
  wrap           = false,                      -- 单行全显示
  writebackup    = false,                      -- if a file is being edited by another program (or was written to file while editing with another program), it is not allowed to be edited

  -- Numbers
  number         = true, -- line number
  numberwidth    = 2,    -- set number column width to 2 {default 4}
  ruler          = false,

  -- Indenting
  expandtab      = true, -- convert tabs to spaces
  shiftwidth     = 2,    -- the number of spaces inserted for each indentation
  smartindent    = true, -- make indenting smarter again
  tabstop        = 2,    -- insert 2 spaces for a tab

  -- Fold
  foldenable     = true,                         -- enable fold for nvim-ufo
  foldlevel      = 99,                           -- set high foldlevel for nvim-ufo
  foldlevelstart = 99,                           -- start with all code unfolded
  foldcolumn     = '0',                          -- 1' is good, '0' is not bad
  foldmethod     = "expr",                       -- folding, set to "expr" for treesitter based folding
  foldexpr       = "nvim_treesitter#foldexpr()", -- set to "nvim_treesitter#foldexpr()" for treesitter based folding
}

for k, v in pairs(options) do
  vim.opt[k] = v
end
