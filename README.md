# Wayfarer - Screen Recorder for GNOME / Wayland / Pipewire

## Features and limitations

**wayfarer** is a screen recorder for GNOME

* Modern GNOME desktop (3.38, 40)
* Wayland or Xorg
* Pipewire / Pusleaudio

Does not support other desktops.

Requires:

* GTK 3
* Vala
* Gstreamer 1.0
* AppIndicator
* Optionally, ffmpeg

**wayfarer** supports VP8 as the video format and Vorbis as the audio format. This is set, in some part due to restrictions of the `org.gnome.Screecast` Dbus API. The output is in a Matroska container.

For Gnome shall 41, it is necessary to set `unsafe` mode in order to record one's own desktop (without a painful migration to the (new and possibly less functional) `org.freedesktop.portal.Desktop` Dbus API. There is a shell extension in the `gs41` directory that enables unsafe mode.

## Building

Appindicator is a build time dependency; at runtime, if you have an appindicator Gnome Shell extension installed, you can use the indicator to stop recording; without such an indicator, you can use Notification, with a less good user experience.

* For Arch Linux, install `libappindicator-gtk3`.
* On Debian / Ubuntu et al the app indicator package is called `libayatana-appindicator3-dev` and you also need `gir1.2-ayatanaappindicator3-0.1`.
* For Fedora, try `libappindicator-gtk3-devel`

The build system is meson / ninja, e.g.

```
meson build --buildtype=release --prefix=~/.local
# then
meson install -C build
```

On older distros (e.g. Ubuntu 20.04), it is necessary to replace the compile and install with:

```
cd build
ninja install
```

## User Interface

![Main Window](data/assets/wayfarer-window.png)

* Define an area using the `Set Area` control. Drag the displayed control to size, ESC to abort.
* Set a file name (optionally directory).
* Select the audio source
* `Delay` defines a delay (seconds) before recording starts
* `Timer` defines the length of the recording (seconds) : 0 (default) means user will stop the recording.
* `Record` starts the recording; requires a file name and either an area defined or `Fullscreen`

Once recording is started:

* If `Timer` is set, the recording will run for the set number of seconds
* If an AppIndicator tray is used, there will be an icon in the system tray, clicking this provides a "Stop Recording" button.
* Otherwise, use the "Preferences" menu and set `Use notifications (vice App Indicator)`. Clicking on the notification will stop the recording.

The menu button at the right of the header bar offers three options:

* Preferences
* About
* Quit (or use the header bar close button)

### Preferences

![Main Window](data/assets/wayfarer-prefs.png)

* Force Gstreamer for output : Uses Gstreamer (in preference to ffmpeg) to combine audio and video streams. Gstreamer is also used if ffmpeg is not found on the system. Gstreamer is somewhat slower than ffmpeg; the file sizes are similar.
* Use Notifications for ready : if set, a notification count down is shown for delays > 2 seconds.
* Use notifications (vice App Indicator). Provides a persistent Notification to stop recordings; mainly needed if you don't have an AppIndicator tray shell extension.

Preferences are stored as a simple `key = value` text file in `~/.config/wayfarer/cap.conf`.

## Miscellaneous

Licence : GPL v3 or later
(c) Jonathan Hudson 2021

Inspired by other fine tools such as **peek** and **green-recorder**; I appreciate the developer's pain with the moving targets of Gnome, Wayland and Pipewire.
