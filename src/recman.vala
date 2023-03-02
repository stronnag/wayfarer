
public class ScreenCap : Object {
    public struct AudioSource {
        string device;
        string desc;
    }

    private enum STATE {
        None=0,
        Cap=1,
        Audio=2,
		Pipewire=4
    }

    public struct SelInfo {
        int x0;
        int y0;
        int x1;
        int y1;
    }

    public struct Options {
		int fd;
        int framerate;
        int audiorate;
        string adevice;
		string dirname;
		string mediatype;
        SelInfo selinfo;
        bool capaudio;
        bool capmouse;
        bool fullscreen;
    }

    private MediaRecorder mediarec;
    public Options options;

	public signal void report_gst_error(string s);

    STATE astate = STATE.None;

    public ScreenCap() {
        options={};
        mediarec = new MediaRecorder();
		mediarec.report_gst_error.connect((s) => {
				report_gst_error(s);
			});
	}

    public bool capture(GenericArray<PortalManager.SourceInfo?>sources, out string fname) {
        bool ok = false;
        astate = STATE.None;
        ok = mediarec.start_capture(options, sources, out fname);
        if (ok) {
            astate |= STATE.Pipewire;
        }
        return ok;
    }

#if USE_GSTDEV
    public AudioSource [] get_audio_sources() {
        AudioSource []at = {};
        var monitor = new Gst.DeviceMonitor ();
        var caps = new Gst.Caps.empty_simple ("audio/x-raw");
        monitor.add_filter ("Audio/Source", caps);
        var devs = monitor.get_devices();
        devs.foreach((d) => {
                var props = d.properties;
                if (props != null) {
                    var dc = props.get_string("device.class");
                    if (dc != null) {
                        var nn = props.get_string("node.name");
                        if (nn != null) {
                            if(dc == "monitor") {
                                nn = nn + ".monitor";
                            }
                            bool add=true;
                            foreach(var as in at) {
                                if (as.device == nn) {
                                    add = false;
                                    break;
                                }
                            }
                            if (add) {
                                AudioSource a = AudioSource(){desc=d.display_name, device=nn};
                                at += a;
                            }
                        }
                    }
                }
            });
        return at;
    }
#endif

#if USE_PACTL_DEV
    public AudioSource [] get_audio_sources() {
        AudioSource []at = {};
        try {
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
                try {
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
#endif

    public AudioSource [] get_audio_sources() {
        AudioSource []at = {};
        var ml = new PulseAudio.GLibMainLoop( null);
        var api = ml.get_api();
        var ctx = new PulseAudio.Context(api, "wayfarer", null);
        ctx.connect(null,0, null);
        PulseAudio.Context.State pastate = 0;
        int state = 0;
        ctx.set_state_callback((c) => {
                pastate = c.get_state();
                switch (pastate) {
                case PulseAudio.Context.State.READY:
                    state = 1;
                    break;
                case PulseAudio.Context.State.FAILED:
                case PulseAudio.Context.State.TERMINATED:
                    state = -1;
                    break;
                default:
                    state = 0;
                    break;
                }
            });
        var mlc = MainContext.@default();
        PulseAudio.Operation? op = null;
        while (true) {
            while(state == 0) {
                mlc.iteration(true);
                continue;
            }
            if (state == -1) {
                break;
            }
            if (state == 1) {
                op = ctx.get_source_info_list ((c, l, eol) => {
                        if (eol > 0) {
                            state = 3;
                        } else {
                            AudioSource a = AudioSource(){device=l.name, desc=l.description};
                            at += a;
                        }
                    });
                state = 2;
            }
            if(state == 3) {
                if (op.get_state() ==  PulseAudio.Operation.State.DONE) {
                    ctx.disconnect();
                    break;
                }
            }
            mlc.iteration(true);
        }
        return at;
    }

    public void post_process(bool forced = false) {
        if (astate != STATE.None) {
            mediarec.stop_recording();
            if (forced) {
                mediarec.force_quit();
            }
        }
        astate = STATE.None;
    }

	public void set_bbox(int x0, int y0, int x1, int y1) {
/**
		if(x1 > x0) {
			options.selinfo.x0 = x0;
			options.selinfo.x1 = x1;
		} else {
			options.selinfo.x0 = x1;
			options.selinfo.x1 = x0;
		}

		if(y1 > y0) {
			options.selinfo.y0 = y0;
			options.selinfo.y1 = y1;
		} else {
			options.selinfo.y0 = y1;
			options.selinfo.y1 = y0;
		}
**/
        options.selinfo.x0 = x0;
        options.selinfo.x1 = x1;
        options.selinfo.y0 = y0;
        options.selinfo.y1 = y1;
        Utils.get_even(ref options.selinfo.x0, false);
        Utils.get_even(ref options.selinfo.x1, true);
        Utils.get_even(ref options.selinfo.y0, false);
        Utils.get_even(ref options.selinfo.y1, true);
    }
}
