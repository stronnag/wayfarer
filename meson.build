project('wayfarer', 'vala', 'c', version : '0.4.0')

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

deps = []

configure_file(
  input : 'src/wayfarer-config.h.in',
  output : 'wayfarer-config.h',
  configuration : conf_data
)
configuration_inc = include_directories('build')

appind_dep  = dependency('appindicator3-0.1', required : false)
if appind_dep.found()
   deps = [ dependency('appindicator3-0.1') ]
else
    deps  = [ dependency('ayatana-appindicator3-0.1') ]
endif

subdir('src')

executable(
    meson.project_name(),
    wresources,
    wguisrcs,
    dependencies: [
        dependency('gtk+-3.0'),
        dependency('gstreamer-1.0'),
	dependency('gio-2.0'),
	dependency('libportal'),
	deps,
        meson.get_compiler('vala').find_library('posix'),
	],
    include_directories : configuration_inc,
    install: true,
)

subdir('data')
meson.add_install_script('meson/post_install.sh')
