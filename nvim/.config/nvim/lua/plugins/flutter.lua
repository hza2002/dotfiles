-- Dart/Flutter development with FVM-managed SDKs.
-- flutter-tools owns dartls; its official `fvm` integration resolves .fvm from Neovim's cwd.
return {
  {
    "nvim-flutter/flutter-tools.nvim",
    ft = "dart",
    dependencies = { "nvim-lua/plenary.nvim" },
    init = function()
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("user_flutter_document_color", { clear = true }),
        callback = function(event)
          if vim.bo[event.buf].filetype == "dart" then
            vim.lsp.document_color.enable(true, { bufnr = event.buf })
          end
        end,
      })
    end,
    opts = {
      fvm = true,
      lsp = {
        settings = {
          showTodos = true,
          completeFunctionCalls = true,
          renameFilesWithClasses = "prompt",
          updateImportsOnRename = true,
          analysisExcludedFolders = {
            vim.fn.expand("$HOME/.pub-cache"),
            vim.fn.expand("$HOME/fvm/versions"),
          },
        },
      },
      widget_guides = { enabled = true },
      dev_log = { enabled = true, open_cmd = "tabedit" },
    },
  },

  -- Prefer formatting through the FVM-backed dartls, with `dart format` as fallback.
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        dart = { "dart_format", lsp_format = "prefer" },
      },
    },
  },
}
