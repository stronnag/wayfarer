namespace Utils {
    private const string CSSSTR="""
#recsel { background:  @theme_selected_bg_color;}
#recdef { background:  @theme_normal_bg_color;}
#opaqueish {background: rgba(255, 255, 255, 0.1);}
""";

	public void get_even(ref int v, bool up = false) {
        if (up)
            v++;
        v&= ~1;
	}

    public uint preferred_threads() {
        return 1+get_num_processors()/2;
    }

    public void setup_css(Gtk.Widget w) {
        var provider = new Gtk.CssProvider ();
		load_provider_string(ref provider, CSSSTR);
		Gtk.StyleContext.add_provider_for_display (Gdk.Display.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
    }

	public void load_provider_string(ref Gtk.CssProvider provider, string str) {
#if CSS_USE_LOAD_DATA
        provider.load_from_data(str.data);
#elif CSS_USE_LOAD_DATA_STR_LEN
        provider.load_from_data(str, -1);
#else
        provider.load_from_string(str);
#endif
	}

    public void fake_sources (ref GenericArray<PortalManager.SourceInfo?> sis) {
        var dpy = Gdk.Display.get_default();
        var mons = dpy.get_monitors();
        for(var j = 0; j <mons.get_n_items(); j++) {
            var monitor = mons.get_item(j) as Gdk.Monitor;
            var rect = monitor.get_geometry();
            var s = monitor.get_model();
            PortalManager.SourceInfo si = {0};
            si.width = rect.width;
            si.height= rect.height;
            si.x = rect.x;
            si.y = rect.y;
            si.id = s;
            sis.add(si);
        }
    }

	public async string get_video_directory(string? d) {
		var fd = new  Gtk.FileDialog ();
		var fn = d;
		if( fn == null) {
			fn = GLib.Path.build_filename(GLib.Environment.get_home_dir(), "Videos");
		}
		var dir = File.new_for_path(fn);
		fd.initial_folder = dir;
		fd.initial_file = dir;
		fd.title = "Video Folder";
		try {
			var fh = yield fd.select_folder(null, null);
			fn = fh.get_path();
		} catch {}
		return fn;
	}
}
