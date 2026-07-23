-- Dart/Flutter development with FVM-managed SDKs.
-- flutter-tools owns dartls; `fvm = true` makes it use <workspace>/.fvm/flutter_sdk.
local function dart_executable(_, ctx)
  local root = vim.fs.root(ctx.dirname, ".fvmrc")
  local executable = root and (root .. "/.fvm/flutter_sdk/bin/dart")
  return executable and vim.uv.fs_stat(executable) and executable or "dart"
end

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

  -- Use the project's FVM SDK directly to avoid the slow FVM CLI startup.
  {
    "stevearc/conform.nvim",
    opts = {
      formatters = {
        dart_format = {
          command = dart_executable,
        },
      },
    },
  },
}
