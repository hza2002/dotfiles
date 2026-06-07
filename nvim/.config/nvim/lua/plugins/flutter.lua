-- Dart/Flutter development with FVM-managed SDKs.
-- flutter-tools owns dartls; `fvm = true` makes it use <workspace>/.fvm/flutter_sdk.
return {
  {
    "nvim-flutter/flutter-tools.nvim",
    ft = "dart",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      fvm = true,
      lsp = {
        color = { enabled = true },
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

  -- Dart formatter routed through FVM (no global `dart` on PATH).
  {
    "stevearc/conform.nvim",
    opts = {
      formatters = {
        dart_format = {
          command = "fvm",
          args = { "dart", "format", "$FILENAME" },
        },
      },
    },
  },
}
