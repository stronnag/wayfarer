using Gtk;

public class AreaWindow : Gtk.Window {
	private int spx=-1;
	private int spy=-1;
	private int ax;
	private int ay;
	private bool dorect;

	public signal void area_set(int x0, int y0, int x1, int y1);

	public AreaWindow() {
		add_events (Gdk.EventMask.BUTTON_PRESS_MASK
					| Gdk.EventMask.BUTTON_RELEASE_MASK
					| Gdk.EventMask.KEY_PRESS_MASK
					| Gdk.EventMask.KEY_RELEASE_MASK
					| Gdk.EventMask.POINTER_MOTION_MASK);
		set_transparent();
		set_decorated(false);
		set_keep_above (true);
		var evtc = new EventControllerKey (this);
		evtc.set_propagation_phase(PropagationPhase.CAPTURE);

		key_press_event.connect((e) => {
				evtc.handle_event(e);
				return false;
			});

		evtc.key_pressed.connect((kv, kc, mfy) => {
				var ec = Gdk.keyval_from_name("Escape");
				if (kv == ec) {
					area_set(-1, -1, -1, -1);
				}
				return false;
			});

		var gestd = new GestureDrag(this);
		gestd.set_exclusive(true);
		gestd.set_window(this.get_window());

		motion_notify_event.connect((e) => {
				gestd.handle_event(e);
				return false;
			});

		gestd.drag_begin.connect((x,y) => {
				spx = (int)x;
				spy = (int)y;
				dorect = true;
			});

		gestd.drag_end.connect((x,y) => {
				int ex = spx + (int)x;
				int ey = spy + (int)y;
				dorect = false;
				queue_draw();
				area_set(spx, spy, ex, ey);
			});

		gestd.drag_update.connect((x,y) => {
				ax = spx + (int)x;
				ay = spy + (int)y;
				queue_draw();
			});
	}

	public void run(int monitor) {
		if (monitor == -1) {
			fullscreen();
		} else {
			fullscreen_on_monitor(Gdk.Screen.get_default(), monitor);
		}
		show_all();
		set_toplevel_cursor(Gdk.CursorType.CROSSHAIR);
	}

	private void set_transparent() {
		draw.connect((w, c) => {
				c.set_source_rgba(0, 0, 0, 0);
				c.set_operator(Cairo.Operator.SOURCE);
				c.paint();
				c.set_operator(Cairo.Operator.OVER);
				return false;
			});
		var screen = get_screen();
		var visual = screen.get_rgba_visual();
		if (visual!= null && screen.is_composited())
			set_visual(visual);
		set_app_paintable(true);
	}

	private void set_toplevel_cursor (Gdk.CursorType? cursor_type) {
        Gdk.Window gdk_window = this.get_window();
        if (cursor_type != null) {
			var dp = this.get_display();
            gdk_window.set_cursor(new Gdk.Cursor.for_display(dp, cursor_type));
		} else {
            gdk_window.set_cursor(null);
		}
    }

	public override bool draw (Cairo.Context cr) {
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
		return false;
	}
}
