local ui = {}

ui.catppuccin = {
  flavour      = "macchiato", -- latte, frappe, macchiato, mocha
  dim_inactive = {
    enabled    = true,        -- dims the background color of inactive window
    shade      = "dark",
    percentage = 0.25,        -- percentage of the shade to apply to the inactive window
  },
  integrations = {
    leap            = true,
    lsp_trouble     = true,
    mason           = true,
    noice           = true,
    notify          = true,
    symbols_outline = true,
    which_key       = true,
    window_picker   = true,
  },
}

ui.gruvbox = {
  -- transparent_mode = true,
}

ui.symbols_outline = {
  symbols = {
    File = { icon = "", hl = "@text.uri" },
    Module = { icon = "󱒌", hl = "@namespace" },
    Namespace = { icon = "", hl = "@namespace" },
    Field = { icon = "", hl = "@field" },
    Array = { icon = "", hl = "@constant" },
    Event = { icon = "", hl = "@type" },
    Component = { icon = "󰡀", hl = "@function" },
    Fragment = { icon = "", hl = "@constant" },
  },
}

ui.numb = {
  show_numbers = true,         -- Enable 'number' for the window while peeking
  show_cursorline = true,      -- Enable 'cursorline' for the window while peeking
  hide_relativenumbers = true, -- Enable turning off 'relativenumber' for the window while peeking
  number_only = false,         -- Peek only when the command is only a number instead of when it starts with a number
  centered_peeking = true,     -- Peeked line will be centered relative to window
}

ui.colorizer = {
  "css", "scss", "html", "javascript",
}

ui.rnvimr = function()
  vim.g.rnvimr_draw_border = 1
  vim.g.rnvimr_pick_enable = 1
  vim.g.rnvimr_bw_enable = 1
end

ui.focus = function()
  -- Disabling Focus
  local ignore_buftypes = { 'nofile', 'prompt', 'popup', 'terminal' }
  local ignore_filetypes = { 'NvimTree', 'toggleterm' }

  local augroup =
      vim.api.nvim_create_augroup('FocusDisable', { clear = true })

  vim.api.nvim_create_autocmd('WinEnter', {
    group = augroup,
    callback = function(_)
      if vim.tbl_contains(ignore_buftypes, vim.bo.buftype)
      then
        vim.w.focus_disable = true
      else
        vim.w.focus_disable = false
      end
    end,
    desc = 'Disable focus autoresize for BufType',
  })

  vim.api.nvim_create_autocmd('FileType', {
    group = augroup,
    callback = function(_)
      if vim.tbl_contains(ignore_filetypes, vim.bo.filetype) then
        vim.b.focus_disable = true
      else
        vim.b.focus_disable = false
      end
    end,
    desc = 'Disable focus autoresize for FileType',
  })

  require("focus").setup({
    autoresize = {
      enable = true,        -- Enable or disable auto-resizing of splits
      width = 0,            -- Force width for the focused window
      height = 0,           -- Force height for the focused window
      minwidth = 10,        -- Force minimum width for the unfocused window
      minheight = 10,       -- Force minimum height for the unfocused window
      height_quickfix = 10, -- Set the height of quickfix panel
    },
    ui = {
      hybridnumber = true, -- Display hybrid line numbers in the focussed window only
    },
  })
end

ui.tmux = {
  resize = {
    enable_default_keybindings = false,
  }
}

ui.noice = {
  cmdline = { -- only config for expired icons
    format = {
      cmdline = { pattern = "^:", icon = "", lang = "vim" },
      search_down = { kind = "search", pattern = "^/", icon = " ", lang = "regex" },
      search_up = { kind = "search", pattern = "^%?", icon = " ", lang = "regex" },
      filter = { pattern = "^:%s*!", icon = "$", lang = "bash" },
      lua = { pattern = { "^:%s*lua%s+", "^:%s*lua%s*=%s*", "^:%s*=%s*" }, icon = "", lang = "lua" },
      help = { pattern = "^:%s*he?l?p?%s+", icon = "󰋖" },
    },
  },
  lsp = {
    override = {
      ["vim.lsp.util.convert_input_to_markdown_lines"] = true, -- override the default lsp markdown formatter with Noice
      ["vim.lsp.util.stylize_markdown"] = true,                -- override the lsp markdown formatter with Noice
      ["cmp.entry.get_documentation"] = true,                  -- override cmp documentation with Noice (needs the other options to work)
    },
  },
  presets = {
    command_palette = true,       -- position the cmdline and popupmenu together
    long_message_to_split = true, -- long messages will be sent to a split
    lsp_doc_border = true,        -- add a border to hover docs and signature help
  },
}

ui.yazi = {
  open_for_directories = false, -- enable this if you want to open yazi instead of netrw.
}

return ui
