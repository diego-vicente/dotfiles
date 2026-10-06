#!/usr/bin/env bash
# Apply the macOS preferences of the old Mac. Run it apart from genesis.sh,
# when you want these settings, and log out afterwards so that every app
# reads them.
#
# Each value was read from the old Mac with `defaults read` on 2026-10-06.
# Only keys that differ from the macOS default, or that matter, are here. To
# find the key behind another System Settings change, run `defaults read`
# before and after the change and compare the two outputs.
set -euo pipefail

# Dock: hide it, no recent apps, and keep Spaces in a fixed order
readonly DOCK_TILE_SIZE=58
readonly HOT_CORNER_NONE=1
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock tilesize -int "$DOCK_TILE_SIZE"
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock mru-spaces -bool false
defaults write com.apple.dock mineffect -string scale
defaults write com.apple.dock expose-group-apps -bool true
# The old Mac had no action on the bottom-right corner, not the Quick Note default
defaults write com.apple.dock wvous-br-corner -int "$HOT_CORNER_NONE"

# Keyboard: fast key repeat, and the Fn key opens Emoji & Symbols
readonly KEY_REPEAT=5
readonly INITIAL_KEY_REPEAT=30
readonly FN_KEY_SHOW_EMOJI=2
defaults write NSGlobalDomain KeyRepeat -int "$KEY_REPEAT"
defaults write NSGlobalDomain InitialKeyRepeat -int "$INITIAL_KEY_REPEAT"
defaults write com.apple.HIToolbox AppleFnUsageType -int "$FN_KEY_SHOW_EMOJI"

# Appearance and region: light and dark follow the time of day, Spanish locale,
# metric units, 24-hour clock, and the week starts on Monday
readonly MONDAY=2
defaults write NSGlobalDomain AppleInterfaceStyleSwitchesAutomatically -bool true
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write NSGlobalDomain AppleLanguages -array "es-ES" "en-US"
defaults write NSGlobalDomain AppleLocale -string "es_ES"
defaults write NSGlobalDomain AppleMeasurementUnits -string "Centimeters"
defaults write NSGlobalDomain AppleTemperatureUnit -string "Celsius"
defaults write NSGlobalDomain AppleFirstWeekday -dict gregorian -int "$MONDAY"
defaults write NSGlobalDomain AppleICUForce24HourTime -bool true
defaults write com.apple.menuextra.clock Show24Hour -bool true
defaults write com.apple.menuextra.clock ShowSeconds -bool false

# Finder: list view, path and status bars, search the current folder, new
# windows open in the home folder, and empty the Trash after 30 days
readonly FINDER_LIST_VIEW="Nlsv"
readonly SEARCH_CURRENT_FOLDER="SCcf"
readonly NEW_WINDOW_HOME="PfHm"
defaults write com.apple.finder FXPreferredViewStyle -string "$FINDER_LIST_VIEW"
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder FXDefaultSearchScope -string "$SEARCH_CURRENT_FOLDER"
defaults write com.apple.finder NewWindowTarget -string "$NEW_WINDOW_HOME"
defaults write com.apple.finder NewWindowTargetPath -string "file://$HOME/"
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool false
defaults write com.apple.finder FXRemoveOldTrashItems -bool true

# Trackpad: tap to click and two-finger right click. The second domain covers
# a Bluetooth trackpad.
for trackpad_domain in com.apple.AppleMultitouchTrackpad com.apple.driver.AppleBluetoothMultitouch.trackpad; do
  defaults write "$trackpad_domain" Clicking -bool true
  defaults write "$trackpad_domain" TrackpadRightClick -bool true
  defaults write "$trackpad_domain" TrackpadThreeFingerDrag -bool false
done

# Window manager: no Stage Manager and no margins between tiled windows
defaults write com.apple.WindowManager GloballyEnabled -bool false
defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false

# Activity Monitor: show every process
readonly ALL_PROCESSES=100
defaults write com.apple.ActivityMonitor ShowCategory -int "$ALL_PROCESSES"

# Restart the processes that cache these preferences
for process in Dock Finder SystemUIServer; do
  killall "$process" >/dev/null 2>&1 || true
done
echo "Done. Log out and back in so that every app reads the new values."
