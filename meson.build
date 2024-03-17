project('wayfarer', 'vala', 'c', version : '1.3.3')

# For now, as some replacements are not  well defined.

show_deprecated = get_option('deprecations')

if show_deprecated  == false
  add_project_arguments('-Wno-deprecated-declarations', language : 'c')
  add_project_arguments('--enable-deprecated', language : 'vala')
endif

if meson.get_compiler('c').get_id() == 'clang'
  add_global_arguments('-Wno-error=incompatible-function-pointer-types', language : 'c')
endif

conf_data = configuration_data()
conf_data.set_quoted('version', meson.project_version())
app = 'wayfarer'

pymodule = import('python3')
python3 = pymodule.find_python()
res = run_command(python3, 'meson/baseinfo.py', check: true)
if res.returncode() == 0
  message(res.stdout().strip())
endif

gnome = import('gnome')

deps = []

configure_file(
  input : 'src/wayfarer-config.h.in',
  output : 'wayfarer-config.h',
  configuration : conf_data
)
configuration_inc = include_directories('.')

vopts=[]
subdir('valaopts')
subdir('src')
subdir('data')
subdir('meson')

dependency('glib-2.0', version: '>=2.30', required: true)

executable(
    meson.project_name(),
    wresources,
    wguisrcs,
    dependencies: [
      dependency('gtk4', version: '>=4.12'),
      dependency('gio-2.0'),
      dependency('gstreamer-1.0'),
      dependency('gstreamer-pbutils-1.0'),
      dependency('libpulse-mainloop-glib'),
      deps,
      meson.get_compiler('vala').find_library('posix'),
      meson.get_compiler('c').find_library('m'),
    ],
    vala_args : vopts,
    c_args : vcopts,
    sources: wayvers_h,
    include_directories : configuration_inc,
    install: true,
)

executable(
  'wayfarer-convert-to-schema',
  convsrc,
  c_args : vcopts,
  dependencies: [
	dependency('gio-2.0'),
        meson.get_compiler('vala').find_library('posix'),
	],
    install: false,
)

meson.add_install_script('meson/post_install.sh')

gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
  update_desktop_database: true
)
