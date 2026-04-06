vim.api.nvim_create_autocmd("InsertLeave", {
  pattern = "*",
  callback = function()
    vim.fn.system("macism com.apple.keylayout.ABC")
  end,
})

if vim.g.vscode then
  require("code")
else
  require("user")
end
