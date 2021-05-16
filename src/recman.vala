
[DBus (name = "org.gnome.Shell.Screenshot", timeout = 10000 )]
interface ScreenShot : GLib.Object {
    public abstract void  SelectArea(out int x, out int y, out int w, out int h) throws Error;
}

[DBus (name = "org.gnome.Shell.Screencast", timeout = 120000)]
interface ScreenCast : GLib.Object {
    public abstract void  ScreencastArea(int x, int y, int w, int h, string filetemplate,
                                         HashTable<string,Variant> options,
                                         out bool result, out string filename) throws Error;
    public abstract void  Screencast(string filetemplate,
                                     HashTable<string,Variant> options,
                                     out bool result, out string filename) throws Error;
    public abstract void  StopScreencast(out bool result) throws Error;
}

public class ScreenCap : Object
{
    public struct AudioSource
    {
        string device;
        string desc;
    }

/*
    Causes recent pipewire to fail, alas.
    const string PIPELINE="vp9enc min_quantizer=10 max_quantizer=50 cq_level=13 cpu-used=5 deadline=1000000 threads=%T ! queue ! webmmux";
*/
    private enum STATE
    {
        None=0,
        Cap=1,
        Audio=2
    }

    public struct AudioOptions
    {
        bool capmouse;
        bool capaudio;
        bool fullscreen;
        int deviceid;
        string adevice;
        string outfile;
        int framerate;
        int delay;
    }

    private int x;
    private int y;
    private int w;
    private int h;

    private AudioRecorder arec;
    private string audio_tmp;
    private string video_tmp;
    private bool have_ffmpeg;
    internal ScreenShot ssbus;
    internal ScreenCast scbus;

    public AudioOptions options;
    public bool use_gst;

    STATE state = STATE.None;

    public ScreenCap()
    {
        try {
            ssbus = Bus.get_proxy_sync (BusType.SESSION,
                                        "org.gnome.Shell.Screenshot",
                                        "/org/gnome/Shell/Screenshot");
        } catch (Error e) {
            stderr.printf("Screenshot dbus: %s\n", e.message);
        }

        try {
            scbus = Bus.get_proxy_sync (BusType.SESSION,
                                        "org.gnome.Shell.Screencast",
                                        "/org/gnome/Shell/Screencast");
        } catch (Error e) {
            stderr.printf("Screencast dbus: %s\n", e.message);
        }
        arec = new AudioRecorder();
        have_ffmpeg = Utils.exists_on_path("ffmpeg");
    }

    public bool get_area(out string atext)
    {
        x = y = w =h = 0;
        bool ok = false;
        try {
            ssbus.SelectArea(out x, out y, out w, out h);
            ok = true;
        } catch (Error e) {
            stderr.printf("error: %s\n", e.message);
        }
        x = ((1+x)/2)*2;
        y = ((1+y)/2)*2;
        w = ((1+w)/2)*2;
        h = ((1+h)/2)*2;
        atext = "%dx%d@%d,%d".printf(w,h,x,y);
        return ok;
    }

    private HashTable<string,Variant> generate_options()
    {
        HashTable<string,Variant> vopts = new HashTable<string,Variant>(null, null);
//        vopts.insert ("pipeline", new Variant.take_string(PIPELINE));
        vopts.insert ("framerate", new Variant.int32 (options.framerate));
        vopts.insert ("draw-cursor", options.capmouse);
        return vopts;
    }

    public bool capture()
    {
        bool ok = false;
        var vid_tmpl = "/tmp/wayfarer_%d.%t.mkv";
        var vidopts = generate_options();
        vidopts.for_each((k,v) => {
                stderr.printf("%s => %s\n", k, v.print(true));
            });

        stderr.printf("try video file %s\n", vid_tmpl);
        try {
            if (options.fullscreen)
                scbus.Screencast(vid_tmpl, vidopts, out ok, out video_tmp);
            else {
                scbus.ScreencastArea(x, y, w, h, vid_tmpl, vidopts, out ok, out video_tmp);
            }
        } catch (Error e) {
            stderr.printf("Capture area: %s\n", e.message);
        }
        if (ok) {
            stderr.printf("Video to %s\n", video_tmp);
            state |= STATE.Cap;
            audio_tmp = video_tmp.replace(".mkv", ".ogg");
            ok = arec.StartRecording(audio_tmp, options.adevice);
            if (ok)
                state |= STATE.Audio;
            stderr.printf("Audio %s %s => %s\n", ok.to_string(), options.adevice,audio_tmp);
        }
        return ok;
    }

    public AudioSource [] get_sources()
    {
        AudioSource []at = {};
        try
        {
            string[] spawn_args = {"pactl", "list", "sources"};
            Pid child_pid;
            int p_stdout;

            Process.spawn_async_with_pipes (null,
                                            spawn_args,
                                            null,
                                            SpawnFlags.SEARCH_PATH |
                                            SpawnFlags.STDERR_TO_DEV_NULL,
                                            null,
                                            out child_pid,
                                            null,
                                            out p_stdout,
                                            null);
            IOChannel out = new IOChannel.unix_new (p_stdout);
            string line = null;
            size_t len = 0;
            string lname = null;
            for(;;) {
                try
                {
                    IOStatus eos = out.read_line (out line, out len, null);
                    if(eos == IOStatus.EOF)
                        break;
                    if(line == null || len == 0)
                        continue;

                    if (line.contains("Name: ")) {
                        var i = line.index_of (": ");
                        lname = line[i+2:line.length].chomp();
                    } else if (line.contains("Description: ")) {
                        var i = line.index_of (":");
                        string s = line[i+2:line.length].chomp();
                        AudioSource a = {};
                        a.desc = s;
                        a.device = lname;
                        at += a;
                    }
                } catch {
                    break;
                }
            }
            try { out.shutdown(false); } catch {}
            Process.close_pid (child_pid);

        } catch (SpawnError e) {
            print(e.message);
        }
        return at;
    }

    public void post_process()
    {
        bool result;
        if ((state & STATE.Cap) == STATE.Cap) {
            try {
                scbus.StopScreencast(out result);
            } catch (Error e) {
                print(e.message);
            }
        }
        if((state & STATE.Audio) == STATE.Audio) {
            arec.StopRecording();
	    stderr.printf("Stop recording\n");
	    if(Utils.is_vorbis(audio_tmp)) {
                if(use_gst || !have_ffmpeg) {
                    arec.Convert(video_tmp, audio_tmp, options.outfile);
                } else {
                    var ffmpeg = "ffmpeg -i %s -i %s -c copy %s -y".printf(video_tmp, audio_tmp, options.outfile);
                    try
                    {
                        Process.spawn_command_line_sync (ffmpeg);
                    } catch (Error e)  {
                        print(e.message);
                    }
                }
                FileUtils.unlink(video_tmp);
            } else {
                FileUtils.rename (video_tmp, options.outfile);
            }
            FileUtils.unlink(audio_tmp);
        } else {
            FileUtils.rename (video_tmp, options.outfile);
        }
        state = STATE.None;
    }
}

#if RECMANEXE

static bool aflag;
static bool fflag;
static bool mflag;
static bool pflag;

static int frate;
static int delay;

public class CliCap : Object
{
    MainLoop ml;
    ScreenCap sc;

    private void process()
    {
        stderr.printf("Sources start\n");
        var at = sc.get_sources();
        stderr.printf("Sources %u\n", at.length);
        foreach(var a in at)  {
            stderr.printf("Name: %s, dev: %s\n", a.desc, a.device);
            if(mflag == false && a.device.contains(".monitor"))
                sc.options.adevice = a.device;
            else
                sc.options.adevice = a.device;
        }

        bool res = false;
        if(fflag == false) {
            string astr;
            res = sc.get_area(out astr);
            if (res == true)
                stderr.printf("%s\n", astr);
            else {
                stderr.printf("failed to get screen info\n");
            }
        }
        res = sc.capture();
    }

    private bool sigfunc()
    {
        stderr.printf("Got signal \n");
        sc.post_process();
        ml.quit();
        return Source.CONTINUE;
    }


    public void run(string fname)
    {
        ml= new MainLoop();

        Unix.signal_add(Posix.Signal.TERM, sigfunc);
        Unix.signal_add(Posix.Signal.USR1, sigfunc);

        sc = new ScreenCap();
        sc.options.fullscreen = fflag;
        sc.options.capmouse = !pflag;
        sc.options.capaudio = !aflag;
        if (frate == 0)
            frate = 25;
        sc.options.framerate = frate;
        sc.options.delay = delay;
        sc.options.outfile = fname;
        process();
        ml.run();
    }
}

const OptionEntry[] options = {
    { "noaudio", 'A', 0, OptionArg.NONE, out aflag, "don't record audio", null},
    { "fullscreen", 'F', 0, OptionArg.NONE, out fflag, "full screen", null},
    { "use-mic", 'M', 0, OptionArg.NONE, out mflag, "use microphone (vice monitor)", null},
    { "nopointer", 'P', 0, OptionArg.NONE, out pflag, "don't show pointer", null},
    { "frame-rate", 'f', 0, OptionArg.INT, out frate, "Frames/sec", "25"},
    { "delay", 'd', 0, OptionArg.INT, out delay, "Delay", "0"},
    {null}
};

int main(string []args)
{
    string outfn = null;
    var opt = new OptionContext("");
    try
    {
        opt.set_help_enabled(true);
        opt.add_main_entries(options, null);
        opt.parse(ref args);
    } catch (OptionError e) {
        stderr.printf("Error: %s\n", e.message);
        stderr.printf("Run '%s --help' to see a full list of available options\n", args[0]);
        return 1;
    }
    if(args.length > 1) {
        outfn = args[1];
    } else {
        stderr.printf("File name required\n");
        return 1;
    }

    var cliapp = new CliCap();
    cliapp.run(outfn);
    return 0;
}
#endif
