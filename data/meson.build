blueprints = custom_target('blueprints',
  input: files(
    'wayfarer.blp',
  ),
  output: '.',
  command: [find_program('blueprint-compiler'), 'batch-compile', '@OUTPUT@', '@CURRENT_SOURCE_DIR@', '@INPUT@'],
)

wresources = gnome.compile_resources(
  'w-resources',
  'wayfarer.gresource.xml',
  source_dir: 'data',
  c_name: 'w',
  dependencies: blueprints,
)

install_data(
	'wayfarer.svg',
    install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', 'scalable', 'apps')
)

install_data('org.stronnag.wayfarer.desktop', install_dir : get_option('datadir') / 'applications')


install_data (
  'org.stronnag.wayfarer.gschema.xml',
  install_dir: join_paths(get_option('datadir'), 'glib-2.0', 'schemas'),
)
