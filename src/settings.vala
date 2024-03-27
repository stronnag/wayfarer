[Compact]
public class Conf : Object {
    public string audio_device { get; set; }
    public string video_dir { get; set; }
    public string media_type { get; set; }
    public string restore_token { get; set; }

    public uint32 audio_rate { get; set; }
    public uint32 frame_rate { get; set; }

    public bool notify_start { get; set; }
    public bool notify_stop { get; set; }

    public bool show_hint { get; set; }

	public bool no_pop { get; set; }

    private Settings s;

    public signal void changed(string str);
    construct {
        s = new Settings("org.stronnag.wayfarer");
        s.bind("audio-device", this, "audio-device", SettingsBindFlags.DEFAULT);
        s.bind("video-dir", this, "video-dir", SettingsBindFlags.DEFAULT);
        s.bind("media-type", this, "media-type", SettingsBindFlags.DEFAULT);
        s.bind("restore-token", this, "restore_token", SettingsBindFlags.DEFAULT);
        s.bind("audio-rate", this, "audio-rate", SettingsBindFlags.DEFAULT);
        s.bind("frame-rate", this, "frame-rate", SettingsBindFlags.DEFAULT);
        s.bind("notify-start", this, "notify_start", SettingsBindFlags.DEFAULT);
        s.bind("notify-stop", this, "notify_stop", SettingsBindFlags.DEFAULT);
        s.bind("show-hint", this, "show-hint", SettingsBindFlags.DEFAULT);
        s.bind("no-pop", this, "no-pop", SettingsBindFlags.DEFAULT);
    }
}
