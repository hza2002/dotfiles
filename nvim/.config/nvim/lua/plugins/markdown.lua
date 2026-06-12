local markdownlint_config = vim.fn.stdpath("config") .. "/.markdownlint.jsonc"

return {
  {
    "iamcco/markdown-preview.nvim",
    optional = true,
    init = function()
      local assets = vim.fn.stdpath("config") .. "/assets"
      vim.g.mkdp_markdown_css = assets .. "/github-markdown.css"
      vim.g.mkdp_highlight_css = assets .. "/github-highlight.css"
    end,
  },
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters = {
        ["markdownlint-cli2"] = {
          args = { "--config", markdownlint_config, "-" },
        },
      },
    },
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters = {
        ["markdownlint-cli2"] = {
          args = { "--fix", "--config", markdownlint_config, "$FILENAME" },
        },
      },
    },
  },
}
