getinfo = files('getinfo.sh')

wayvers_h = custom_target(
    'wayvers.h',
    output : 'wayvers.h',
    command : [getinfo, '@OUTPUT@'],
)

vapi_dir = meson.current_source_dir() / 'vapi'

add_project_arguments(['--vapidir', vapi_dir], language: 'vala')
add_project_arguments(['--pkg', 'wayfarer'], language: 'vala')

wguisrcs = files('gst-recording.vala', 'recman.vala', 'utils.vala', 'xdg-notify.vala', 'portal.vala', 'wayfarer.vala', 'selection.vala', 'pipeline.vala', 'encoders.vala', 'settings.vala')

convsrc = files('wayfarer-convert-to-schema.vala', 'settings.vala')
