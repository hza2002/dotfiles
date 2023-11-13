local editor = {}

editor.spectre = {
  is_block_ui_break = true,
  highlight = {
    ui = "String",
    search = "@text.warning",
    replace = "@text.danger"
  },
}

editor.smartyank = {
  highlight = {
    enabled = false, -- highlight yanked text
  },
}

return editor
