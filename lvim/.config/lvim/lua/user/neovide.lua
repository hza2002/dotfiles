-- Neovide
-----------------------DISPLAY--------------------------
vim.g.neovide_scale_factor                   = 1.0 -- Without changing the whole font definition. Useful for presentations.
vim.g.neovide_transparency                   = 0.8
vim.g.neovide_hide_mouse_when_typing         = true
vim.g.neovide_confirm_quit                   = true
vim.g.neovide_fullscreen                     = false
-- Padding between the window border and the actual Neovim
vim.g.neovide_padding_top                    = 0
vim.g.neovide_padding_bottom                 = 0
vim.g.neovide_padding_right                  = 0
vim.g.neovide_padding_left                   = 0
-- Floating Blur Amount: blur radius on the respective axis for floating windows.
vim.g.neovide_floating_blur_amount_x         = 2.0
vim.g.neovide_floating_blur_amount_y         = 2.0

vim.g.neovide_scroll_animation_length        = 0.3  -- How long the scroll animation takes to complete, measured in seconds.
-----------------------Cursor Settings------------------
vim.g.neovide_cursor_antialiasing            = true -- Antialiasing of the cursor quad. Disabling may fix some cursor visual issues.
vim.g.neovide_cursor_animate_in_insert_mode  = true
vim.g.neovide_cursor_animate_command_line    = true
vim.g.neovide_cursor_animation_length        = 0.13      -- The cursor to complete it's animation in seconds. Set to 0 to disable.
vim.g.neovide_cursor_trail_size              = 0.8       -- How much the trail of the cursor lags behind the front edge.
vim.g.neovide_cursor_unfocused_outline_width = 0.125     -- Specify cursor outline width in ems.
-----------------------Particle Settings----------------
vim.g.neovide_cursor_vfx_mode                = "railgun" -- "railgun", "torpedo", "pixiedust"
vim.g.neovide_cursor_vfx_particle_phase      = 1.5       -- (Only for the railgun vfx mode.) The mass movement of particles, or how individual each one acts.
vim.g.neovide_cursor_vfx_particle_curl       = 1.0       -- (Only for the railgun vfx mode.) The velocity rotation speed of particles.
vim.g.neovide_cursor_vfx_opacity             = 200.0     -- The transparency of the generated particles.
vim.g.neovide_cursor_vfx_particle_lifetime   = 1.2       -- The amount of time the generated particles should survive.
vim.g.neovide_cursor_vfx_particle_density    = 7.0       -- The number of generated particles.
vim.g.neovide_cursor_vfx_particle_speed      = 10.0      -- The speed of particle movement.
-----------------------MacOs----------------------------
vim.g.neovide_input_macos_alt_is_meta        = true

function Neovide()
  vim.defer_fn(function()
    vim.cmd([[LvimReload]])
    vim.defer_fn(function()
      vim.cmd([[lua require('lvim.core.lualine').setup()]])
      vim.defer_fn(function()
        vim.cmd([[lua require("noice").cmd("dismiss")]])
        vim.defer_fn(function()
          vim.cmd([[normal gg]])
        end, 0)
      end, 0)
    end, 0)
  end, 0)
end

lvim.builtin.which_key.mappings.L.N = { "<cmd>lua Neovide()<cr>", "Init Neovide", { noremap = true, silent = true } }
