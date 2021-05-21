project('wayfarer', 'vala', 'c', version : '0.1.0')

conf_data = configuration_data()
conf_data.set('version', meson.project_version())

app = 'wayfarer'

gnome = import('gnome')

wresources = gnome.compile_resources(
    'w-resources',
    join_paths('data', app + '.gresource.xml'),
    source_dir: 'data',
    c_name: 'w'
)

appind_dep  = dependency('appindicator3-0.1', required : false)
if appind_dep.found()
 appind_dep  = dependency('appindicator3-0.1')
else
 appind_dep  = dependency('ayatana-appindicator3-0.1')
endif

vapi_dir = meson.current_source_dir() / 'src/vapi'

add_project_arguments(['--vapidir', vapi_dir], language: 'vala')
add_project_arguments(['--pkg', 'wayfarer'], language: 'vala')

configure_file(
  input : 'src/wayfarer-config.h.in',
  output : 'wayfarer-config.h',
  configuration : conf_data
)
configuration_inc = include_directories('build')

executable(
    meson.project_name(),
    wresources,
    'src/gst-recording.vala',
    'src/recman.vala',
    'src/utils.vala',
    'src/xdg-notify.vala',
    'src/wayfarer.vala',
    dependencies: [
        dependency('gtk+-3.0'),
        dependency('gstreamer-1.0'),
	dependency('gio-2.0'),
	appind_dep,
        meson.get_compiler('vala').find_library('posix'),
	],
    include_directories : configuration_inc,
    install: true,
)

executable(
    'wayfarer-cli',
    'src/gst-recording.vala',
    'src/recman.vala',
    'src/utils.vala',
    dependencies: [
        dependency('gstreamer-1.0'),
	dependency('gio-2.0'),
        meson.get_compiler('vala').find_library('posix'),
	],
    vala_args: '--define=RECMANEXE',
    install: true
)

subdir('data')
meson.add_install_script('meson/post_install.sh')
