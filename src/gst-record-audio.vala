using Gst;

public class AudioRecorder : GLib.Object
{
    internal enum State
    {
        NONE = 0,
        RECORDING = 1,
    }

    private Pipeline pipeline;
    private string srcname;
    private State state;

    public AudioRecorder(string? []args = {})
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
            pipeline = new Pipeline ("test");
            var audiosrc = ElementFactory.make ("pulsesrc", "pulsesrc");
            var audioconvert = ElementFactory.make ("audioconvert", "audioconvert");
            var vorbisenc = ElementFactory.make("vorbisenc", "vorbisenc");
            var oggmux = ElementFactory.make("oggmux", "oggmux");
            var filesink = ElementFactory.make("filesink", "filesink");

            audiosrc.set_property("device", srcname);
            filesink.set_property("location",filename);
            pipeline.add( audiosrc);
            pipeline.add( audioconvert);
            pipeline.add( vorbisenc);
            pipeline.add( oggmux);
            pipeline.add( filesink);

            audiosrc.link( audioconvert);
            audioconvert.link( vorbisenc);
            vorbisenc.link( oggmux);
            oggmux.link( filesink);
            state = State.RECORDING;
            pipeline.set_state(Gst.State.PLAYING);
            ok = true;
        }
        return ok;
    }

    public void StopRecording()
    {
        pipeline.set_state (Gst.State.NULL);
        pipeline.dispose ();
        state = State.NONE;
    }

    public void Convert(string vidsrc, string audsrc, string outfile)
    {
        Gst.Element pl;
        var sm = "filesrc location=\"%s\" ! matroskademux ! queue ! matroskamux name=mux ! filesink location=\"%s\"  filesrc location=\"%s\" ! decodebin ! audioconvert ! vorbisenc ! queue ! mux.".printf(vidsrc, outfile, audsrc);
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
    var a = new AudioRecorder();
    if (args.length == 2) {
        Idle.add(() => {
            a.StartRecording(args[1], "alsa_output.pci-0000_00_1b.0.analog-stereo.monitor");
            Timeout.add_seconds(10, () => {
                    a.StopRecording();
                    ml.quit();
                    return Source.REMOVE;
                });
            return Source.REMOVE;
        });
    } else if (args.length == 4) {
        Idle.add(() => {
                a.Convert(args[1], args[2], args[3]);
                ml.quit();
                return Source.REMOVE;
            });
    } else {
        return 255;
    }
    ml.run ();
    return 0;
}
#endif
