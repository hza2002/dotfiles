-- Custom LSP server configuration (overrides the lang.clangd / lang.rust extras).
return {
  -- clangd: use the system binary (no mason), but keep LazyVim's extra defaults.
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers["*"] = opts.servers["*"] or {}
      opts.servers["*"].keys = opts.servers["*"].keys or {}
      vim.list_extend(opts.servers["*"].keys, {
        { "K", false },
        { "gh", vim.lsp.buf.hover, desc = "Hover documentation" },
      })

      local clangd = opts.servers.clangd or {}
      clangd.mason = false -- don't auto-install via mason; use clangd from PATH
      clangd.cmd = vim.tbl_filter(function(arg)
        return not arg:match("^%-%-fallback%-style=")
      end, clangd.cmd or { "clangd" })
      table.insert(clangd.cmd, "--fallback-style=Google")
      opts.servers.clangd = clangd

      -- Dart/Flutter is configured in plugins/flutter.lua.
    end,
  },

  -- rustaceanvim: clippy as the check command, all features, inlay hints.
  -- Merges into the lang.rust extra's default_settings (preserves its on_attach/dap).
  {
    "mrcjkb/rustaceanvim",
    opts = {
      server = {
        default_settings = {
          ["rust-analyzer"] = {
            check = { command = "clippy" },
            inlayHints = { enable = true },
          },
        },
      },
    },
  },
}
