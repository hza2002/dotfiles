-- VSCode-specific mappings and hooks for vscode-neovim.
local vscode = require("vscode")
local map = vim.keymap.set

vim.api.nvim_create_autocmd("InsertLeave", {
  group = vim.api.nvim_create_augroup("user_vscode_im_select", { clear = true }),
  callback = function()
    vim.fn.system("macism com.apple.keylayout.ABC")
  end,
})

local function action(command)
  return function()
    vscode.call(command)
  end
end

local opts = { silent = true }

-- Keep personal insert-mode line navigation from the normal LazyVim config.
map("i", "<C-e>", "<esc>A", vim.tbl_extend("force", opts, { desc = "Jump to end of line" }))
map("i", "<C-a>", "<esc>I", vim.tbl_extend("force", opts, { desc = "Jump to start of line" }))

-- Window/editor commands aligned with LazyVim's default window keymaps.
map(
  "n",
  "<leader>-",
  action("workbench.action.splitEditorDown"),
  vim.tbl_extend("force", opts, { desc = "Split Window Below" })
)
map(
  "n",
  "<leader>|",
  action("workbench.action.splitEditorRight"),
  vim.tbl_extend("force", opts, { desc = "Split Window Right" })
)
map(
  "n",
  "<leader>wd",
  action("workbench.action.closeActiveEditor"),
  vim.tbl_extend("force", opts, { desc = "Delete Window" })
)
map(
  "n",
  "<leader>wm",
  action("workbench.action.toggleEditorWidths"),
  vim.tbl_extend("force", opts, { desc = "Toggle Window Zoom" })
)

-- LSP-like actions. Native Neovim LSP is disabled in VSCode mode, so these call VSCode.
map("n", "gd", action("editor.action.revealDefinition"), vim.tbl_extend("force", opts, { desc = "Goto Definition" }))
map("n", "gr", action("editor.action.goToReferences"), vim.tbl_extend("force", opts, { desc = "References" }))
map(
  "n",
  "gI",
  action("editor.action.goToImplementation"),
  vim.tbl_extend("force", opts, { desc = "Goto Implementation" })
)
map(
  "n",
  "gy",
  action("editor.action.goToTypeDefinition"),
  vim.tbl_extend("force", opts, { desc = "Goto Type Definition" })
)
map("n", "gD", action("editor.action.goToDeclaration"), vim.tbl_extend("force", opts, { desc = "Goto Declaration" }))
map("n", "K", action("editor.action.showHover"), vim.tbl_extend("force", opts, { desc = "Hover" }))
map("n", "<leader>ca", action("editor.action.quickFix"), vim.tbl_extend("force", opts, { desc = "Code Action" }))
map("x", "<leader>ca", action("editor.action.quickFix"), vim.tbl_extend("force", opts, { desc = "Code Action" }))
map("n", "<leader>cr", action("editor.action.rename"), vim.tbl_extend("force", opts, { desc = "Rename" }))
map("n", "<leader>cf", action("editor.action.formatDocument"), vim.tbl_extend("force", opts, { desc = "Format" }))
map("x", "<leader>cf", action("editor.action.formatSelection"), vim.tbl_extend("force", opts, { desc = "Format" }))
