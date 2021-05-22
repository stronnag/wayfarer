
vapi_dir = meson.current_source_dir() / 'vapi'

add_project_arguments(['--vapidir', vapi_dir], language: 'vala')
add_project_arguments(['--pkg', 'wayfarer'], language: 'vala')

wclisrcs = files('gst-recording.vala', 'recman.vala', 'utils.vala')
wguisrcs = files('gst-recording.vala', 'recman.vala', 'utils.vala', 'xdg-notify.vala', 'wayfarer.vala')
