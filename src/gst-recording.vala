using Gst;

public class MediaRecorder : GLib.Object
{
    internal enum State
    {
        NONE = 0,
        RECORDING = 1,
    }

//    private Pipeline pipeline;
    private Element vpl;
	private Element pipeline;
    private string srcname;
    private State state;

    public MediaRecorder(string? []args = {})
    {
        Gst.init (ref args);
        state = State.NONE;
    }

    public bool StartRecording(string filename, string? device)
    {
        bool ok = false;
        if (device != null)
        {
            srcname = device;
        }

        if (filename != null && srcname != null) {
			try {
				var sm = "pulsesrc device=%s ! audioconvert ! opusenc bitrate=16000 ! oggmux ! filesink location=%s".printf(srcname, filename);
				pipeline = Gst.parse_launch (sm);
				state = State.RECORDING;
				pipeline.set_state(Gst.State.PLAYING);
				ok = true;
			} catch (Error e) {
				stderr.printf ("Error: %s\n", e.message);
				return false;
			}
        }
        return ok;
    }

    public void StopRecording()
    {
        pipeline.set_state (Gst.State.NULL);
        pipeline.dispose ();
        state = State.NONE;
    }

    public bool Capture_x11_mp4(string name, ScreenCap.Options o, int x, int y, int w, int h)
    {
        string area = "";
        if (!o.fullscreen) {
            int ex = (x+w)|1;
            int ey= (y+h)|1;
            area = "startx=%d starty=%d endx=%d endy=%d".printf(x,y,ex,ey);
        }
        var sm = "ximagesrc display-name=:0 show-pointer=%s %s ! video/x-raw, framerate=%d/1 ! videoconvert ! x264enc qp-min=17 qp-max=17 speed-preset=superfast threads=5 ! mux. matroskamux name=mux writing-app=wayfarer ! filesink location=%s".printf( o.capmouse.to_string(), area, o.framerate, name);

        stderr.printf("pipe=%s\n", sm);
        try {
            vpl = Gst.parse_launch (sm);
	} catch (Error e) {
            stderr.printf ("Error: %s\n", e.message);
            return false;
        }
        vpl.set_state (Gst.State.PLAYING);
        return true;
    }

    public bool StopVideoRecording()
    {
        vpl.set_state (Gst.State.NULL);
        vpl.dispose ();
        return true;
    }

    public void Convert(string vidsrc, string audsrc, string outfile)
    {
        Gst.Element pl;
        var sm = "filesrc location=\"%s\" ! matroskademux ! queue ! matroskamux name=mux ! filesink location=\"%s\"  filesrc location=\"%s\" ! decodebin ! audioconvert ! opusenc ! queue ! mux.".printf(vidsrc, outfile, audsrc);
        try {
            pl = Gst.parse_launch (sm);
	} catch (Error e) {
            stderr.printf ("Error: %s\n", e.message);
            return;
        }
        Gst.Bus bus = pl.get_bus ();
        pl.set_state (Gst.State.PLAYING);
	bus.timed_pop_filtered (Gst.CLOCK_TIME_NONE, Gst.MessageType.ERROR | Gst.MessageType.EOS);
	pl.set_state (Gst.State.NULL);
    }
}

#if GSTTEST
int main (string[] args) {

    MainLoop ml;
    ml = new MainLoop ();
    var a = new MediaRecorder();
    string mondev = "alsa_output.pci-0000_00_1b.0.analog-stereo.monitor";

    switch(args.length) {
        case 3:
            mondev = args[2];
        case 2:
            Idle.add(() => {
                a.StartRecording(args[1], mondev);
                    Timeout.add_seconds(10, () => {
                            a.StopRecording();
                            ml.quit();
                            return Source.REMOVE;
                        });
                    return Source.REMOVE;
                });
            break;
        case 4:
            Idle.add(() => {
                    a.Convert(args[1], args[2], args[3]);
                    ml.quit();
                    return Source.REMOVE;
                });
            break;
        default:
            return 255;
    }
    ml.run ();
    return 0;
}
#endif
