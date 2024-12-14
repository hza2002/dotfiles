local tool = {}

tool.urlview = {
  default_picker = "telescope",
  default_action = "clipboard",
  default_register = "",
}

tool.neovim_project = {
  projects = { -- define project roots
    "~/.config/*",
  },
  last_session_on_startup = false,
}

return tool
