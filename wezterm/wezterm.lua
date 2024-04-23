local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Configuration
config.default_prog = { '/opt/homebrew/bin/fish', '-l' }

-- Appearance, colors, and fonts
local function scheme_for_appearance(appearance)
  if appearance:find 'Dark' then
    return 'Catppuccin Mocha'
  else
    return 'Catppuccin Latte'
  end
end

config.color_scheme = scheme_for_appearance(wezterm.gui.get_appearance())

config.font = wezterm.font {
  family = 'JetBrains Mono',
  weight = 'DemiBold',
}
config.font_size = 15.5

config.use_fancy_tab_bar = false
config.tab_max_width = 32

-- Mouse events
config.mouse_bindings = {
  -- Open URLs with CMD+Click
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CMD',
    action = wezterm.action.OpenLinkAtMouseCursor,
  }
}

-- Keybindings
config.keys = {
  -- Vertical pipe (|) -> horizontal split
  {
    key = '\\',
    mods = 'CMD|SHIFT',
    action = wezterm.action.SplitHorizontal {
      domain = 'CurrentPaneDomain'
    },
  },

  -- Underscore (_) -> vertical split
  {
    key = '-',
    mods = 'CMD|SHIFT',
    action = wezterm.action.SplitVertical {
      domain = 'CurrentPaneDomain'
    },
  },

  -- Rename current tab
  {
    key = 'E',
    mods = 'CMD|SHIFT',
    action = wezterm.action.PromptInputLine {
      description = 'Enter new name for tab',
      action = wezterm.action_callback(
        function(window, _, line)
          if line then
            window:active_tab():set_title(line)
          end
        end
      ),
    },
  },

  -- Move to a pane (prompt to which one)
  {
    key = "m",
    mods = "CMD",
    action = wezterm.action.PaneSelect
  },

  -- Use CMD + [h|j|k|l] to move between panes
  {
    key = "h",
    mods = "CMD",
    action = wezterm.action.ActivatePaneDirection('Left')
  },

  {
    key = "j",
    mods = "CMD",
    action = wezterm.action.ActivatePaneDirection('Down')
  },

  {
    key = "k",
    mods = "CMD",
    action = wezterm.action.ActivatePaneDirection('Up')
  },

  {
    key = "l",
    mods = "CMD",
    action = wezterm.action.ActivatePaneDirection('Right')
  },

  -- Use CMD+w to close the pane, CMD+SHIFT+w to close the tab
  {
    key = "w",
    mods = "CMD",
    action = wezterm.action.CloseCurrentPane { confirm = true }
  },

  {
    key = "w",
    mods = "CMD|SHIFT",
    action = wezterm.action.CloseCurrentTab { confirm = true }
  },
}

return config
