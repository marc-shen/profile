-- wezterm.lua - WezTerm Terminal Emulator Configuration

local wezterm = require 'wezterm'
local act = wezterm.action

local config = wezterm.config_builder()

local mod = {}
mod.SUPER = 'SUPER'
mod.SUPER_REV = 'SUPER|CTRL'

-- Note: These are global variables and not part of the config table
initial_cols = 120
initial_rows = 60

-- Font settings
config.font = wezterm.font_with_fallback {
  -- 'Protomolecule',
  'MesloLGS NF',
  'Songti SC',
}
config.font_size = 16.0

config.window_frame = {
  font_size = 14.0,  -- tab栏和标题栏字体大小
}

config.enable_scroll_bar = true

config.window_background_opacity = 0.75
config.macos_window_background_blur = 100

wezterm.on("gui-startup", function(cmd)
  local screen = wezterm.gui.screens().active
  -- local ratio = 0.4
  -- local width, height = screen.width * ratio, screen.height * ratio
  local tab, pane, window = wezterm.mux.spawn_window {
    position = {
      x = (screen.width) / 2,
      y = (screen.height) / 2,
      origin = 'ActiveScreen' }
  }
  -- window:gui_window():set_inner_size(width, height)
end)

config.color_scheme = 'Monokai (base16)'
-- config.color_scheme = 'Monokai Pro' 
config.keys = {
  {
    key = 's',
    mods = mod.SUPER_REV,
    action = wezterm.action.QuickSelect,
  },
  {
    key = [[\]],
    mods = mod.SUPER,
    action = act.SplitVertical({ domain = 'CurrentPaneDomain' }),
   },
  {
    key = [[\]],
    mods = mod.SUPER_REV,
    action = act.SplitHorizontal({ domain = 'CurrentPaneDomain' }),
  },
  { key = 'Enter', mods = mod.SUPER_REV,     action = act.TogglePaneZoomState },
  { key = 'w',     mods = mod.SUPER,     action = act.CloseCurrentPane({ confirm = true }) },
  { key = 'k',     mods = mod.SUPER_REV, action = act.ActivatePaneDirection('Up') },
  { key = 'j',     mods = mod.SUPER_REV, action = act.ActivatePaneDirection('Down') },
  { key = 'h',     mods = mod.SUPER_REV, action = act.ActivatePaneDirection('Left') },
  { key = 'l',     mods = mod.SUPER_REV, action = act.ActivatePaneDirection('Right') },
  {
    key = 'p',
    mods = mod.SUPER_REV,
    action = act.PaneSelect({ alphabet = '1234567890', mode = 'SwapWithActiveKeepFocus' }),
  },
  {
    key = 'F12',
    -- mods = 'SHIFT|CTRL',
    action = wezterm.action.ToggleFullScreen,
  },
}

return config
