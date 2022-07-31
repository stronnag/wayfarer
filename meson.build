project('wayfarer', 'vala', 'c', version : '0.5.0')

conf_data = configuration_data()
conf_data.set('version', meson.project_version())

app = 'wayfarer'

gnome = import('gnome')

blueprints = custom_target('blueprints',
  input: files(
    'data/wayfarer.blp',
  ),
  output: '.',
  command: [find_program('blueprint-compiler'), 'batch-compile', '@OUTPUT@', '@CURRENT_SOURCE_DIR@', '@INPUT@'],
)


wresources = gnome.compile_resources(
    'w-resources',
    join_paths('data', app + '.gresource.xml'),
    dependencies: blueprints,
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

subdir('src')

executable(
    meson.project_name(),
    wresources,
    wguisrcs,
    dependencies: [
        dependency('gtk4'),
        dependency('gstreamer-1.0'),
	dependency('gio-2.0'),
	dependency('libportal-gtk4'),
	deps,
        meson.get_compiler('vala').find_library('posix'),
	],
    include_directories : configuration_inc,
    install: true,
)

subdir('data')
meson.add_install_script('meson/post_install.sh')
