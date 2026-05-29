lvim.lsp.automatic_configuration.skipped_servers = { "clangd" }

local clangd_opts = {
  cmd = {
    "clangd",
    "--background-index",
    "--fallback-style=Google",
  },
  init_options = {
    fallbackFlags = { "-std=c++17" },
  },
}

require("lvim.lsp.manager").setup("clangd", clangd_opts)
