project(
    'wayfarer',
    'vala', 'c',
    version: '0.0.1'
)

app_nickname = 'wayfarer'

gnome = import('gnome')

asresources = gnome.compile_resources(
    'as-resources',
    join_paths('data', app_nickname + '.gresource.xml'),
    source_dir: 'data',
    c_name: 'as'
)

appind_dep  = dependency('appindicator3-0.1', required : false)
if appind_dep.found()
 appind_dep  = dependency('appindicator3-0.1')
else
 appind_dep  = dependency('ayatana-appindicator3-0.1')
endif

executable(
    meson.project_name(),
    asresources,
    'src/gst-record-audio.vala',
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
    install: true,
)

executable(
    'wayfarer-cli',
    'src/gst-record-audio.vala',
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
