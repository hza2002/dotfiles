-- Code / LSP-adjacent plugins not covered by LazyVim defaults.

return {
  -- Better folds with a custom fold-text handler
  {
    "kevinhwang91/nvim-ufo",
    dependencies = { "kevinhwang91/promise-async" },
    event = "BufReadPost",
    -- stylua: ignore start
    keys = {
      { "zp", function() require("ufo").peekFoldedLinesUnderCursor() end, desc = "Preview folded lines" },
      { "zR", function() require("ufo").openAllFolds() end, desc = "Open all folds" },
      { "zM", function() require("ufo").closeAllFolds() end, desc = "Close all folds" },
      { "zr", function() require("ufo").openFoldsExceptKinds() end, desc = "Open folds except configured kinds" },
      { "zm", function() require("ufo").closeFoldsWith() end, desc = "Fold to level (count, default 0)" },
    },
    -- stylua: ignore end
    opts = {
      preview = {
        mappings = {
          scrollB = "<C-b>",
          scrollF = "<C-f>",
          scrollU = "<C-u>",
          scrollD = "<C-d>",
        },
      },
      provider_selector = function()
        return { "treesitter", "indent" }
      end,
      fold_virt_text_handler = function(virtText, lnum, endLnum, width, truncate)
        local newVirtText = {}
        local suffix = (" 󰁂 %d "):format(endLnum - lnum)
        local sufWidth = vim.fn.strdisplaywidth(suffix)
        local targetWidth = width - sufWidth
        local curWidth = 0
        for _, chunk in ipairs(virtText) do
          local chunkText = chunk[1]
          local chunkWidth = vim.fn.strdisplaywidth(chunkText)
          if targetWidth > curWidth + chunkWidth then
            table.insert(newVirtText, chunk)
          else
            chunkText = truncate(chunkText, targetWidth - curWidth)
            local hlGroup = chunk[2]
            table.insert(newVirtText, { chunkText, hlGroup })
            chunkWidth = vim.fn.strdisplaywidth(chunkText)
            -- str width returned from truncate() may be less than the 2nd arg, pad it
            if curWidth + chunkWidth < targetWidth then
              suffix = suffix .. (" "):rep(targetWidth - curWidth - chunkWidth)
            end
            break
          end
          curWidth = curWidth + chunkWidth
        end
        table.insert(newVirtText, { suffix, "MoreMsg" })
        return newVirtText
      end,
    },
  },

  -- Preview LSP locations in a floating window
  {
    "rmagatti/goto-preview",
    event = "LspAttach",
    opts = {
      width = 120,
      height = 25,
      default_mappings = false,
      debug = false,
      opacity = nil,
      resizing_mappings = false,
    },
    config = function(_, opts)
      require("goto-preview").setup(opts)
      -- Preview windows share real buffers; keep q window-aware without buffer-local maps.
      vim.keymap.set("n", "q", function()
        if vim.w["is-goto-preview-window"] == 1 and vim.fn.reg_recording() == "" then
          return "<cmd>close<cr>"
        end
        return "q"
      end, { expr = true, desc = "Close preview or record macro" })
    end,
    -- stylua: ignore start
    keys = {
      { "gpd", function() require("goto-preview").goto_preview_definition() end, desc = "Preview definition" },
      { "gpr", function() require("goto-preview").goto_preview_references() end, desc = "Preview references" },
      { "gpI", function() require("goto-preview").goto_preview_implementation() end, desc = "Preview implementation" },
      { "gpy", function() require("goto-preview").goto_preview_type_definition() end, desc = "Preview type definition" },
      { "gpD", function() require("goto-preview").goto_preview_declaration() end, desc = "Preview declaration" },
      { "gP", function() require("goto-preview").close_all_win() end, desc = "Close preview windows" },
    },
    -- stylua: ignore end
  },
}
