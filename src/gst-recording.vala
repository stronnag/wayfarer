using Gst;

public class MediaRecorder : GLib.Object {
    internal enum State {
        NONE = 0,
        RECORDING = 1,
    }

    private State state;
    private Pipeline pipeline;
	public signal void report_gst_error(string s);
	public signal void stream_ended();

    public MediaRecorder() {
        state = State.NONE;
    }

    public bool start_capture (ScreenCap.Options o, GenericArray<PortalManager.SourceInfo?> sources, out string fname) {
        stderr.printf("Media: %s\n", o.mediatype);
        stderr.printf("Capture audio: %s\n", o.capaudio.to_string());
        stderr.printf("Full screen: %s\n", o.fullscreen.to_string());
        stderr.printf("Frame rate: %d\n", o.framerate);
        stderr.printf("Audio rate: %d\n", o.audiorate);
        stderr.printf("Audiodevice: %s\n", o.adevice);
        stderr.printf("Area: (%d, %d) (%d, %d)\n",  o.selinfo.x0, o.selinfo.y0,
                      o.selinfo.x1,
                      o.selinfo.y1);
        stderr.printf("fd: %d\n", o.fd);

        sources.foreach((s) => {
                stderr.printf("Source: {nodeid=%u w=%d h=%d x=%d y=%d source-type=%u}\n", s.node_id, s.width, s.height,s.x,s.y,s.source_type);
            });

        var sg = new ScreenGrab();
        pipeline = sg.generate_pipeline(o, sources, out fname);
        if (pipeline != null) {
            stderr.printf("File: %s\n", fname);
            state = State.RECORDING;
            monitor_bus();
            pipeline.set_state(Gst.State.PLAYING);
            return true;
        } else {
            return false;
        }
    }

	private void monitor_bus() {
		var bus = pipeline.get_bus ();
		bus.add_watch (0, (b, message) => {
				switch (message.type) {
				case MessageType.ERROR:
                   GLib.Error err = null;
                   string debug = "";
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
					stream_ended();
					return false;
				default:
				    break;
				}
				return true;
			});
	}

    public void stop_recording() {
		pipeline.send_event (new Gst.Event.eos () );
        state = State.NONE;
	}

    public void force_quit() {
        pipeline.set_state (Gst.State.NULL);
        pipeline = null;
    }
}
