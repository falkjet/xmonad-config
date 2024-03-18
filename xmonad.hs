import Control.Monad (join)
import qualified Data.Map as M
import Data.Monoid
import System.Exit
import System.FilePath
import Text.Printf (printf)
import XMonad
import XMonad.Hooks.EwmhDesktops (ewmh, setEwmhActivateHook)
import XMonad.Hooks.ManageDocks (AvoidStruts, avoidStruts, docks)
import XMonad.Hooks.ManageHelpers (doCenterFloat)
import XMonad.Hooks.UrgencyHook
import XMonad.Layout.Decoration
import XMonad.Layout.NoBorders (WithBorder, noBorders)
import XMonad.Layout.Simplest
import XMonad.Layout.Spacing
import XMonad.Layout.Tabbed (TabbedDecoration, tabbed)
import qualified XMonad.Layout.Tabbed as Tabbed
import XMonad.Layout.ToggleLayouts
import qualified XMonad.StackSet as W
import XMonad.Util.EZConfig (mkKeymap)
import XMonad.Util.Hacks (javaHack, windowedFullscreenFixEventHook)
import XMonad.Util.SpawnOnce (spawnOnce)

myWorkspaces :: [String]
myWorkspaces =
  [ "\xf121 ",
    "{}",
    "\x000f0361",
    "\x000f0dc8",
    "\x000f075a",
    "\xf11b",
    "\xf120",
    "\xebc8",
    "\x000f03bc",
    "\x000f0f7d"
  ]

unmuteSink :: X ()
unmuteSink = spawn "pactl set-sink-mute @DEFAULT_SINK@ false"

toggleSinkMute :: X ()
toggleSinkMute = spawn "pactl set-sink-mute @DEFAULT_SINK@ toggle"

increaseSinkVolume :: Int -> X ()
increaseSinkVolume c = do
  unmuteSink
  spawn $
    if c < 0
      then printf "pactl set-sink-volume @DEFAULT_SINK@ -%d%%" (-c)
      else printf "pactl set-sink-volume @DEFAULT_SINK@ +%d%%" c

toggleMicMute :: X ()
toggleMicMute = spawn "exec pactl set-source-mute @DEFAULT_SOURCE@ toggle"

adjustBrightness :: Int -> X ()
adjustBrightness c =
  spawn $
    if c < 0
      then printf "brightnessctl s '%d%%-'" (-c)
      else printf "brightnessctl s '+%d%%'" c

simpleKeys :: XConfig Layout -> [(String, X (), String)]
simpleKeys conf =
  [ -- launchers
    ("M-<Return>", spawn $ XMonad.terminal conf, "Open terminal"),
    ("M-r", spawn "rofi -show drun", "Open launcher"),
    ("M-b", spawn "/bin/brave", "Open browser"),
    ("M-S-b", spawn "/bin/brave --incognito", "Open incognito browser"),
    ("M-e", spawn "emacsclient -cna ''", "Open emacs"),
    ("M-S-p", spawn "gmrun", "Open whatever gmrun is"),
    -- Close and restart stuff
    ("M-q", kill, "Close window"),
    ("M-S-r", spawn "xmonad --recompile; xmonad --restart", "Recompile and restart"),
    ("M-C-r", spawn "xmonad --restart", "Restart"),
    ("M-S-q", io exitSuccess, "Exit Xmonad"),
    ("M-x", spawn "xkill", "Kill a window (xkill)"),
    -- lock
    ("M-C-l", spawn "loginctl lock-session", "Lock screen"),
    -- Move, risize and focus stuff
    ("M-<Space>", sendMessage NextLayout, "Next layout"),
    ("M-S-<Space>", setLayout $ XMonad.layoutHook conf, "Default layout"),
    ("M-S-<Return>", windows W.swapMaster, "Move to top of stack"),
    ("M-f", sendMessage (Toggle "Full"), "Default layout"),
    ("M-n", refresh, "Refresh"),
    ("M1-<Tab>", windows W.focusDown, "Focus down"),
    ("M-j", windows W.focusDown, "Focus down"),
    ("M-k", windows W.focusUp, "Focus up"),
    ("M-m", windows W.focusMaster, "Focus master"),
    ("M-S-j", windows W.swapDown, "Move down"),
    ("M-S-k", windows W.swapUp, "Move up"),
    ("M-h", sendMessage Shrink, "Shrink master"),
    ("M-l", sendMessage Expand, "Expand master"),
    ("M-t", withFocused $ windows . W.sink, "Disable floating"),
    ("M-,", sendMessage (IncMasterN 1), "Increase master"),
    ("M-.", sendMessage (IncMasterN (-1)), "Decrease master"),
    ("M-S-/", showHelp conf, "Help"),
    -- Screenshot
    ("<Print>", spawn "flameshot gui", "Screenshot"),
    -- MPRIS
    ("M-p", spawn "playerctl play-pause", "play/pause"),
    ("M-C-p", spawn "playerctl pause -a", "play/pause"),
    ("M-]", spawn "playerctl next", "play/pause"),
    ("M-[", spawn "playerctl previous", "play/pause"),
    ("M-C-]", spawn "playerctld shift", "play/pause"),
    ("M-C-[", spawn "playerctld unshift", "play/pause"),
    -- Volume and brightness
    ("<XF86MonBrightnessUp>", adjustBrightness 10, "Increase brightness"),
    ("<XF86MonBrightnessDown>", adjustBrightness (-10), "Decrease brightness"),
    ("<XF86AudioRaiseVolume>", increaseSinkVolume 10, "Increase Volume"),
    ("<XF86AudioLowerVolume>", increaseSinkVolume (-10), "DecreaseVolume"),
    ("<XF86AudioMute>", toggleSinkMute, "Togle Mute"),
    ("<XF86AudioMicMute>", toggleMicMute, "Mute Microphone Mute")
  ]

------------------------------------------------------------------------
-- Key bindings. Add, modify or remove key bindings here.
--
myKeys :: XConfig Layout -> M.Map (KeyMask, KeySym) (X ())
myKeys conf@(XConfig {XMonad.modMask = modm}) =
  M.union keybinds workspace_keybinds
  where
    keybinds =
      mkKeymap
        conf
        [(a, b) | (a, b, _) <- simpleKeys conf]
    workspace_keybinds =
      M.fromList
        [ ((m .|. modm, k), windows $ f i)
          | (i, k) <- zip (XMonad.workspaces conf) ([xK_1 .. xK_9] ++ [xK_0]),
            (f, m) <- [(W.greedyView, 0), (W.shift, shiftMask)]
        ]

tabSettings :: Theme
tabSettings =
  def
    { Tabbed.fontName = "xft:FreeSans:size=11",
      -- active
      Tabbed.activeColor = "#29061e",
      Tabbed.activeBorderColor = "#81A1C1",
      Tabbed.activeTextColor = "#ff00aa",
      Tabbed.activeBorderWidth = 0,
      -- inactive
      Tabbed.inactiveColor = "#120c2b",
      Tabbed.inactiveBorderColor = "#3B4252",
      Tabbed.inactiveTextColor = "#6666cc",
      Tabbed.inactiveBorderWidth = 0,
      -- urgent
      Tabbed.urgentColor = "#BF616A",
      Tabbed.urgentBorderColor = "#BF616A",
      Tabbed.urgentBorderWidth = 0
    }

type MyLayout =
  ToggleLayouts
    (ModifiedLayout WithBorder Full)
    ( Choose
        (ModifiedLayout AvoidStruts (ModifiedLayout Spacing Tall))
        ( Choose
            (ModifiedLayout AvoidStruts (Mirror (ModifiedLayout Spacing Tall)))
            ( ModifiedLayout
                AvoidStruts
                ( ModifiedLayout
                    (Decoration TabbedDecoration DefaultShrinker)
                    Simplest
                )
            )
        )
    )

myLayout :: MyLayout Window
myLayout =
  toggleLayouts
    full
    ( avoidStruts tiled
        ||| avoidStruts (Mirror tiled)
        ||| avoidStruts tab
    )
  where
    tiled = spacing 10 $ Tall 1 (3 / 100) (1 / 2)
    full = noBorders Full
    tab = tabbed shrinkText tabSettings

myManageHook :: Query (Endo WindowSet)
myManageHook =
  composeAll
    [ className =? "Gimp" --> doFloat,
      className =? "Bitwarden" --> doFloat,
      className =? "Xmessage" --> doCenterFloat,
      className =? "Zenity" --> doCenterFloat,
      className =? "discord" --> doShift (myWorkspaces !! 2),
      className =? "Evolution" --> doShift (myWorkspaces !! 2),
      className =? "ONLYOFFICE Desktop Editors" --> doShift (myWorkspaces !! 3),
      className =? "Spotify" --> doShift (myWorkspaces !! 4),
      stringProperty "WM_WINDOW_ROLE" =? "pop-up" --> doCenterFloat,
      resource =? "desktop_window" --> doIgnore,
      resource =? "kdesktop" --> doIgnore
    ]

myEventHook :: Event -> X All
myEventHook = windowedFullscreenFixEventHook

myStartupHook :: X ()
myStartupHook =
  do
    cfgDir' <- asks (cfgDir . directories)
    let cfg path = joinPath [cfgDir', path]
    spawn ("killall polybar; polybar --config=" ++ cfg "res/polybar-config")
    spawnOnce ("feh --bg-scale " ++ cfg "res/wallpaper.png")
    spawnOnce ("picom --config " ++ cfg "res/picom.conf")
    spawnOnce "nm-applet"
    spawnOnce "dunst"
    spawnOnce ("xss-lock " ++ cfg "scripts/lock.sh")
    spawnOnce "xsetroot -cursor_name left_ptr"
    spawnOnce "lowbattery" -- low-battery-warning-git (aur)
    spawnOnce "discord"
    spawnOnce "playerctld"
    spawnOnce "flameshot"
    spawnOnce "spotify-launcher"
    spawnOnce "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
    return ()

defaults :: XConfig MyLayout
defaults =
  def
    { -- simple stuff
      terminal = "kitty",
      focusFollowsMouse = True,
      clickJustFocuses = False,
      borderWidth = 0,
      modMask = mod4Mask, -- Windows key
      workspaces = myWorkspaces,
      normalBorderColor = "#dddddd",
      focusedBorderColor = "#ff0000",
      -- key bindings
      keys = myKeys,
      -- hooks, layouts
      layoutHook = myLayout,
      manageHook = myManageHook,
      handleEventHook = myEventHook,
      startupHook = myStartupHook
    }

main :: IO ()
main = xmonad $ setEwmhActivateHook doAskUrgent . ewmh . docks . javaHack $ defaults

showHelp :: XConfig Layout -> X ()
showHelp conf = do
  h <- help conf
  spawn
    ( "echo \""
        ++ h
        ++ "\" | "
        ++ "zenity --text-info --font 'monospace 12' --width 1200 --height 720"
    )

help :: XConfig Layout -> X String
help conf =
  do
    dirs <- asks directories
    return $
      unlines $
        join
          [ ["Keybindings: "],
            [printf "  %-24s %s" a c | (a, _, c) <- simpleKeys conf],
            [ "",
              "Directories: ",
              "  Config Directory: " ++ cfgDir dirs,
              "  Cache Directory: " ++ cacheDir dirs,
              "  Data Directory: " ++ dataDir dirs
            ]
          ]
