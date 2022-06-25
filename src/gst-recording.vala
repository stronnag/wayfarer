using Gst;

public class MediaRecorder : GLib.Object
{
    internal enum State {
        NONE = 0,
        RECORDING = 1,
    }

	private Element pipeline;
    private State state;

	public signal void report_gst_error(string s);

    public MediaRecorder(string? []args = {})
    {
        Gst.init (ref args);
        state = State.NONE;
    }

    public bool StartPipewire(ScreenCap.Options o, PortalManager.SourceInfo []sources) {
        StringBuilder sb = new StringBuilder();
		var h =  sources[0].height;
		var w = 0;
		if (sources.length > 1) {
			sb.append("compositor name=comp ");
			var i = 0;
			foreach (var s in sources) {
				sb.append_printf("sink_%d::xpos=%d ", i, s.xpos);
				i++;
				w += s.width;
			}
			sb.append(" ! ");
		}
		if (w == 0) {
			w = sources[0].width;
		}
        sb.append_printf("queue name=queue0 ! videorate ! video/x-raw, framerate=%d/1", o.framerate);
        if(o.atype == 1) {
			var rm = w-o.x1;
			if (rm < 0)
				rm = 0;
			var bm = h-o.y1;
			if (bm < 0)
				bm = 0;
            sb.append_printf(" ! videoscale ! video/x-raw, width=%d, height=%d ! videocrop top=%d left=%d right=%d bottom=%d", w, h, o.y0, o.x0, rm, bm);
        }

		sb.append_printf(" ! videoconvert chroma-mode=GST_VIDEO_CHROMA_MODE_NONE dither=GST_VIDEO_DITHER_NONE matrix-mode=GST_VIDEO_MATRIX_MODE_OUTPUT_ONLY n-threads=%u", 1+(o.nproc/2));

        sb.append_printf(" ! queue ! %s ! filesink name=filesink location=\"%s\"", Utils.get_encopts(o), o.outfile);

		if (sources != null) {
			if (sources.length == 1) {
				sb.append_printf(" pipewiresrc fd=%d path=%u do-timestamp=true keepalive-time=1000 resend-last=true  ! video/x-raw, max-framerate=%d/1 ! queue0.",  o.fd, sources[0].node_id, o.framerate);
			} else {
				foreach (var s in sources) {
					sb.append_printf(" pipewiresrc fd=%d path=%u do-timestamp=true keepalive-time=1000 resend-last=true ! video/x-raw, max-framerate=%d/1 ! comp. ", o.fd, s.node_id,  o.framerate);
				}
			}
		}

		if(o.capaudio) {
            var arate = (o.audiorate == 0) ? "" : "bitrate=%d".printf(o.audiorate);
            sb.append_printf(" pulsesrc device=\"%s\" ! opusenc %s ! queue ! mux." ,
                             o.adevice, arate);
        }
        print("pipeline = %s\n", sb.str);
        bool ok = false;
        try {
            pipeline = Gst.parse_launch (sb.str);
            state = State.RECORDING;
			monitor_bus();
            pipeline.set_state(Gst.State.PLAYING);
            ok = true;
        } catch (Error e) {
            stderr.printf ("Error: %s\n", e.message);
        }
        return ok;
    }

	private void monitor_bus() {
		var bus = pipeline.get_bus ();
		GLib.Error err = null;
		string debug = "";
		bus.add_watch (0, (b, message) => {
				switch (message.type) {
				case MessageType.ERROR:
				    message.parse_error (out err, out debug);
					print ("GST(e): %s\n", err.message);
					Idle.add(() => {
							report_gst_error(err.message);
							return false;
						});
					pipeline.set_state (Gst.State.NULL);
					b.remove_watch();
					bus = null;
					return false;
				case MessageType.EOS:
				    print ("Gstreamer: EOS\n");
					pipeline.set_state (Gst.State.NULL);
					b.remove_watch();
					bus = null;
					return false;
				default:
				    break;
				}
				return true;
			});
	}

    public void StopRecording()
    {
		pipeline.send_event (new Gst.Event.eos () );
        state = State.NONE;
	}

    public bool Capture_fallback(ScreenCap.Options o)
    {
        string area = "";
        if (!o.fullscreen) {
            area = "startx=%d starty=%d endx=%d endy=%d".printf(o.x0,o.y0,o.x1,o.y1);
        }
        var vc = Utils.get_encopts(o);
		StringBuilder sb = new StringBuilder();

		var display = Environment.get_variable("DISPLAY");
		if (display == null)
			display = ":0";

		sb.append_printf("ximagesrc display-name=%s show-pointer=%s %s ! video/x-raw, framerate=%d/1 ! videoconvert ! queue ! %s ! filesink location=\"%s\"", display, o.capmouse.to_string(), area, o.framerate, vc, o.outfile);
        if(o.capaudio) {
            var arate = (o.audiorate == 0) ? "" : "bitrate=%d".printf(o.audiorate);
            sb.append_printf(" pulsesrc device=\"%s\" ! audio/x-raw ! queue ! audioconvert ! opusenc %s ! mux." , o.adevice, arate);
        }

        stderr.printf("pipe=%s\n", sb.str);
        try {
            pipeline = Gst.parse_launch (sb.str);
		} catch (Error e) {
            stderr.printf ("Error: %s\n", e.message);
            return false;
        }
        pipeline.set_state (Gst.State.PLAYING);
		monitor_bus();
        return true;
    }
}
