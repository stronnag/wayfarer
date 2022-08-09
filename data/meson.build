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

#icon_sizes = ['16', '24', '32', '48', '64', '128']
#foreach i : icon_sizes
#    install_data(
#        join_paths('icons', i, 'wayfarer.svg'),
#        install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', i + 'x' + i, 'apps')
#    )
#endforeach

install_data(
	'wayfarer.svg',
    install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', 'scalable', 'apps')
)

install_data('org.stronnag.wayfarer.desktop', install_dir : get_option('datadir') / 'applications')
