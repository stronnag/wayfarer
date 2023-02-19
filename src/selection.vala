using Gtk;

public class AreaWindow : Gtk.Window {
	private int spx=-1;
	private int spy=-1;
	private int ax;
	private int ay;
	private bool dorect;
	private Gdk.RGBA fill;
	private Gdk.RGBA stroke;
	public signal void area_set(int x0, int y0, int x1, int y1);
	public signal void area_quit();
    private DrawingArea da;

	public AreaWindow() {
		fill = Gdk.RGBA(){red = 1.0f, green = 1.0f, blue = 1.0f, alpha= 0.2f};
		stroke = Gdk.RGBA(){red = 0.0f, green = 0.2f, blue = 0.8f, alpha = 0.8f};
        title = "Wayfarer";

        da = new DrawingArea();
        da.hexpand = true;
        da.vexpand = true;
        set_child (da);

        da.set_draw_func((da, cr, w, h) => {
                if (dorect) {
                    cr.set_line_cap(Cairo.LineCap.ROUND);
                    cr.set_source_rgba(1, 1, 1, 0.2);
                    cr.rectangle(spx, spy, ax-spx, ay-spy);
                    cr.fill_preserve();
                    cr.set_line_width(2);
                    cr.set_source_rgba(1, 1, 1, 0.5);
                    cr.stroke();
                } else {
                    cr.new_path();
                }
            });

        set_decorated(false);

		var evtc = new EventControllerKey ();
		evtc.set_propagation_phase(PropagationPhase.CAPTURE);
		((Gtk.Widget)this).add_controller(evtc);

		evtc.key_pressed.connect((kv, kc, mfy) => {
				var ec = Gdk.keyval_from_name("Escape");
				if (kv == ec) {
					area_quit();
				}
				return false;
			});

		var gestd = new GestureDrag();
		gestd.set_exclusive(true);
		((Gtk.Widget)this).add_controller(gestd);

        gestd.drag_begin.connect((x,y) => {
				spx = (int)x;
				spy = (int)y;
                dorect = true;
			});

		gestd.drag_end.connect((x,y) => {
				int ex = spx + (int)x;
				int ey = spy + (int)y;
                dorect = false;
                da.queue_draw();
				area_set(spx, spy, ex, ey);
			});

		gestd.drag_update.connect((x,y) => {
				ax = spx + (int)x;
				ay = spy + (int)y;
                da.queue_draw();
			});
	}

	public void run(int mno) {
        set_cursor_from_name("crosshair");
		if (mno == -1) {
			fullscreen();
		} else {
			var dpy = Gdk.Display.get_default();
			var mons = dpy.get_monitors();
			var nitems = mons.get_n_items();
			if (mno < nitems) {
				var monitor = (Gdk.Monitor)mons.get_item(mno);
				fullscreen_on_monitor(monitor);
			} else {
				fullscreen();
			}
		}
        set_bg();
		present();
	}

    private void set_bg() {
        string css = "window {background: rgba(255, 255, 255, 0.1);}";
        var provider = new CssProvider();
        provider.load_from_data(css.data);
        var stylec = get_style_context();
        stylec.add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
    }
}
