#!/usr/bin/python

import sys
from xml.etree import ElementTree

import dbus
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

dbus_loop = DBusGMainLoop(set_as_default=True)


class Namespace(str):
    def __getattr__(self, name):
        return self.__class__(f"{self}.{name}")


MediaPlayer2 = Namespace("org.mpris.MediaPlayer2")
Properties = Namespace("org.freedesktop.DBus.Properties")
Introspectable = Namespace("org.freedesktop.DBus.Introspectable")


def main():
    bus = dbus.SessionBus()

    player = bus.get_object(MediaPlayer2.playerctld, "/org/mpris/MediaPlayer2")

    properties = dbus.Interface(player, "org.freedesktop.DBus.Properties")
    player = dbus.Interface(player, "org.mpris.MediaPlayer2.Player")

    player_properties = properties.GetAll(MediaPlayer2.Player)

    def statusbar():
        # print(json.dumps(player_properties, indent=2))
        playing = player_properties["PlaybackStatus"] != "Paused"
        title = player_properties["Metadata"].get("xesam:title")

        play_pause_icon = "\U000f03e4" if playing else "\U000f040a"
        play_button = clickable("playerctl play-pause", play_pause_icon)
        next_button = clickable("playerctl next", "\U000f04ad")
        prev_button = clickable("playerctl previous", "\U000f04ae")
        shift_button = clickable("playerctld shift", "\U000f0465")
        unshift_button = clickable("playerctld unshift", "\U000f0467")

        print(
            f"{truncate(title, 30)}"
            f"{prev_button}{play_button}{next_button}"
            f"{shift_button}{unshift_button}"
        )
        sys.stdout.flush()

    def handle_change(player, state, other):
        for prop, val in state.items():
            player_properties[prop] = val
        statusbar()

    properties.connect_to_signal("PropertiesChanged", handle_change)
    statusbar()

    loop = GLib.MainLoop()
    loop.run()


def clickable(cmd, text):
    start = "%{A1:" + cmd + ":} "
    end = " %{A}"
    return start + text + end


def truncate(text: str, max_len: int = 10) -> str:
    if len(text) > max_len:
        return text[: max_len - 3] + "..."
    return text


def to_py_value(value):
    if isinstance(value, dbus.Dictionary):
        return {str(key): to_py_value(val) for (key, val) in value.items()}
    if isinstance(value, dbus.String):
        return str(value)
    if (
        isinstance(value, dbus.UInt16)
        or isinstance(value, dbus.UInt32)
        or isinstance(value, dbus.UInt64)
    ):
        return int(value)
    if isinstance(value, dbus.Boolean):
        return bool(value)
    return value


def find_all_members(object):
    xml = object.Introspect(dbus_interface=Introspectable)
    tree = ElementTree.fromstring(xml)
    for interface in tree:
        iface_name = interface.attrib["name"]
        for member in interface:
            signal_name = member.attrib["name"]
            yield iface_name, member.tag, signal_name


if __name__ == "__main__":
    main()
