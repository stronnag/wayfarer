using Gtk;
using Gst;

public class Wayfarer : Gtk.Application {
    private enum PWAction {
        NONE,
        SET_AREA,
        START_RECORDING,
    }

    public enum PWSession {
        X11,
        WAYLAND,
    }

    Gtk.ApplicationWindow window;
    private ScreenCap sc;
    private uint8 have_area;
    private string filename;
    private Conf conf;
    private Notify nt;
    private uint timerid;
    private uint runtimerid;
    private Gtk.CheckButton fullscreen;
    private Gtk.Entry fileentry;
    private Gtk.Button startbutton;
    private Gtk.Label statuslabel;
	private PortalManager pw;
	private Button dirchooser;
	private DropDown mediasel;
	private Window stopwindow;
    private Gtk.Label runtimerlabel;
    private Gtk.SpinButton framerate;
    private DropDown audiosource;
    private CheckButton audiorecord;
    private CheckButton mouserecord;
    private SpinButton delayspin;
    private SpinButton recordtimer;

    private PortalManager.Result pw_result;
    private PWAction pw_action;
    private PWSession pw_session;
	private int fd;
    GenericArray<PortalManager.SourceInfo?> sources;
    private bool ctrlseta;
    private bool ctrlsets;
    private bool stophide;
	private bool forced;

    public static bool show_version;
    public static bool two_is_one;

	private ScreenCap.AudioSource[] audios;

	private AreaWindow sw;

    const OptionEntry[] options = {
        { "my-portal-is-broken", 0, 0, OptionArg.NONE, out two_is_one, "workaround broken portal", null},
        { "version", 'v', 0, OptionArg.NONE, out show_version, "show version", null},
        {null}
    };

    public Wayfarer () {
        GLib.Object(application_id: "org.stronnag.wayfarer",
               flags:ApplicationFlags.FLAGS_NONE);
    }

    protected override void activate () {
        fd = -1;
		if(active_window == null) {
			present_window();
		}
	}

    private void present_window() {
        uint validaudio = Gtk.INVALID_LIST_POSITION;
        var builder = new Builder.from_resource("/org/stronnag/wayfarer/wayfarer.ui");
        window = builder.get_object ("window") as Gtk.ApplicationWindow;
        this.add_window (window);
        window.set_application (this);

        window.close_request.connect( () => {
				clean_up();
				return false;
            });

        fullscreen  =  builder.get_object("fullscreen") as CheckButton;
        fileentry = builder.get_object("filename") as Entry;
        startbutton = builder.get_object("startbutton") as Button;
        statuslabel = builder.get_object("statuslabel") as Label;
        runtimerlabel = builder.get_object("runtimer") as Label;

        dirchooser = builder.get_object("dirchooser") as Button;
		var dirlabel = builder.get_object("dirlabel") as Label;
        audiosource = builder.get_object("audiosource") as DropDown;
        audiorecord =  builder.get_object("audiorecord") as CheckButton;
        mouserecord =  builder.get_object("mouserecord") as CheckButton;
        framerate = builder.get_object("framerate") as SpinButton;
        delayspin = builder.get_object("delay") as SpinButton;
        recordtimer = builder.get_object("recordtimer") as SpinButton;

        Gtk.Button areabutton = builder.get_object("areabutton") as Button;

        Gtk.AboutDialog about = builder.get_object ("wayfarerabout") as Gtk.AboutDialog;
        Gtk.Window prefs = builder.get_object ("wayfarerprefs") as Gtk.Window;
        Gtk.Button prefapply = builder.get_object("prefsapply") as Button;
        CheckButton prefs_not =  builder.get_object("prefs_not") as CheckButton;
        CheckButton prefs_notall =  builder.get_object("prefs_notall") as CheckButton;
        CheckButton prefs_hint =  builder.get_object("prefs_hint") as CheckButton;
		Gtk.Entry prefs_audiorate = builder.get_object("prefs_audiorate") as Entry;
		mediasel = builder.get_object("media_sel") as DropDown;

        var evtka = new GestureClick();
        evtka.set_propagation_phase(PropagationPhase.CAPTURE);
        evtka.set_exclusive(true);
        ((Gtk.Widget)areabutton).add_controller(evtka);

        evtka.pressed.connect((n, x, y) => {
                var e = evtka.get_last_event(null);
                if(e != null) {
                    var mt = e.get_modifier_state();
                    ctrlseta = ((mt & Gdk.ModifierType.CONTROL_MASK) != 0);
                }
            });

        var evtks = new GestureClick();
        evtks.set_propagation_phase(PropagationPhase.CAPTURE);
        evtks.set_exclusive(true);
        ((Gtk.Widget)startbutton).add_controller(evtks);

        evtks.pressed.connect((n, x, y) => {
                var e = evtks.get_last_event(null);
                if(e != null) {
                    var mt = e.get_modifier_state();
                    ctrlsets = ((mt & Gdk.ModifierType.CONTROL_MASK) != 0);
                }
            });

        Utils.setup_css(startbutton);
        pw_result = PortalManager.Result.UNKNOWN;

        pw_session = (Environment.get_variable("XDG_SESSION_TYPE") == "wayland") ? PWSession.WAYLAND : PWSession.X11;

		if (pw_session == PWSession.WAYLAND) {
			var dmc = Environment.get_variable("XDG_CURRENT_DESKTOP");
			if (dmc != null && dmc == "wlroots") {
				two_is_one = true;
				stderr.printf("*DBG* wlroots detected, setting `two_is_one` flag portal workaround\n");
			}
		}

        conf = new Conf();

        uint mediaset = Gtk.INVALID_LIST_POSITION;
		StringList sl = new StringList(null);

		mediasel.model = sl;
		int n = 0;
        foreach (var e in Encoders.list_profiles()) {
            if (e.is_valid) {
                sl.append(e.pname);
                if (mediaset == Gtk.INVALID_LIST_POSITION) {
                    mediasel.selected = n;
                    print("initial %s\n", e.name);
                    mediaset = n;
                }
                if (e.name == conf.media_type) {
                    mediasel.selected = n;
                }
				n++;
            }
        }

        stopwindow = builder.get_object("stopwindow") as Window;
        stopwindow.set_icon_name("wayfarer");

		var stoprecbutton = builder.get_object("stoprecbutton") as Button;
		stopwindow.close_request.connect(() => {
				return true;
			});

		stoprecbutton.clicked.connect(() => {
				do_stop_action();
			});

        about.version = "%s (%s)".printf(WAYFARER_VERSION_STRING, WAYFARER_GITVERS);
		about.set_transient_for(window);
		about.modal = true;
		about.authors = {"Jonathan Hudson <jh+github@daria.co.uk>"};

        stderr.printf("Version Info: v%s (%s, %s, %s)\n", WAYFARER_VERSION_STRING,
                      WAYFARER_GITVERS, WAYFARER_GITBRANCH, WAYFARER_GITSTAMP);

        stderr.printf("Build Info: %s, %s\n", BUILDINFO, COMPINFO);

		prefs.set_transient_for(window);
		prefs.modal = true;
		var pstuff = builder.get_object ("prefsstuff") as Gtk.Box;
		prefs.set_child(pstuff);

        about.close_request.connect (() => {
                about.hide();
                return true;
            });

        prefs.close_request.connect (() => {
                prefs.hide();
                return true;
            });

        prefapply.clicked.connect(() => {
                conf.notify_start = prefs_not.active;
                conf.notify_stop = prefs_notall.active;
                conf.show_hint = prefs_hint.active;
				conf.audio_rate = int.parse(prefs_audiorate.text);
                prefs.hide();
            });

		dirchooser.clicked.connect(() => {
				Utils.get_video_directory.begin(conf.video_dir, (o,r) => {
						conf.video_dir  = Utils.get_video_directory.end(r);
						dirlabel.label = Path.get_basename(conf.video_dir);

					});
			});

        var saq = new GLib.SimpleAction("quit",null);
        saq.activate.connect(() => {
                clean_up();
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("prefs",null);
        saq.activate.connect(() => {
                prefs.present();
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("about",null);
        saq.activate.connect(() => {
                about.show();
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("nopersist",null);
        if (pw_session == PWSession.WAYLAND) {
            saq.activate.connect(() => {
                    stderr.printf("Clearing token\n");
                    conf.restore_token = "";
                    pw.set_token(null);
            });
        } else {
            saq.set_enabled(false);
        }
        window.add_action(saq);

		set_accels_for_action ("win.nopersist", {"<Ctrl>r"});
		set_accels_for_action ("win.quit", {"<Ctrl>q"});
		set_accels_for_action ("win.about", { "F1" });
		set_accels_for_action ("win.prefs", {"<Ctrl>p"});

        set_start_active(false);

        fullscreen.toggled.connect(() => {
                update_status_label();
                if (pw_session == PWSession.WAYLAND) {
                    if (Gdk.Display.get_default().get_monitors().get_n_items() > 1) {
                        conf.restore_token = ""; // may wish to select different monitor ...
                        pw.set_token(null);
                        set_start_active(false);
                    }
                }
            });

        window.set_icon_name("wayfarer");

        sc = new ScreenCap();
		sc.stream_ended.connect(() => {
				cleanup_session();
			});

        startbutton.clicked.connect(() => {
				forced = false;
				stderr.printf("*DBG* Start with %s %d\n", pw_session.to_string(), fd);
				if(pw_session == PWSession.X11 || fd > 0) {
                    start_recording(validaudio);
                } else {
					stderr.printf("*DBG* Need acquire %d\n", fd);
                    pw_action = START_RECORDING;
                    pw.acquire(mouserecord.active);
                }
            });

		sc.report_gst_error.connect((s) => {
				do_stop_action();
				statuslabel.label = s;
				if(forced) {
					cleanup_session();
				}
			});

        audios = sc.get_audio_sources();
		StringList asl = new StringList(null);

		audiosource.model = asl;
		foreach (var a in audios) {
            asl.append(a.desc);
        }

        if(audios.length == 0) {
            stderr.puts("No audio sources found\n");
        } else {
            if(conf.audio_device.length > 4) {
				int na = 0;
				foreach(var a in audios) {
                    if (a.desc == conf.audio_device) {
                        audiosource.selected = na;
                        validaudio = na;
                        break;
                    }
					na++;
                }
            }
            if (validaudio == Gtk.INVALID_LIST_POSITION) {
                audiosource.selected = 0;
                validaudio = 0;
            }
        }

        Unix.signal_add(Posix.Signal.USR1, () => {
                do_stop_action();
                return Source.CONTINUE;
            });

        prefs_audiorate.text = conf.audio_rate.to_string();

        framerate.set_value(conf.frame_rate);
        framerate.value_changed.connect(() => {
                conf.frame_rate = (uint32)framerate.value;
            });

		if(conf.video_dir != null) {
			dirlabel.label = Path.get_basename(conf.video_dir);
		}

		if(filename != null)
            fileentry.text = filename;

        prefs_not.active = conf.notify_start;
        prefs_notall.active = conf.notify_stop;
        prefs_hint.active = conf.show_hint;

        sources = new GenericArray<PortalManager.SourceInfo?>();
		var fake_sources = new GenericArray<PortalManager.SourceInfo?>();
		Utils.fake_sources(ref fake_sources);
        if(pw_session == PWSession.WAYLAND) {
            pw = new PortalManager(conf.restore_token);
            pw.closed.connect(() => {
                    stderr.printf("Portal cancelled / closed remotely [%d]\n", fd);
					forced = true;
					do_stop_action();
                });

            pw.completed.connect((result) => {
                    pw_result = result;
                    if (pw_action == PWAction.SET_AREA) {
                        if(result == PortalManager.Result.OK) {
                            var ci = pw.get_cast_info();
                            if (ci.fd > -1  && ci.sources.length > 0 ) {
								for(var js = 0; js < ci.sources.length; js++) {
									ci.sources[js].scale = fake_sources[js].scale;
								}
								fd = ci.fd;
                                sources = ci.sources;
                                if (sources[0].source_type == 1 || sources[0].source_type == 0 || (two_is_one && sources[0].source_type == 2)) {
                                    run_area_selection();
                                } else {
                                    have_area = 2;
                                    update_status_label();
                                }
                            }
                            set_start_active(validate_start());
                        }
                    } else {
                        start_recording(validaudio);
                    }
                });
        } else {
			sources = fake_sources;
        }

        areabutton.clicked.connect(() => {
                if (pw_session == PWSession.X11) {
                    run_area_selection();
                } else {
                    sources.remove_range(0,sources.length);
                    pw_action = PWAction.SET_AREA;
                    pw.acquire(mouserecord.active);
                }
            });

        nt = new Notify();
        nt.on_action(() => {
                if(conf.notify_stop)
                    do_stop_action();
            });
        window.show ();
    }

    private void start_recording(uint validaudio) {
        sc.options.capaudio = (validaudio == Gtk.INVALID_LIST_POSITION)  ? false : audiorecord.active;
        sc.options.capmouse = mouserecord.active;
        conf.frame_rate = framerate.get_value_as_int();
        sc.options.framerate = (int)conf.frame_rate;
        sc.options.audiorate = (int)conf.audio_rate;

		uint na = audiosource.selected;
		conf.audio_device = audios[na].device;
		sc.options.adevice = (sc.options.capaudio) ? conf.audio_device : null;
        sc.options.fd = fd;
        sc.options.fullscreen = fullscreen.active;
        sc.options.dirname = conf.video_dir;

		uint nm = mediasel.selected;
        sc.options.mediatype = Encoders.get_all()[nm].name;

		if (conf.video_dir.length > 0) {
            try {
                var file = File.new_for_path(conf.video_dir);
                file.make_directory_with_parents();
            } catch {}
        }

        window.hide();

        if (!conf.notify_stop) {
			if (!conf.no_pop) {
				runtimerlabel.label = "00:00";
				stopwindow.present();
				if(ctrlsets) {
					stopwindow.hide();
					stophide = false;
				}
			}
        }

        var delay = delayspin.get_value();

        if(conf.notify_start || conf.notify_stop) {
            if(delay < 2) {
                nt.send_notification("Ready to record", "Click me to stop", (conf.notify_stop) ? 0 :1000);
            } else {
                var ctr = (int)(delay);
                var str = "Starting in %ds\n".printf(ctr);
                nt.send_notification("Ready to record", str, (conf.notify_stop)? 0 :1000);
                ctr--;
                Timeout.add_seconds(1, () => {
                        str = "Starting in %ds\n".printf(ctr);
                        nt.send_notification("Ready to record", (ctr>1) ? str : "Close me to stop", (conf.notify_stop)? 0 :1000);
                        ctr--;
                        if(ctr <= 0)
                            return Source.REMOVE;
                        else
                            return Source.CONTINUE;
                    });
            }
        }

        Timeout.add((uint)(1000*delay), () => {
                var runtime = recordtimer.get_value_as_int();
                if(runtime > 0) {
                    timerid = Timeout.add_seconds(runtime, () => {
                            do_stop_action();
                            return Source.REMOVE;
                        });
                }
                if(!conf.notify_stop)
                    nt.close_last();
                var res = sc.capture(sources, out filename);
                if (res) {
                    fileentry.text = filename;
                    if (!conf.notify_stop) {
                        var rt = new Timer();
                        runtimerid = Timeout.add_seconds(1, () => {
                                var secs = (int)rt.elapsed(null);
                                runtimerlabel.label = "%02d:%02d".printf(secs / 60, secs % 60);
                                return true;
                            });
                    }
                } else {
                    if(timerid > 0) {
                        Source.remove(timerid);
                        timerid = 0;
                    }
                    statuslabel.label = "Failed to record";
                    window.show();
                }
                return Source.REMOVE;
            });
    }

    private void run_area_selection() {
		if (!fullscreen.active) {
            if(ctrlseta) {
                window.hide();
            }
            sw = new AreaWindow (conf.show_hint);
            sw.area_set.connect((x0, y0, x1, y1) => {
                    var swh = sw.get_height();
                    var offset = sources[0].height - swh;
                    if(offset != 0){
                        y0 += offset;
                        y1 += offset;
                    }
                    if (x0 < sources[0].x) {
                        x0 = sources[0].x;
                    }
                    int w =0;
                    sources.foreach((s) => {
                            w += s.width;
                        });
                    if (x1 > w) {
                        x1 = w -1;
                    }
                    if (y0 < 0) {
                        y0 = 0;
                    }
                    if (y1 >= sources[0].height) {
                        y1 = sources[0].height-1;
                    }
                    sc.set_bbox(x0, y0, x1, y1);
                    string astr = "(%d %d) (%d %d)".printf(sc.options.selinfo.x0,
                                                           sc.options.selinfo.y0,
                                                           sc.options.selinfo.x1,
                                                           sc.options.selinfo.y1);
//                    stderr.printf("dbg: %s\n", astr);

					if (x0 != -1 && x1 != -1) {
                        have_area = 1;
                        update_status_label(astr);
                    } else {
                        have_area = 0;
                        update_status_label();
                    }
                    sw.destroy();
                    sw = null;
                    window.show();
			});

            sw.area_quit.connect(() => {
                    sw.destroy();
                    sw = null;
                    window.show();
                });
            sw.run (pw_session, sources);
        }
    }

    private bool validate_start() {
        bool valid = (fullscreen.active || have_area > 0);
        if(pw_session == PWSession.WAYLAND) {
            valid = valid && (fd > 0);
        }
        return valid;
    }

    private void update_status_label(string? astr=null) {
        StringBuilder sb = new StringBuilder();
		if (!fullscreen.active) {
			switch(have_area) {
			case 0:
				sb.append("Set area or select full screen");
				break;
			case 1:
				sb.append_printf("Area: %s", astr);
				break;
			case 2:
				sb.append("Window");
				break;
			}
		} else {
			sb.append("Full screen");
		}
		statuslabel.label=sb.str;
		set_start_active(validate_start());
    }

    private void set_start_active(bool act) {
		startbutton.set_name((act) ? "recsel" : "recdef");
        startbutton.sensitive = act;
    }

    private void do_stop_action() {
        if(timerid > 0) {
            Source.remove(timerid);
            timerid = 0;
        }
        if(runtimerid > 0) {
            Source.remove(runtimerid);
            runtimerid = 0;
        }
        nt.close_last();
		stopwindow.hide();
        window.show();
        sc.post_process();
    }


	private void cleanup_session() {
		if(pw_session == PWSession.WAYLAND && pw_result == PortalManager.Result.OK) {
			stderr.printf("*DBG* pw.close\n");
			pw.close();
		}
		if(fd != -1) {
			stderr.printf("*DBG* close FD %d\n", fd);
			Posix.close(fd);
			fd = -1;
		}
		have_area = 0;
		set_start_active(false);
		update_status_label();
		if(forced && sc.options.mediatype == "mp4" && conf.no_pop == false) {
			stderr.printf("delete %s on forced close\n", filename);
			statuslabel.label = "mp4 file deleted on forced close";
			Posix.unlink(filename);
		}
	}

	private void clean_up() {
		uint nm =mediasel.selected;
		if (nm != Gtk.INVALID_LIST_POSITION) {
			var str = Encoders.get_all()[nm].name;
			conf.media_type = str;
		}
		uint na = audiosource.selected;
		if (nm != Gtk.INVALID_LIST_POSITION) {
			conf.audio_device = audios[na].desc;
		}
		save_config();
        quit();
    }

    private void save_config() {
        conf.frame_rate = framerate.get_value_as_int();
        if(pw_session == PWSession.WAYLAND) {
            var t = pw.get_token();
            if (t == null) {
                t = "";
            }
            conf.restore_token = t;
        }
        GLib.Settings.sync();
    }

    public static int main (string[] args) {
        Gst.init(ref args);
        Encoders.Init();

        var opt = new OptionContext("");
        try {
            opt.set_summary("wayfarer %s".printf(WAYFARER_VERSION_STRING));
            opt.set_help_enabled(true);
            opt.add_main_entries(options, null);
            opt.parse(ref args);
        } catch (OptionError e) {
            stderr.printf("Error: %s\n", e.message);
            stderr.printf("Run '%s --help' to see a full list of available options\n", args[0]);
            return 1;
        }
        if (show_version) {
            stdout.printf("%s\n", WAYFARER_VERSION_STRING);
            return 0;
        }
        Wayfarer app = new Wayfarer ();
        return app.run (args);
    }
}
