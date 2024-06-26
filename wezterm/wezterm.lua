local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Appearance, colors, and fonts

---Return the suitable argument depending on the appearance
---@param arg { light: any, dark: any } light and dark alternatives
---@return any
local function depending_on_appearance(arg)
  local appearance = wezterm.gui.get_appearance()
  if appearance:find 'Dark' then
    return arg.dark
  else
    return arg.light
  end
end

config.color_scheme = depending_on_appearance {
  light = 'Catppuccin Latte',
  dark = 'Catppuccin Mocha',
}

config.use_fancy_tab_bar = false
config.tab_max_width = 32
config.colors = {
  tab_bar = {
    active_tab = depending_on_appearance {
      light = { fg_color = '#f8f8f2', bg_color = '#209fb5' },
      dark = { fg_color = '#292c3c', bg_color = '#74c7ec' },
    }
  }
}

config.font_size = 14
config.font = wezterm.font {
  family = 'JetBrains Mono',
  weight = 'DemiBold',
}


-- Behavior
config.native_macos_fullscreen_mode = true
config.pane_focus_follows_mouse = true

config.default_prog = { '/opt/homebrew/bin/fish', '-l' }
config.launch_menu = {
  {
    label = 'fish',
    args = { '/opt/homebrew/bin/fish', '-l' },
  },
  {
    label = 'bash',
    args = { '/bin/bash', '-l' },
  }
}


-- Mouse events
config.mouse_bindings = {
  -- Open URLs with CMD+Click
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CMD',
    action = wezterm.action.OpenLinkAtMouseCursor,
  }
}

--- Bind a movement key to a direction
---
--- If the current pane is running nvim, send the key to it using CTRL
--- as the modifier instead. If not, move the next pane in the given
--- direction.
--- @param key string the key to send
--- @param direction string the direction to move the pane
local function bind_movement(key, direction)
  local function basename(str)
    local name = string.gsub(str, "(.*/)(.*)", "%2")
    return name
  end

  return function(win, pane)
    local name = basename(pane:get_foreground_process_name())
    win:toast_notification('wezterm', name, nil, 4000)
    if name == 'nvim' then
      win:perform_action(
        wezterm.action.SendKey{ key = key, mods = 'CTRL' },
        pane
      )
    else
      win:perform_action(
        wezterm.action.ActivatePaneDirection(direction),
        pane
      )
    end
  end
end

-- Keybindings
config.keys = {
  -- Show tab navigator
  {
    key = 'p',
    mods = 'CMD',
    action = wezterm.action.ShowTabNavigator
  },
  -- Show launcher menu
  {
    key = 'P',
    mods = 'CMD|SHIFT',
    action = wezterm.action.ShowLauncher
  },

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
    mods = "CMD", key = "m",
    action = wezterm.action.PaneSelect
  },

  -- Use CMD + [h|j|k|l] to move between panes
  {
    key = "h",
    mods = "CMD",
    action = wezterm.action_callback(bind_movement('h', 'Left'))
  },

  {
    key = "j",
    mods = "CMD",
    action = wezterm.action_callback(bind_movement('j', 'Down'))
  },

  {
    key = "k",
    mods = "CMD",
    action = wezterm.action_callback(bind_movement('k', 'Up'))
  },

  {
    key = "l",
    mods = "CMD",
    action = wezterm.action_callback(bind_movement('l', 'Right'))
  },

  -- Move to another pane (next or previous)
  {
    key = "[",
    mods = "CMD",
    action = wezterm.action.ActivatePaneDirection('Prev')
  },

  {
    key = "]",
    mods = "CMD",
    action = wezterm.action.ActivatePaneDirection('Next')
  },

  -- Move to another tab (next or previous)
  {
    key = "{",
    mods = "CMD|SHIFT",
    action = wezterm.action.ActivateTabRelative(-1)
  },

  {
    key = "}",
    mods = "CMD|SHIFT",
    action = wezterm.action.ActivateTabRelative(1)
  },

  -- Use CMD+Shift+S t swap the active pane and another one
  {
    key = "s",
    mods = "CMD|SHIFT",
    action=wezterm.action{
      PaneSelect = { mode = "SwapWithActiveKeepFocus" }
    }
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

  -- Use CMD+z to enter zoom state
  {
    key = 'z',
    mods = 'CMD',
    action = wezterm.action.TogglePaneZoomState,
  },

  -- Launch commands in a new pane
  {
    key = 'g',
    mods = 'CMD',
    action = wezterm.action.SplitHorizontal {
      -- `lg` is a custom alias for `lazygit`
      args = { os.getenv 'SHELL', '-c', 'lg' },
    }
  },
  {
    key = 'r',
    mods = 'CTRL',
    -- action = wezterm.action.SplitHorizontal {
    --   args = { os.getenv 'SHELL', '-c', '_atuin_search' },
    -- }
    action = wezterm.action.SendKey {key = 'r', mods = 'CTRL'}
  }
}

local smart_splits = wezterm.plugin.require(
  'https://github.com/mrjones2014/smart-splits.nvim'
)

smart_splits.apply_to_config(config, {
  direction_keys = { 'h', 'j', 'k', 'l' },
  modifiers = {
    move = 'CTRL',
    resize = 'META',
  },
})

return config
