
public class ScreenCap : Object
{
    public struct AudioSource
    {
        string device;
        string desc;
    }

    private enum STATE
    {
        None=0,
        Cap=1,
        Audio=2,
		Pipewire=4
    }

    public struct Options
    {
		string mediatype;
        bool capmouse;
        bool capaudio;
        bool fullscreen;
        bool fallback;
        int deviceid;
        int framerate;
        int audiorate;
        int delay;
        string adevice;
        string outfile;
		int x0;
		int y0;
		int x1;
		int y1;
		int fd;
		uint32 node_id;
		uint8 atype;
		int vaapis;
		uint nproc;
    }

    private MediaRecorder mediarec;
    private bool bsd_x11;

    public Options options;

	public signal void report_gst_error(string s);

    STATE astate = STATE.None;

    public ScreenCap(bool fallback=false) {
        mediarec = new MediaRecorder();
//		var u = Posix.utsname();
        if(Environment.get_variable("XDG_SESSION_TYPE") != "wayland") {
            /* if (fallback || u.sysname == "FreeBSD") {
            }
			*/
			bsd_x11 = true;
        }
		mediarec.report_gst_error.connect((s) => {
				report_gst_error(s);
			});
	}

    public bool get_x11() {
        return bsd_x11;
    }


    public bool capture(PortalManager.SourceInfo []sources)
    {
        bool ok = false;
        if(!bsd_x11) {
            ok = mediarec.StartPipewire(options, sources);
			if (ok) {
				astate |= STATE.Pipewire;
			}
        } else {
            ok = mediarec.Capture_fallback(options);
            if (ok) {
                astate |= STATE.Cap;
            }
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

    public void post_process() {
		mediarec.StopRecording();
		astate = STATE.None;
    }

	public void set_bbox(int x0, int y0, int x1, int y1) {
		if(x1 > x0) {
			options.x0 = x0;
			options.x1 = x1;
		} else {
			options.x0 = x1;
			options.x1 = x0;
		}

		if(y1 > y0) {
			options.y0 = y0;
			options.y1 = y1;
		} else {
			options.y0 = y1;
			options.y1 = y0;
		}
	}
}
