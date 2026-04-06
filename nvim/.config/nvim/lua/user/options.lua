-- 检测是否在 VSCode 模式下运行
local is_vscode = vim.g.vscode == true

-- VSCode 模式下的配置（避免与 VSCode UI 冲突）
local vscode_options = {
  cursorline = false,
  number = false,
  relativenumber = false,
  laststatus = 0,
  signcolumn = "auto",
  showtabline = 0,
  termguicolors = false,
}

-- 普通 Neovim 模式下的配置
local nvim_options = {
  backup = false,
  clipboard = "unnamedplus",
  cmdheight = 1,
  completeopt = { "menuone", "noselect" },
  conceallevel = 0,
  cursorline = true,
  expandtab = true,
  fileencoding = "utf-8",
  foldexpr = "",
  foldmethod = "manual",
  guifont = "JetBrains_Mono,Hack_Nerd_Font",
  hidden = true,
  hlsearch = true,
  ignorecase = true,
  laststatus = 3,
  linebreak = true,
  more = false,
  mouse = "a",
  number = true,
  numberwidth = 2,
  pumheight = 10,
  relativenumber = true,
  ruler = false,
  scrolloff = 8,
  shadafile = join_paths(get_cache_dir(), "lvim.shada"),
  shiftwidth = 2,
  showmode = false,
  showtabline = 2,
  sidescrolloff = 8,
  signcolumn = "yes",
  smartcase = true,
  smartindent = true,
  splitbelow = true,
  splitright = true,
  swapfile = false,
  tabstop = 2,
  termguicolors = true,
  timeoutlen = 1000,
  title = true,
  undodir = undodir,
  undofile = true,
  updatetime = 100,
  whichwrap = "bs<>[]hl",
  wrap = false,
  writebackup = false,
}

-- 根据模式选择配置
local options = is_vscode and vscode_options or nvim_options

for k, v in pairs(options) do
  vim.opt[k] = v
end
