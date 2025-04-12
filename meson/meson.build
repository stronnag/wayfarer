r = run_command('pkg-config', '--modversion', 'gtk4',  check: true)
if r.returncode() != 0
  error('failed to get gtk version')
endif
gtkvers = r.stdout().strip()
compiler = meson.get_compiler('vala')
if gtkvers.version_compare('<4.12.0')
  if compiler.version().version_compare('<0.56.11')
    vopts += '--define=CSS_USE_LOAD_DATA'
  else
    vopts += '--define=CSS_USE_LOAD_DATA_STR_LEN'
  endif
else
  if compiler.version().version_compare('<0.56.9')
    vopts += '--define=CSS_USE_LOAD_DATA'
  else
    vopts += '--define=CSS_USE_LOAD_STR'
  endif
endif
