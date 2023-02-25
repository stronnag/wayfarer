project('wayfarer', 'vala', 'c', version : '1.0.0')

conf_data = configuration_data()
conf_data.set_quoted('version', meson.project_version())

res = run_command(['git', 'rev-parse', '--short', 'HEAD'], capture : true, check : true)
gitvers = res.stdout().strip()
res = run_command(['git', 'branch', '--show-current'], capture : true, check : true)
gitbranch = res.stdout().strip()
res = run_command(['git', 'log', '-1', '--format=%cI'], capture : true, check : true)
gitstamp = res.stdout().strip()

conf_data.set_quoted('gitvers', gitvers)
conf_data.set_quoted('gitbranch',  gitbranch)
conf_data.set_quoted('gitstamp', gitstamp)

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

dependency('glib-2.0', version: '>=2.30', required: true)

executable(
    meson.project_name(),
    wresources,
    wguisrcs,
    dependencies: [
      dependency('gtk4'),
      dependency('gio-2.0'),
      dependency('gstreamer-1.0'),
      dependency('gstreamer-pbutils-1.0'),
      dependency('libpulse-mainloop-glib'),
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
