private string? get_config_file() {
    string fn = null;
    var uc = Environment.get_user_config_dir();
    if(uc != null) {
        fn = Path.build_filename(uc, "wayfarer", "cap.conf");
    }
    var file = File.new_for_path(fn);
    var f = file.get_parent();
    if(f.query_exists() == false) {
        return null;
    } else {
        return fn;
    }
}

bool  read_config_file(ref Conf conf) {
    bool res = false;
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
                            conf.video_dir = p1;
                            break;
                        case "audioid":
                            conf.audio_device = p1;
                            break;
                        case "audiorate":
                            var audiorate = int.parse(p1);
                            if (audiorate == 0) {
                                audiorate = 48000;
                            }
                            conf.audio_rate = audiorate;
                            break;
                        case "use_not":
                            conf.notify_start = (p1 == "true");
                            break;
                        case "use_notall":
                            conf.notify_stop = (p1 == "true");
                            break;
                        case "media_type":
                            conf.media_type = p1;
                            break;
                        case "token":
                            conf.restore_token = p1;
                            break;
                        }
                    }
                }
            }
            print("Config read successfully\n");
            res = true;
        } else {
            print("Failed to read config file\n");
        }
    } else {
        print("No config found\n");
    }
    return res;
}


void main () {
    var conf = new Conf();
    read_config_file(ref conf);
    Settings.sync();
    print("Settings schema updated\n");
}
