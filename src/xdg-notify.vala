[DBus (name = "org.freedesktop.Notifications")]
interface DTNotify : DBusProxy {
    public abstract uint Notify(
	string app_name,
 	uint replaces_id,
 	string app_icon,
 	string summary,
 	string body,
        string[]? actions,
 	HashTable<string,Variant>? hints,
 	int expire_timeout) throws GLib.DBusError, GLib.IOError;
    public abstract void CloseNotification (uint id) throws GLib.DBusError, GLib.IOError;

    public signal void  notification_closed(uint32 id, uint32 reason);
    public signal void  action_invoked(uint32 id, string actionid);
}

public delegate void DelegateUU (uint a, uint b);
public delegate void DelegateUS (uint a, string b);

public class Notify : GLib.Object
{
    private DTNotify dtnotify;
    private HashTable<string, Variant> _ht;
    private bool is_valid = false;
    private uint lastid;

    public Notify() {
        try {
            dtnotify = Bus.get_proxy_sync (BusType.SESSION, "org.freedesktop.Notifications",
                                     "/org/freedesktop/Notifications");
            _ht = new HashTable<string, Variant>(null,null);
            _ht.insert ("urgency", (uint8)2);
			_ht.insert ("resident", (bool)true);
            is_valid = true;
        } catch {
            is_valid = false;
        }
    }

    public void send_notification(string summary,  string text="", int32 timeout=2000) {
        try {
            if (is_valid) {
                string []acts = {"default", ""};
                var res = dtnotify.Notify ("wayfarer", lastid, "wayfarer", summary, text, acts, _ht, timeout);
                lastid = res;
            }
        } catch {
            is_valid = false;
        }
    }

    public void close_last() {
        try {
            dtnotify.CloseNotification(lastid);
        } catch {}
    }

    public void on_closed(DelegateUU d) {
        dtnotify.notification_closed.connect((id, reason) => {
                d(id,reason);
            });
    }

    public void on_action(DelegateUS d) {
        dtnotify.action_invoked.connect((id, actid) => {
                d(id,actid);
            });
    }
}
