local tool = {}

tool.urlview = {
  default_picker = "telescope",
  default_action = "clipboard",
  default_register = "",
}

tool.neovim_project = {
  projects = { -- define project roots
    "~/projects/*",
    "~/.config/*",

    "~/repo/*",
    "~/repo/os/experiment/*",
    "~/repo/keyboard/zmk-config",
    "~/repo/AlgorithmAndDataStructures/tutorial*"
  },
  last_session_on_startup = false,
}

return tool
