project('wayfarer', 'vala', 'c', version : '1.0.0')

conf_data = configuration_data()
conf_data.set('version', meson.project_version())

app = 'wayfarer'

gnome = import('gnome')

deps = []

configure_file(
  input : 'src/wayfarer-config.h.in',
  output : 'wayfarer-config.h',
  configuration : conf_data
)
configuration_inc = include_directories('build')

subdir('src')
subdir('data')

executable(
    meson.project_name(),
    wresources,
    wguisrcs,
    dependencies: [
        dependency('gtk4'),
	dependency('gio-2.0'),
        dependency('gstreamer-1.0'),
        dependency('gstreamer-pbutils-1.0'),
	deps,
        meson.get_compiler('vala').find_library('posix'),
	],
    include_directories : configuration_inc,
    install: true,
)

executable(
  'wayfarer-convert-to-schema',
  convsrc,
  dependencies: [
	dependency('gio-2.0'),
        meson.get_compiler('vala').find_library('posix'),
	],
    install: false,
)

gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
  update_desktop_database: true
)
