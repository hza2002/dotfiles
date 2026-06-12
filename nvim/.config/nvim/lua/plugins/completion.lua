-- Override LazyVim's default blink.cmp keymap so Tab/S-Tab cycle the menu.
-- Accept is still <CR> / <C-y>; other default-preset bindings (C-n/C-p, C-e,
-- C-space, scroll, signature) are preserved by the merge.
return {
  {
    "saghen/blink.cmp",
    opts = {
      keymap = {
        ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
      },
      cmdline = {
        keymap = {
          preset = "cmdline",
          ["<Down>"] = { "select_next", "fallback" },
          ["<Up>"] = { "select_prev", "fallback" },
        },
      },
    },
  },
}
