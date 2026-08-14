#!/bin/sh
#
# Publish the status bar's STRUCTURAL colours for the active catppuccin flavour.
#
# WHY THIS EXISTS
#
# The bar was ANSI-only so it would follow the terminal between latte and mocha
# for free. That works for SEMANTIC colour — red means red in both flavours —
# but ANSI cannot express a SURFACE. It has sixteen foreground colours and no
# "one step off the background" shade, and the slots that look like one sit at
# opposite ends of the ramp in the two flavours:
#
#              canvas     colour0    colour7     colour8
#   latte      #eff1f5    #5c5f77    #acb0be     #6c6f85
#   mocha      #1e1e2e    #45475a    #a6adc8     #585b70
#
# In latte the surfaces are the HIGH indices; in mocha they are the LOW ones.
# So no single index reads as a surface in both, and a filled pill needs real
# hex. Measured, for the values chosen below:
#
#              pill vs canvas   colour8 on pill
#   latte          1.37             3.20        <- ANSI dim survives here
#   mocha          1.30             1.88        <- but collapses here
#
# which is why @bar_dim exists too: once the pill is filled, the dim text has
# to come from the palette as well. The split ends up clean:
#
#   SEMANTIC   glyph colours (red/green/yellow/blue) stay ANSI and keep
#              tracking the terminal with no help from this script.
#   STRUCTURAL the pill surface, the dim text on it, and the text colour that
#              #[default] resolves to inside a pill all come from here.
#
# DETECTION rides on ghostty's `theme = light:...,dark:...`, which follows the
# macOS system appearance — so the system is the single source of truth and we
# never have to ask the terminal. On anything else (claw) there is no such
# setting, and mocha is the only sane default for an ssh session.
#
# Set @theme_flavour to latte or mocha to pin it and skip detection entirely.

set -u

# catppuccin, https://catppuccin.com/palette
#            surface0     subtext0     text
LATTE_PILL="#ccd0da"; LATTE_DIM="#6c6f85"; LATTE_TEXT="#4c4f69"
MOCHA_PILL="#313244"; MOCHA_DIM="#a6adc8"; MOCHA_TEXT="#cdd6f4"
#            base         teal         claude orange
LATTE_CANVAS="#eff1f5"; LATTE_TEAL="#179299"; LATTE_ORANGE="#fe640b"
MOCHA_CANVAS="#1e1e2e"; MOCHA_TEAL="#94e2d5"; MOCHA_ORANGE="#fab387"

# surface0 rather than surface1: surface1 fills harder (1.61 against the canvas
# in latte, versus 1.37) but drags every glyph down with it — latte yellow,
# already the weakest at 2.31 on the bare canvas, falls to 1.44 on surface1
# against 1.70 on surface0. The blocked marker is the one glyph that must never
# be missed, and the pill shape now carries the separation that the darker
# surface was being asked to carry, so the softer shade wins.
#
# DIM IS SUBTEXT0, NOT AN OVERLAY SHADE. Catppuccin's style guide assigns
# overlay to "subtle text elements" and subtext to "sub-headlines and labels".
# A session name is a label. Using overlay2 for it read as washed out — 2.56
# against the pill in latte, where subtext0 gives 3.20.
#
# TEAL ARRIVES AS A FILL, NEVER AS TEXT. Teal reads 2.43 on the pill in latte,
# and even on the bare canvas it only reaches 3.31, because every latte accent
# except blue, red and mauve sits under 3.0 — they are tuned for text on base,
# not on a surface. Inverted, the same teal is a 3.31 chip carrying canvas text,
# and 11.01 in mocha.
#
# THE ORANGE IS CATPPUCCIN'S PEACH IN BOTH FLAVOURS, and stays that way. Canvas
# text on latte peach measures 2.64, which is low, and a darkened #d24700 would
# reach 4.00. Diego judged the palette peach readable enough and preferred the
# vibrancy, so vibrancy wins: the segment is short, bold, and the only orange
# thing on the bar, so recognition does not rest on contrast alone. Mocha reads
# 9.27 and never had the problem.

OPT_FLAVOUR="@theme_flavour"   # latte | mocha | (unset = auto)
OPT_ACTIVE="@bar_flavour"      # what is currently published, to skip no-op work
OPT_PILL="@pill_bg"
OPT_DIM="@bar_dim"
OPT_TEXT="@bar_text"
OPT_CANVAS="@bar_canvas"
OPT_TEAL="@bar_teal"
OPT_ORANGE="@bar_orange"

# Separator and marker glyphs, published here because this is the one script
# that always runs before the bar draws. They are octal UTF-8 escapes rather
# than literal characters: private-use codepoints do not survive every editor
# and pipeline, and an earlier round silently wrote empty strings for the pill
# caps. An escape either produces the right bytes or fails loudly.
#
# Names come from the font's own cmap, not a cheat sheet:
#   U+E0BB ple-forwardslash_separator      the thin "/"
#   U+E0BC ple-upper_left_triangle         solid, ink in the UPPER-LEFT half
#   U+E0BA ple-lower_right_triangle        solid, ink in the LOWER-RIGHT half
#   U+E0BF ple-backslash_separator_redundant   the OTHER slant, do not use
#
# E0BC and E0BA are the two halves of one "/" diagonal, so they draw the SAME
# picture with foreground and background swapped. That equivalence is the point:
# it lets the colouring pick which half is ink. Nerd-fonts draws both seven
# units past the cell, and only the INK overshoots, so the ink should always be
# the lighter of the two colours — a pill-grey fringe against the canvas is
# invisible where a teal one is a spike.
SEP_THIN=$(printf '\356\202\273')
SEP_SOLID_UL=$(printf '\356\202\274')
SEP_SOLID_LR=$(printf '\356\202\272')

# Font Awesome v4 range, all four verified present in
# JetBrainsMonoNerdFont-Regular.ttf. The v5 additions are NOT: robot U+F544 and
# brain U+F5DC both miss, because nerd-fonts remapped them. The asterisks Claude
# Code uses for its own spinner (U+2731, U+273B, U+273D) miss as well, so they
# would fall to macOS substitution at an unpredictable cell width.
GLYPH_BLOCKED=$(printf '\357\201\231')   # U+F059 question-circle
GLYPH_ERROR=$(printf '\357\201\261')     # U+F071 exclamation-triangle
GLYPH_FINISHED=$(printf '\357\201\230')  # U+F058 check-circle
# fa-spinner rather than fa-circle-notch: both are rings, but the spinner's
# tapered segments are the shape people already read as "in progress". It does
# NOT animate. tmux redraws the bar on status-interval, which is 15 seconds
# here, and cycling frames would mean dropping that to about one second — the
# modeline forks a #() on every redraw, so the bar would run a shell fifteen
# times as often to spin a glyph.
GLYPH_WORKING=$(printf '\357\204\220')   # U+F110 spinner
GLYPH_IDLE=$(printf '\357\201\251')      # U+F069 asterisk
# fa-maximize, the four solid diagonal arrows. Font Awesome publishes it at
# f31e, and that codepoint is USELESS here: nerd-fonts reassigned f31e to
# linux-archlabs and moved fa-maximize to f06f. Reading the codepoint off the
# Font Awesome site is how the wrong glyph keeps arriving — fa-expand f065
# draws thin corner brackets and fa-window_maximize f2d0 draws a window frame.
GLYPH_EXPAND=$(printf '\357\201\257')    # U+F06F fa-maximize

# The workspace indicator. fa-user_circle measures 923x924, exactly matching the
# agent markers; fa-briefcase is 923x865, a little shorter, which is the shape
# of a briefcase rather than a defect.
GLYPH_PERSONAL=$(printf '\357\212\275')  # U+F2BD fa-user_circle
GLYPH_WORK=$(printf '\357\202\261')      # U+F0B1 fa-briefcase

command -v tmux >/dev/null 2>&1 || exit 0

flavour="$(tmux show -gv "$OPT_FLAVOUR" 2>/dev/null)"
if [ "$flavour" != "latte" ] && [ "$flavour" != "mocha" ]; then
	case "$(uname -s)" in
		Darwin)
			# The key is absent on light, which makes `defaults read` fail. That
			# non-zero exit IS the signal; there is no "Light" value to match.
			if defaults read -g AppleInterfaceStyle >/dev/null 2>&1; then
				flavour=mocha
			else
				flavour=latte
			fi
			;;
		*) flavour=mocha ;;
	esac
fi

case "$flavour" in
	latte)
		pill="$LATTE_PILL"; dim="$LATTE_DIM"; text="$LATTE_TEXT"
		canvas="$LATTE_CANVAS"; teal="$LATTE_TEAL"; orange="$LATTE_ORANGE" ;;
	*)
		pill="$MOCHA_PILL"; dim="$MOCHA_DIM"; text="$MOCHA_TEXT"
		canvas="$MOCHA_CANVAS"; teal="$MOCHA_TEAL"; orange="$MOCHA_ORANGE" ;;
esac

# Skip the writes if the flavour has not moved. This runs on every focus-in, and
# a redundant set-plus-redraw on every alt-tab is exactly the kind of flicker
# that makes people turn a feature off. The tier still gets rebuilt below —
# attaching a client needs that whether or not the theme changed.
#
# The guard checks the published values are actually PRESENT, not just that the
# flavour matches. Keying on the flavour alone meant that renaming an option
# here left a live server holding the old names forever: sourcing the config
# republished nothing, because latte was still latte. Reloading a config should
# never be a no-op that leaves the previous shape in place.
# The guard compares a SIGNATURE of everything published, not the flavour and
# not a presence check. Both weaker tests failed in turn: keying on the flavour
# alone left a live server holding renamed options forever, and checking that
# the options merely exist let an edited colour VALUE slip through, because
# latte was still latte and every option was still set. A signature catches a
# rename, a new option, and a changed hex with one comparison.
# THE SIGNATURE MUST LIST EVERY PUBLISHED VALUE. Each time it has covered only
# some of them, an edit to one of the rest reloaded into nothing: first the
# flavour alone survived a rename, then a presence check survived a changed
# colour, then this list omitted the working glyph and survived changing it.
# A value that this script writes and this line does not mention cannot reach a
# running server.
sig="$flavour:$pill:$dim:$text:$canvas:$teal:$orange"
sig="$sig:$SEP_THIN$SEP_SOLID_UL$SEP_SOLID_LR"
sig="$sig:$GLYPH_BLOCKED$GLYPH_ERROR$GLYPH_FINISHED$GLYPH_WORKING$GLYPH_IDLE$GLYPH_EXPAND"
sig="$sig:$GLYPH_PERSONAL$GLYPH_WORK"

if [ "$(tmux show -gv "@bar_sig" 2>/dev/null)" != "$sig" ]; then
	tmux set -g "$OPT_PILL"   "$pill"
	tmux set -g "$OPT_DIM"    "$dim"
	tmux set -g "$OPT_TEXT"   "$text"
	tmux set -g "$OPT_CANVAS" "$canvas"
	tmux set -g "$OPT_TEAL"   "$teal"
	tmux set -g "$OPT_ORANGE" "$orange"
	tmux set -g "$OPT_ACTIVE" "$flavour"
	tmux set -g "@bar_sig"    "$sig"

	tmux set -g @sep_thin       "$SEP_THIN"
	tmux set -g @sep_solid_ul   "$SEP_SOLID_UL"
	tmux set -g @sep_solid_lr   "$SEP_SOLID_LR"
	tmux set -g @glyph_blocked_ch  "$GLYPH_BLOCKED"
	tmux set -g @glyph_error_ch    "$GLYPH_ERROR"
	tmux set -g @glyph_finished_ch "$GLYPH_FINISHED"
	tmux set -g @glyph_working_ch  "$GLYPH_WORKING"
	tmux set -g @glyph_idle_ch     "$GLYPH_IDLE"
	tmux set -g @glyph_expand_ch   "$GLYPH_EXPAND"
	tmux set -g @glyph_personal_ch "$GLYPH_PERSONAL"
	tmux set -g @glyph_work_ch     "$GLYPH_WORK"

	# The BAR itself is transparent — only the pills are filled. The gaps
	# between them are canvas, and that emptiness is what separates the three
	# groups; a fill behind everything would put the groups back on one slab
	# and undo the parsing win.
	#
	# status-style takes literal values, NOT a format: `set -g status-style
	# "bg=#{E:@pill_bg}"` silently keeps the default, the same trap that ate
	# history-limit. Anything read through #{E:} may reference the options;
	# anything tmux parses directly has to be written out here.
	tmux set -g status-style  "bg=default,fg=$dim"
	tmux set -g message-style "bg=$pill,fg=colour4"
fi

# Always: the pills are assembled from these colours and the client width.
exec "$(dirname "$0")/status-tier.sh"
