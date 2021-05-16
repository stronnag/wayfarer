using Gtk;
using AppIndicator;

public class MyApplication : Gtk.Application {
    Gtk.ApplicationWindow window;
    private Indicator ci;
    private ScreenCap sc;
    private bool have_area;
    private string filename;
    private string dirname;
    private string astr;
    private int audioid;
    private bool use_not;
    private bool use_notall;
    private Notify nt;
    private uint timerid;
    private Gtk.CheckButton fullscreen;
    private Gtk.Entry fileentry;
    private Gtk.Button startbutton;
    private Gtk.Label statuslabel;

    public MyApplication () {
        Object(application_id: "org.stonnag.wayfarer",
               flags: ApplicationFlags.FLAGS_NONE);
    }

    protected override void activate () {
        Builder builder;
        builder = new Builder.from_resource("/org/stronnag/wayfarer/wayfarer.ui");

        builder.connect_signals (null);
        window = builder.get_object ("appwin") as Gtk.ApplicationWindow;
        this.add_window (window);
        window.set_application (this);

        window.destroy.connect( () => {
                clean_up();
            });

        fullscreen  =  builder.get_object("fullscreen") as CheckButton;
        fileentry = builder.get_object("filename") as Entry;
        startbutton = builder.get_object("startbutton") as Button;
        statuslabel = builder.get_object("statuslabel") as Label;

        FileChooserButton dirchooser = builder.get_object("dirchooser") as FileChooserButton;
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
        CheckButton prefs_gst =  builder.get_object("prefs_gst") as CheckButton;
        CheckButton prefs_not =  builder.get_object("prefs_not") as CheckButton;
        CheckButton prefs_notall =  builder.get_object("prefs_notall") as CheckButton;

        about.delete_event.connect (() => {
                about.hide();
                return true;
            });

        prefs.delete_event.connect (() => {
                prefs.hide();
                return true;
            });

        prefapply.clicked.connect(() => {
                sc.use_gst = prefs_gst.active;
                use_not = prefs_not.active;
                use_notall = prefs_notall.active;
                prefs.hide();
            });

        var saq = new GLib.SimpleAction("quit",null);
        saq.activate.connect(() => {
                clean_up();
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("prefs",null);
        saq.activate.connect(() => {
                prefs.show_all();
            });
        window.add_action(saq);

        saq = new GLib.SimpleAction("about",null);
        saq.activate.connect(() => {
                about.show_all();
            });
        window.add_action(saq);

        startbutton.sensitive = false;

        fileentry.changed.connect(() => {
                filename = fileentry.text;
                update_status_label();
            });

        fullscreen.toggled.connect(() => {
                update_status_label();
            });

        window.set_icon_name("wayfarer");
        ci = new Indicator("wayfarer",
                           "wayfarer",
                           IndicatorCategory.APPLICATION_STATUS);
        var menu = new Gtk.Menu();
        var stoprecordingbutton = new Gtk.MenuItem.with_label("Stop Recording");

        stoprecordingbutton.activate.connect(do_stop_action);
        menu.append(stoprecordingbutton);
        menu.show_all();

        ci.set_menu(menu);
        ci.set_secondary_activate_target(stoprecordingbutton);
        startbutton.clicked.connect(() => {
                sc.options.capmouse = mouserecord.active;
                sc.options.capaudio = audiorecord.active;
                sc.options.framerate = framerate.get_value_as_int();
                sc.options.adevice = audiosource.active_id;
                dirname = dirchooser.get_current_folder ();
                var filepath = string.join(".", fileentry.text, "mkv");
                var tryfile =  Path.build_filename (dirname, filepath);
                var tmpname = fileentry.text;
                int nfn = 0;
                while (Utils.file_exists(tryfile)) {
                    var res = show_conflict_dialog(tmpname);
                    if(res < 0) // Cancel
                        return;
                    if(res == 1001) // Overwrite
                        break;
                    else {
                        nfn++;
                        tmpname = "%s_%d".printf(fileentry.text, nfn);
                        filepath = string.join(".", tmpname, "mkv");
                        tryfile =  Path.build_filename (dirname, filepath);
                        stderr.printf("Offer %s\n", tryfile);
                    }
                }
                if (nfn != 0) {
                     fileentry.text = tmpname;
                }

                sc.options.outfile = tryfile;
                stderr.printf("Out => %s\n",  sc.options.outfile);
                sc.options.fullscreen = fullscreen.active;
                window.hide();
                ci.set_status(IndicatorStatus.ACTIVE);
                var delay = delayspin.get_value();

                if(use_not || use_notall) {
                    if(delay < 2) {
                        nt.send_notification("Ready to record", "", (use_notall)? 0 :1000);
                    } else {
                        var ctr = (int)(delay);
                        var str = "Starting in %ds\n".printf(ctr);
                        nt.send_notification("Ready to record", str, (use_notall)? 0 :1000);
                        ctr--;
                        Timeout.add_seconds(1, () => {
                                str = "Starting in %ds\n".printf(ctr);
                                nt.send_notification("Ready to record", (ctr>1) ? str : "", (use_notall)? 0 :1000);
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
                        var res = sc.capture();
                        if (res == false) {
                              if(timerid > 0) {
                                  Source.remove(timerid);
                                  timerid = 0;
                              }
                              ci.set_status(IndicatorStatus.PASSIVE);
                              statuslabel.label = "Failed to record";
                              window.show_all();
                        }
                        return Source.REMOVE;
                    });
            });

        sc = new ScreenCap();
        var at = sc.get_sources();
        foreach (var a in at) {
            audiosource.append(a.device,a.desc);
        }

        if(at.length == 0) {
            stderr.puts("No audio sources found\n");
            quit();
        }

        Unix.signal_add(Posix.Signal.USR1, () => {
                do_stop_action();
                return Source.CONTINUE;
            });

        read_config();
        if(dirname != null)
            dirchooser.set_current_folder(dirname);
        if(filename != null)
            fileentry.text = filename;
        audiosource.active = audioid;

        prefs_gst.active = sc.use_gst;
        prefs_not.active = use_not;
        prefs_notall.active = use_notall;

        audiosource.changed.connect(() => {
                audioid = audiosource.active;
            });

        areabutton.clicked.connect(() => {
                have_area = sc.get_area(out astr);
                if (have_area)
                    fullscreen.active = false;
                update_status_label();
            });

        nt = new Notify();
        nt.on_action(() => {
                if(use_notall)
                    do_stop_action();
            });

        window.show_all ();
    }

    private void update_status_label()
    {
        var startok = ((fileentry.text.length > 0) && (fullscreen.active || have_area));
        bool need_space = false;
        if (startok) {
            statuslabel.label="";
        } else {
            StringBuilder sb = new StringBuilder();
            if(fileentry.text.length == 0) {
                sb.append("Set a file name to record");
                need_space = true;
            }
            if (!fullscreen.active) {
                if(need_space)
                    sb.append(" : ");
                if(have_area)
                    sb.append_printf("Area: %s", astr);
                else
                    sb.append("Set area or full-screen");
            }
            statuslabel.label=sb.str;
        }
        startbutton.sensitive = startok;
    }

    private int show_conflict_dialog(string filename)
    {
        var dialog = new Gtk.Dialog.with_buttons ("File Conflict",
                                                  window,
                                                  Gtk.DialogFlags.MODAL|Gtk.DialogFlags.DESTROY_WITH_PARENT,
                                                  "Overwrite",
                                                  1001,
                                                  "Auto-rename",
                                                  1002,
                                                  "_Cancel",
                                                  ResponseType.REJECT,
                                                  null);
        var  content_area = dialog.get_content_area ();
        var label = new Gtk.Label("File %s exists\nPlease select a resolution".printf(filename));
        content_area.add(label);
        dialog.show_all();
        var res = dialog.run();
        dialog.destroy();
        return res;
    }

    private void do_stop_action()
    {
        if(timerid > 0) {
            Source.remove(timerid);
            timerid = 0;
        }
        nt.close_last();
        ci.set_status(IndicatorStatus.PASSIVE);
        window.show_all();
        sc.post_process();
    }

    private string? get_config_file()
    {
        string fn = null;
        var uc = Environment.get_user_config_dir();
        if(uc != null) {
            fn = Path.build_filename (uc, "wayfarer", "cap.conf");
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


    private void clean_up()
    {
        save_config();
        quit();
    }

    private void save_config()
    {
        var fn = get_config_file();
        if (fn != null) {
            var fp = FileStream.open(fn, "w");
            if(fp != null)
            {
                if (dirname != null)
                    fp.printf("dir = %s\n", dirname);
                if (filename != null)
                    fp.printf("file = %s\n", filename);
                if (audioid != 0)
                    fp.printf("audioid = %d\n", audioid);
                if (sc.use_gst)
                    fp.puts("use_gst = true\n");
                if (use_not)
                    fp.puts("use_not = true\n");
                if (use_notall)
                    fp.puts("use_notall = true\n");
            }
        }
    }

    private void read_config()
    {
        var fn = get_config_file();
        if (fn != null) {
            var fp = FileStream.open(fn, "r");
            if(fp != null)
            {
                string line;
                while ((line = fp.read_line ()) != null)
                {
                    if(line.strip().length > 0 &&
                       !line.has_prefix("#") &&
                       !line.has_prefix(";"))
                    {
                        var parts = line.split("=");
                        if(parts.length == 2)
                        {
                            var p0 = parts[0].strip();
                            var p1 = parts[1].strip();
                            switch (p0)
                            {
                                case "dir":
                                    dirname = p1;
                                    break;
                                case "file":
                                    filename = p1;
                                    break;
                                case "audioid":
                                    audioid = int.parse(p1);
                                    break;
                                case "use_gst":
                                    sc.use_gst = (p1 == "true");
                                    break;
                                case "use_not":
                                    use_not = (p1 == "true");
                                    break;
                                case "use_notall":
                                    use_notall = (p1 == "true");
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
        MyApplication app = new MyApplication ();
        return app.run (args);
    }
}
