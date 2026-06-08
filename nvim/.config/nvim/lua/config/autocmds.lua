local group = vim.api.nvim_create_augroup("user_markdown", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = { "markdown", "markdown.mdx" },
  callback = function()
    -- LazyVim enables English spellcheck for Markdown; it underlines Chinese text.
    vim.opt_local.spell = false
  end,
})
