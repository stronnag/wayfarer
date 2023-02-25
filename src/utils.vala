namespace Utils {
    private const string CSSSTR="#record { background:  @theme_selected_bg_color;}";
    // background-color: @accent_bg_color; }";

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
        provider.load_from_data(CSSSTR.data);
        var stylec = w.get_style_context();
        stylec.add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
    }
}
