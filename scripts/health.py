#!/usr/bin/env python3
import sys
from shutil import which
from subprocess import PIPE, run

"""
A simple script to check that the dependencies of this configuration is
installed.  If any dependencies are missing, this script will try to suggest a
solution, but it will not install anything.
"""


def main():
    require_cmd("i3lockr", aur="i3lockr-bin")
    require_cmd("dunst", pacman="dunst")
    require_cmd("rofi", pacman="rofi")
    require_cmd("playerctl", pacman="playerctl")
    require_cmd("pactl", pacman="libpulse")
    require_cmd("nm-applet", pacman="network-manager-applet")
    require_cmd("xss-lock", pacman="xss-lock")
    require_cmd("picom", pacman="picom")
    require_cmd("feh", pacman="feh")
    require_cmd("xsetroot", pacman="xorg-xsetroot")
    require_cmd("polybar", pacman="polybar")
    require_cmd("flameshot", pacman="flameshot")
    require_cmd("lowbattery", aur="low-battery-warning-git")
    if require_cmd("fc-list", pacman="font-config"):
        require_font("SauceCodePro Nerd Font", pacman="ttf-sourcecodepro-nerd")


def require_font(font, pacman=None, yay=None):
    res = run(["fc-list", "SauceCodePro Nerd Font"], stdout=PIPE)
    for line_ in res.stdout.split(b"\n"):
        line = line_.decode("utf8")
        parts = line.split(": ")
        if len(parts) != 2:
            continue
        name = line.split(": ")[1].split(",")[0]
        if name == font:
            print(f"font '{font}' {Colors.GREEN}OK{Colors.RESET}")
            return True

    print(f"font '{font}' {Colors.RED}not found{Colors.RESET}")
    match os_info.get("ID"):
        case "arch" if pacman is not None:
            print_hint(f"font '{font}' can be installed with ",
                       f"`sudo pacman -S {pacman}`")
        case "arch" if yay is not None:
            print_hint(f"{Colors.YELLOW}font '{font}' can be installed with ",
                       f"`yay -S {yay}`{Colors.RESET}")

    return False


def require_cmd(cmd, pacman=None, aur=None):
    if which(cmd) is not None:
        print(f"{cmd} {Colors.GREEN}OK{Colors.RESET}")
        return True

    print(f"{cmd} {Colors.RED}not in `PATH`{Colors.RESET}")
    match os_info.get("ID"):
        case "arch" if pacman is not None:
            print_hint(f"{cmd} can be installed with ",
                       f"`sudo pacman -S {pacman}`")
        case "arch" if aur is not None:
            print_hint(f"{Colors.YELLOW}{cmd} can be installed with ",
                       f"`yay -S {aur}`{Colors.RESET}")

    return False


def get_os_info():
    os_info = dict()
    try:
        with open("/etc/os-release") as os_release:
            for line in os_release:
                k, v = line.strip().split("=")
                os_info[k] = v
        return os_info
    except Exception:
        return {}


os_info = get_os_info()


def print_hint(*args, sep=" ", end="\n"):
    print(Colors.YELLOW, sep.join(args),
          Colors.RESET, sep="", end=end,
          file=sys.stderr)


class Colors:
    RED = "\x1b[31m"
    GREEN = "\x1b[32m"
    RESET = "\x1b[0m"
    YELLOW = "\x1b[33m"


if __name__ == "__main__":
    main()
