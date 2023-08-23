namespace Utils {
    private const string CSSSTR="#record { background:  @theme_selected_bg_color;}";
    // background-color: @accent_bg_color; }";
    private const string UCSSSTR="#record { background:  @theme_normal_bg_color;}";

	public void get_even(ref int v, bool up = false) {
        if (up)
            v++;
        v&= ~1;
	}

    public uint preferred_threads() {
        return 1+get_num_processors()/2;
    }

    public void setup_css(Gtk.Widget w, bool on = true) {
		string str = (on) ? CSSSTR : UCSSSTR;
        var provider = new Gtk.CssProvider ();
#if CSS_USE_LOAD_DATA
        provider.load_from_data(str.data);
#else
        provider.load_from_string(str);
#endif
        var stylec = w.get_style_context();
        stylec.add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
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
}
