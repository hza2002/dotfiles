lvim.lsp.automatic_configuration.skipped_servers = { "clangd", "rust_analyzer" }

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

-- rustaceanvim 接管 rust_analyzer，不需要 setup()，通过 vim.g.rustaceanvim 配置
-- 必须在 plugins 初始化之前设置，不可以放在 after/ftplugin/rust.lua 里
vim.g.rustaceanvim = {
  server = {
    default_settings = {
      ["rust-analyzer"] = {
        check      = { enable = true, command = "clippy" }, -- clippy 替代默认 cargo check
        inlayHints = { enable = true },
        cargo      = { allFeatures = true },
      },
    },
  },
}
