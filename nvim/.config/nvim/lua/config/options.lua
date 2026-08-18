-- Loaded after LazyVim's own options; only override what differs from defaults.
local opt = vim.opt

opt.conceallevel = 0 -- show raw markup (LazyVim default: 2)
opt.scrolloff = 8 -- more vertical context (LazyVim default: 4)
opt.numberwidth = 2 -- narrower number column (default: 4)
opt.showtabline = 2 -- always show the tabline
opt.whichwrap = "bs<>[]hl" -- let these keys cross line boundaries
opt.more = false -- don't pause long listings
opt.timeoutlen = 300 -- LazyVim default; bump later once chord muscle memory builds
opt.updatetime = 100 -- faster CursorHold (LazyVim default: 200)
opt.writebackup = false -- no backup while a file is being edited

-- Folding: keep buffers unfolded on start (nvim-ufo, see plugins/code.lua)
opt.foldlevelstart = 99
opt.foldcolumn = "0"
