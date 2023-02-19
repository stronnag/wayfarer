using Gtk;
using Gst;

public class MyApplication : Gtk.Application {
    Gtk.ApplicationWindow window;
    private ScreenCap sc;
    private uint8 have_area;
    private string filename;

    private string dirname;
    private string audioid;
    private int audiorate;
	private string msel;
    private bool use_not;
    private bool use_notall;

    private Notify nt;
    private uint timerid;
    private uint runtimerid;
    private Gtk.CheckButton fullscreen;
    private Gtk.Entry fileentry;
    private Gtk.Button startbutton;
    private Gtk.Label statuslabel;
	private PortalManager pw;
	private Button dirchooser;
	private ComboBoxText mediasel;
	private Window stopwindow;
    private Gtk.Label runtimerlabel;

	private int fd;
    GenericArray<PortalManager.SourceInfo?> sources;

    public static bool show_version;

	private AreaWindow sw;

    const OptionEntry[] options = {
        { "version", 'v', 0, OptionArg.NONE, out show_version, "show version", null},
        {null}
    };

    public MyApplication () {
        GLib.Object(application_id: "org.stronnag.wayfarer",
               flags:ApplicationFlags.FLAGS_NONE);
    }

    protected override void activate () {
        fd = -255;
        audiorate = 48000;
		if(active_window == null) {
			present_window();
		}
	}

    private void present_window() {
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
        ComboBoxText audiosource = builder.get_object("audiosource") as ComboBoxText;
        CheckButton audiorecord =  builder.get_object("audiorecord") as CheckButton;
        CheckButton mouserecord =  builder.get_object("mouserecord") as CheckButton;
        SpinButton framerate = builder.get_object("framerate") as SpinButton;
        SpinButton delayspin = builder.get_object("delay") as SpinButton;
        SpinButton recordtimer = builder.get_object("recordtimer") as SpinButton;
        Gtk.Button areabutton = builder.get_object("areabutton") as Button;

        Gtk.AboutDialog about = builder.get_object ("wayfarerabout") as Gtk.AboutDialog;
        Gtk.Dialog prefs = builder.get_object ("wayfarerprefs") as Gtk.Dialog;
        Gtk.Button prefapply = builder.get_object("prefsapply") as Button;
        CheckButton prefs_not =  builder.get_object("prefs_not") as CheckButton;
        CheckButton prefs_notall =  builder.get_object("prefs_notall") as CheckButton;
		Gtk.Entry prefs_audiorate = builder.get_object("prefs_audiorate") as Entry;
		mediasel = builder.get_object("media_sel") as ComboBoxText;

        foreach (var e in Encoders.list_profiles()) {
            if (e.is_valid) {
                mediasel.append(e.name, e.pname);
            }
        }

        stopwindow = builder.get_object("stopwindow") as Window;
		var stoprecbutton = builder.get_object("stoprecbutton") as Button;
		stopwindow.close_request.connect(() => {
				return true;
			});

		stoprecbutton.clicked.connect(() => {
				do_stop_action();
			});

        about.version = WAYFARER_VERSION_STRING;
		about.set_transient_for(window);
		about.modal = true;
		about.authors = {"Jonathan Hudson <jh+github@daria.co.uk>"};

		prefs.set_transient_for(window);
		prefs.modal = true;
		var pbox = prefs.get_content_area();
		var pstuff = builder.get_object ("prefsstuff") as Gtk.Box;
		pbox.append(pstuff);

        about.close_request.connect (() => {
                about.hide();
                return true;
            });

        prefs.close_request.connect (() => {
                prefs.hide();
                return true;
            });

        prefapply.clicked.connect(() => {
                use_not = prefs_not.active;
                use_notall = prefs_notall.active;
				audiorate = int.parse(prefs_audiorate.text);
                prefs.hide();
            });

		dirchooser.clicked.connect(() => {
				Gtk.FileChooserDialog fc = new Gtk.FileChooserDialog (
					"Video Directory",
					active_window, Gtk.FileChooserAction.SELECT_FOLDER,
					"_Cancel",
					Gtk.ResponseType.CANCEL,
					"_Select",
					Gtk.ResponseType.ACCEPT);

				try {
					fc.set_current_folder(File.new_for_path(dirname));
				} catch {}

				fc.response.connect((result) => {
						if (result== Gtk.ResponseType.ACCEPT) {
							dirname = fc.get_file().get_path ();
							dirlabel.label = Path.get_basename(dirname);
						}
						fc.close();
					});
				fc.present();
			});

        var saq = new GLib.SimpleAction("quit",null);
        saq.activate.connect(() => {
                clean_up();
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("prefs",null);
        saq.activate.connect(() => {
                prefs.show();
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("about",null);
        saq.activate.connect(() => {
                about.show();
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("nopersist",null);
        saq.activate.connect(() => {
				pw.invalidate();
            });
        window.add_action(saq);

		set_accels_for_action ("win.nopersist", {"<Ctrl><Shift>p"});
		set_accels_for_action ("win.quit", {"<Ctrl>q"});
		set_accels_for_action ("win.about", { "F1" });
		set_accels_for_action ("win.prefs", {"<Ctrl>p"});

        startbutton.sensitive = false;

        fullscreen.toggled.connect(() => {
                update_status_label();
            });

        window.set_icon_name("wayfarer");

        sc = new ScreenCap();

        startbutton.clicked.connect(() => {
                sc.options.capaudio = audiorecord.active;
                sc.options.capmouse = mouserecord.active;
                sc.options.framerate = framerate.get_value_as_int();
                sc.options.audiorate = audiorate;
                sc.options.adevice = audiosource.active_id;
				sc.options.fd = fd;
                sc.options.mediatype = mediasel.active_id;
                sc.options.fullscreen = fullscreen.active;
                sc.options.dirname = dirname;

                window.hide();

                if (!use_notall) {
                    runtimerlabel.label = "00:00";
                    stopwindow.present();
                }

                var delay = delayspin.get_value();

                if(use_not || use_notall) {
                    if(delay < 2) {
                        nt.send_notification("Ready to record", "Click me to stop", (use_notall) ? 0 :1000);
                    } else {
                        var ctr = (int)(delay);
                        var str = "Starting in %ds\n".printf(ctr);
                        nt.send_notification("Ready to record", str, (use_notall)? 0 :1000);
                        ctr--;
                        Timeout.add_seconds(1, () => {
                                str = "Starting in %ds\n".printf(ctr);
                                nt.send_notification("Ready to record", (ctr>1) ? str : "Close me to stop", (use_notall)? 0 :1000);
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
                        if(!use_notall)
                            nt.close_last();
                        var res = sc.capture(sources, out filename);
                        if (res) {
                            fileentry.text = filename;
                            if (!use_notall) {
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
            });

		sc.report_gst_error.connect((s) => {
				do_stop_action();
				statuslabel.label = s;
			});

        var at = sc.get_sources();
        foreach (var a in at) {
            audiosource.append(a.device,a.desc);
        }

        if(at.length == 0) {
            stderr.puts("No audio sources found\n");
            quit();
			audiorecord.active = false;
        }

		sw = new AreaWindow ();
		sw.area_set.connect((x0, y0, x1, y1) => {
				sc.set_bbox(x0, y0, x1, y1);
                string astr = "(%d %d) (%d %d)".printf(sc.options.selinfo.x0,
                                                       sc.options.selinfo.y0,
                                                       sc.options.selinfo.x1,
                                                       sc.options.selinfo.y1);
				if (x0 != -1 && x1 != -1) {
					have_area = 1;
					update_status_label(astr);
				} else {
					have_area = 0;
					update_status_label();
				}
				sw.hide();
			});

		Unix.signal_add(Posix.Signal.USR1, () => {
                do_stop_action();
                return Source.CONTINUE;
            });

		use_notall = true;
		mediasel.active_id = "webm";  // "simple, fast"

        pw = new PortalManager(null);
        read_config();

		prefs_audiorate.text = audiorate.to_string();

		if (msel != null) {
			mediasel.active_id = msel;
		}

		if(dirname != null) {
			dirlabel.label = Path.get_basename(dirname);
		}

		if(filename != null)
            fileentry.text = filename;

		if(audioid != null && audioid.length > 4) {
			audiosource.active_id = audioid;
		} else {
			audiosource.active = 0;
		}
        prefs_not.active = use_not;
        prefs_notall.active = use_notall;

        audiosource.changed.connect(() => {
                audioid = audiosource.active_id;
            });

        sources = new GenericArray<PortalManager.SourceInfo?>();

        bool is_x11 = (Environment.get_variable("XDG_SESSION_TYPE") == "x11");

        pw.complete.connect((_fd) => {
                fd = _fd;
                if (sources.length > 1) {
                    sources.sort((a,b) => {
                            return (int)(a.x > b.x) - (int)(a.x < b.x);
                        });
                }
                if (fd > -1  && sources.length > 0 ) {
                    if (sources[0].source_type == 1 || sources[0].source_type == 0) {
                        run_area_selection();
                    } else {
                        have_area = 2;
                        update_status_label();
                    }
                } else if (fd == -1) {
                    if (is_x11) {
                        run_area_selection();
                    } else {
                        statuslabel.label = "Failed run XDG Portal";
                    }
                }
                startbutton.sensitive = validate_start();
            });
        pw.source_info.connect((s) => {
                sources.add(s);
            });

        areabutton.clicked.connect(() => {
                sources.remove_range(0,sources.length);
                pw.run(mouserecord.active);
            });

        nt = new Notify();
        nt.on_action(() => {
                if(use_notall)
                    do_stop_action();
            });
        window.show ();
    }

    private void run_area_selection() {
		if (!fullscreen.active) {
			int mon = -1;
			if (sources.length == 1) {
				mon = sources[0].x / sources[0].width;
			}
            sw.run (mon);
        }
    }

    private bool validate_start() {
        return ((fd > 0 || fd == -1) && (fullscreen.active || have_area > 0));
    }


    private void update_status_label(string? astr=null) {
        StringBuilder sb = new StringBuilder();
		if (!fullscreen.active) {
			switch(have_area) {
			case 0:
				sb.append("Set area or window");
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
		startbutton.sensitive = validate_start();
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

    private string? get_config_file()
    {
        string fn = null;
        var uc = Environment.get_user_config_dir();
        if(uc != null) {
            fn = Path.build_filename(uc, "wayfarer", "cap.conf");
        }

        var file = File.new_for_path(fn);
        var f = file.get_parent();
        if(f.query_exists() == false)
        {
            try {
                f.make_directory_with_parents();
            } catch {};
        }
        return fn;
    }


    private void clean_up() {
		msel = mediasel.active_id;
        save_config();
        quit();
    }

    private void save_config() {
        var fn = get_config_file();
        if (fn != null) {
            var fp = FileStream.open(fn, "w");
            if(fp != null) {
                if (dirname != "")
                    fp.printf("dir = %s\n", dirname);
                if (audiorate != 0)
                    fp.printf("audiorate = %d\n", audiorate);
                if (audioid != "")
                    fp.printf("audioid = %s\n", audioid);
				fp.printf("use_not = %s\n", use_not.to_string());
				fp.printf("use_notall = %s\n", use_notall.to_string());
				fp.printf("media_type = %s\n", msel);
                var t = pw.get_token();
                if (t != null) {
                    fp.printf("token = %s\n", t);
                }
			}
        }
    }

    private void read_config() {
        var fn = get_config_file();
        if (fn != null) {
            var fp = FileStream.open(fn, "r");
            if(fp != null) {
                string line;
                while ((line = fp.read_line ()) != null) {
                    if(line.strip().length > 0 &&
                       !line.has_prefix("#") &&
                       !line.has_prefix(";")) {
                        var parts = line.split("=");
                        if(parts.length == 2) {
                            var p0 = parts[0].strip();
                            var p1 = parts[1].strip();
                            switch (p0) {
							case "dir":
								dirname = p1;
								break;
							case "audioid":
								audioid = p1;
								break;
							case "audiorate":
								audiorate = int.parse(p1);
                                if (audiorate == 0) {
                                    audiorate = 48000;
                                }
								break;
							case "use_not":
								use_not = (p1 == "true");
								break;
							case "use_notall":
								use_notall = (p1 == "true");
								break;
							case "media_type":
								msel = p1;
								break;
							case "token":
                                pw.set_token(p1);
								break;

                            }
                        }
                    }
                }
            }
        }
        if (dirname == null)
            dirname = "/tmp";
    }

    public static int main (string[] args) {
        if (Environment.get_variable("XDG_SESSION_DESKTOP") == "gnome") {
            Environment.set_variable("GDK_BACKEND", "x11", true);
        }

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
        MyApplication app = new MyApplication ();
        return app.run (args);
    }
}
