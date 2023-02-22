
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
        ok = mediarec.StartCapture(options, sources, out fname);
        if (ok) {
            astate |= STATE.Pipewire;
        }
        return ok;
    }

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

    public void post_process() {
		mediarec.StopRecording();
		astate = STATE.None;
    }

	public void set_bbox(int x0, int y0, int x1, int y1) {
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
        Utils.get_even(ref options.selinfo.x0, false);
        Utils.get_even(ref options.selinfo.x1, true);
        Utils.get_even(ref options.selinfo.y0, false);
        Utils.get_even(ref options.selinfo.y1, true);
    }
}
