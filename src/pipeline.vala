using Gst;

class ScreenGrab : GLib.Object {
    private Gst.Pipeline pipeline;
    private Gst.Element videosrc_bin;
    private Gst.Element audiosrc_bin;
    private Gst.Element queue;

    Gst.Element? videoconvert_default() {
        var c = ElementFactory.make("videoconvert", null);
        c.set("chroma-mode",  Gst.Video.ChromaMode.NONE);
        c.set("dither", Gst.Video.DitherMethod.NONE);
        c.set("matrix-mode", Gst.Video.MatrixMode.OUTPUT_ONLY);
        c.set("n-threads", 5);
        return c;
    }

    Gst.Element? pipewiresrc_default(int fd, uint32 path) {
        var registry = Registry.get();
        var needs_copy =  (registry.check_feature_version("pipewiresrc", 0, 3, 57)
                           && !registry.check_feature_version("videoconvert", 1, 20, 4));
        stderr.printf("needs copy %s\n", needs_copy.to_string());
        var src = ElementFactory.make("pipewiresrc", null);
        src.set("fd", fd);
        src.set("path", path.to_string());
        src.set("do-timestamp", true);
        src.set("keepalive-time", 1000);
        src.set("resend-last", true);
        src.set("always-copy", needs_copy);
        return src;
    }

    Gst.Bin? pulsesrc_bin(ScreenCap.Options o) {
        var bin = new Gst.Bin(null);
        var audiomixer = ElementFactory.make("audiomixer", null);
        var audiorate = ElementFactory.make("audiorate", null);
        var audioconvert = ElementFactory.make("audioconvert", null);
        var queue = ElementFactory.make("queue", null);
        var sample_rate_filter = new Caps.simple("audio/x-raw", "rate", typeof(int), o.audiorate);
        stderr.printf("sample filter %s\n",  sample_rate_filter.to_string());
        bin.add_many(audiomixer, audiorate, audioconvert, queue);

        var ret = audiomixer.link_filtered(audiorate, sample_rate_filter);
        if (ret == false) {
            stderr.printf("audiomixer link fails\n");
            return null;
        }

        if (audiorate.link_many(audioconvert, queue) == false) {
            stderr.printf("audiorate link fails\n");
            return null;
        }
        stderr.printf("audio name %s\n", o.adevice);
        var pulsesrc = ElementFactory.make("pulsesrc", null);
        pulsesrc.set("device", o.adevice);
        pulsesrc.set("provide-clock", false);
        var audioresample = ElementFactory.make("audioresample", null);
        var capsfilter = ElementFactory.make("capsfilter", null);
        capsfilter.set("caps", sample_rate_filter);
        bin.add_many(pulsesrc, audioresample, capsfilter);
        if (pulsesrc.link_many(audioresample, capsfilter) == false) {
            stderr.printf("pulsesrc link fails\n");
            return null;
        }
        var audiomixer_sink_pad = audiomixer.request_pad_simple("sink_%u");
        var cfp = capsfilter.get_static_pad("src");
        var ret3 = cfp.link(audiomixer_sink_pad);
        if (ret3 != Gst.PadLinkReturn.OK) {
            stderr.printf("capsfilter link result is %s\n", ret3.to_string());
            return null;
        }
        var queue_pad = queue.get_static_pad("src");
        bin.add_pad(new GhostPad("src", queue_pad));
        return bin;
    }

    Gst.Bin? pipewiresrc_bin(ScreenCap.Options o, GenericArray<PortalManager.SourceInfo?>si) {
        var bin = new Gst.Bin(null);
        var compositor =  ElementFactory.make("compositor", null);
        var videoconvert = videoconvert_default();
        var queue = ElementFactory.make("queue", null);
        bin.add_many(compositor, videoconvert, queue);
        if (compositor.link(videoconvert) == false) {
            stderr.printf("comp link fails\n");
            return null;
        }

        if (!o.fullscreen) {
            var videoscale = ElementFactory.make("videoscale", null);
            var videocrop = ElementFactory.make("videocrop", null);

            var right = si[0].width - o.selinfo.x1;
            var bottom = si[0].height - o.selinfo.y1;
			var left = o.selinfo.x0;
			var top = o.selinfo.y0;

            stderr.printf("crop: left %d, top %d, right %d bottom %d scale %f\n",
                          left, top, right, bottom, si[0].scale);

			var w =  si[0].width;
			var h = si[0].height;

			if(si[0].scale > 1.0) {
				right = (int) (right*si[0].scale);
				left = (int) (left*si[0].scale);
				top= (int) (top*si[0].scale);
				bottom = (int) (bottom*si[0].scale);
				w = (int) (w*si[0].scale);
				h = (int) (h*si[0].scale);
			}

            videocrop.set("top", top);
            videocrop.set("left", left);
            videocrop.set("right", right);
            videocrop.set("bottom", bottom);
            var videoscale_filter = new Caps.simple("video/x-raw",
                                                    "width", typeof(int), w,
                                                    "height", typeof(int), h);
            stderr.printf("videoscale_filter %s\n",  videoscale_filter.to_string());
            bin.add_many(videoscale, videocrop);
            if (videoconvert.link(videoscale) == false) {
                stderr.printf("conv link fails\n");
                return null;
            }
            if (videoscale.link_filtered(videocrop, videoscale_filter) == false) {
                stderr.printf("scale link fails\n");
                return null;
            }
            if (videocrop.link(queue) == false) {
                stderr.printf("crop link fails\n");
                return null;
            }
        } else {
            if (videoconvert.link(queue) == false) {
                stderr.printf("vidconv link fails\n");
                return null;
            }
        }

        var videorate_filter = new Caps.simple("video/x-raw", "framerate", typeof (Fraction),
                                               o.framerate, 1);
        int last_pos = 0;
        var link_ok = true;
        si.foreach((s) => {
                var pipewiresrc =  pipewiresrc_default(o.fd, s.node_id);
                var videorate = ElementFactory.make("videorate", null);
                var videorate_capsfilter = ElementFactory.make("capsfilter", null);
                videorate_capsfilter.set("caps", videorate_filter);
                bin.add_many(pipewiresrc, videorate, videorate_capsfilter);
                if ((link_ok = pipewiresrc.link_many(videorate, videorate_capsfilter)) == false) {
                    stderr.printf("pipewiresrc link fails\n");
                    return;
                }
                var compositor_sink_pad = compositor.request_pad_simple("sink_%u");
                compositor_sink_pad["xpos"] = last_pos;
                var vcf = videorate_capsfilter.get_static_pad("src");
                var vcfret = vcf.link(compositor_sink_pad);
                if (vcfret != Gst.PadLinkReturn.OK) {
                    stderr.printf("vcf link result is %s\n", vcfret.to_string());
                    link_ok = false;
                    return;
                }
                last_pos += (int) (s.width*s.scale);
            });
        if (link_ok) {
            var queue_pad = queue.get_static_pad("src");
            bin.add_pad(new GhostPad("src", queue_pad));
            return bin;
        } else {
            return null;
        }
    }

    Gst.Bin? x11src_bin(ScreenCap.Options o) {
        var display = Environment.get_variable("DISPLAY");
        if (display == null) {
            display = ":0";
        }
        var bin = new Gst.Bin(null);
        var queue = ElementFactory.make("queue", null);
        var videoconvert = videoconvert_default();
        var x11src = ElementFactory.make("ximagesrc", null);
        x11src.set("display-name", display);
        x11src.set("show-pointer", o.capmouse);
        x11src.set("use-damage", true);
        if (! o.fullscreen) {
            x11src.set("startx", o.selinfo.x0);
            x11src.set("starty", o.selinfo.y0);
            x11src.set("endx", o.selinfo.x1+1);
            x11src.set("endy", o.selinfo.y1+1);
        }
        var rate_filter = new Caps.simple("video/x-raw", "framerate",
                                          typeof(Fraction), o.framerate, 1);
        var capsfilter = ElementFactory.make("capsfilter", null);
        capsfilter.set("caps", rate_filter);

        bin.add_many(x11src, capsfilter, videoconvert, queue);
        if (x11src.link_many(capsfilter, videoconvert, queue) == false) {
            stderr.printf("Failed to link X11 elements");
            return null;
        }

        var queue_pad = queue.get_static_pad("src");
        bin.add_pad(new GhostPad("src", queue_pad));
        return bin;
    }

    public Gst.Pipeline? generate_pipeline(ScreenCap.Options o,
                                           GenericArray<PortalManager.SourceInfo?> sis,
                                           out string fname) {
        fname = "";
        pipeline = new Pipeline ("pipeline");
        queue = ElementFactory.make ("queue", null);
        var profile = Encoders.find(o.mediatype);
        if (profile == null) {
            return null;
        }
        var fsink = ElementFactory.make ("filesink", null);
        fname = generate_file_name(o.dirname, profile.extn);
        fsink.set("location", fname);
        pipeline.add_many(queue, fsink);
        if (queue.link (fsink) != true) {
            stderr.puts ("Elements could not be linked.\n");
            return null;
        }

        videosrc_bin = (o.fd != -1) ? pipewiresrc_bin(o, sis) : x11src_bin(o);
        if (videosrc_bin == null) {
            return null;
        }
        pipeline.add(videosrc_bin);

        if (o.capaudio) {
            audiosrc_bin =  pulsesrc_bin(o);
            if (audiosrc_bin != null) {
                pipeline.add(audiosrc_bin);
            } else {
                stderr.printf("Not adding audio pipeline\n");
            }
        }
        if (pipeline != null) {
            if (finalise_pipeline(profile) == false) {
                pipeline = null;
            }
        }
        return pipeline;
    }

    string generate_file_name(string dirname, string extn) {
        time_t currtime;
        time_t(out currtime);
        var fn  = "Wayfarer_%s".printf(Time.local(currtime).format("%F_%H%M%S"));
        var filepath = string.join(".", fn, extn);
        return Path.build_filename (dirname, filepath);
    }

    public bool finalise_pipeline (Encoders.EProfile ep) {
        var cp = Encoders.get_container_profile(ep);
        var ebin = Gst.ElementFactory.make ("encodebin", null);
        ebin.set("profile", cp);
        pipeline.add(ebin);
        var vsp =  videosrc_bin.get_static_pad("src");
        var espv = ebin.request_pad_simple("video_%u");
        var ret = vsp.link(espv);
        if (ret !=  Gst.PadLinkReturn.OK) {
            stderr.printf("videosrc link result %s\n", ret.to_string());
            return false;
        }
        if (audiosrc_bin != null) {
            var asp = audiosrc_bin.get_static_pad("src");
            var espa = ebin.request_pad_simple("audio_%u");
            ret = asp.link(espa);
            if (ret !=  Gst.PadLinkReturn.OK) {
                stderr.printf("audiosrc link %s\n", ret.to_string());
                return false;
            }
        }
        if (ebin.link(queue) == false) {
            stderr.printf("encoderbin link to queue fails\n");
            return false;
        }
        return true;
    }
}
