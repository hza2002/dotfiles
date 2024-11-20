function switch_keyboard_layout(layoutName)
end

vim.api.nvim_create_autocmd("InsertLeave", {
  pattern = "*",
  callback = function()
    vim.fn.system("im-select com.apple.keylayout.ABC")
  end,
})

if vim.g.vscode then
  require("code")
else
  require("user")
end
