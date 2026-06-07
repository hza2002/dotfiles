local editor = {}

editor.spectre = {
  is_block_ui_break = true,
  highlight = {
    ui = "String",
    search = "@comment.warning",
    replace = "@comment.error"
  },
}

editor.smartyank = {
  highlight = {
    enabled = false, -- highlight yanked text
  },
}

return editor
