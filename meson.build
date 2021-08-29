project('solas', 'vala', 'c',
  version: '1.0.0',
  default_options: [
    'warning_level=2',
    'werror=false',
    'c_std=gnu17',
    'b_lundef=false'
  ]
)

valac = meson.get_compiler('vala')
cc = meson.get_compiler('c')

glib_dep = dependency('glib-2.0', version: '>= 2.68')
gobject_dep = dependency('gobject-2.0')
gio_dep = dependency('gio-2.0')
gee_dep = dependency('gee-0.8')
json_glib_dep = dependency('json-glib-1.0')
openssl_dep = dependency('openssl', version: '>= 1.1')
m_dep = cc.find_library('m', required: false)

solas_inc = include_directories('src')

core_sources = files(
  'src/core/byte_buffer.vala',
  'src/core/byte_reader.vala',
  'src/core/byte_writer.vala',
  'src/core/clock.vala',
  'src/core/stats.vala',
  'src/core/logger.vala'
)

# Core library
solas_core_lib = static_library('solas_core',
  core_sources,
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, m_dep],
  include_directories: solas_inc
)

solas_core_dep = declare_dependency(
  link_with: solas_core_lib,
  include_directories: solas_inc,
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, m_dep]
)

# Test Core
test_core_exe = executable('test_core',
  'tests/test_core.vala',
  dependencies: [solas_core_dep],
  include_directories: solas_inc
)

test('test_core', test_core_exe)
