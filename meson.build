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
crypto_lib = cc.find_library('crypto', dirs: ['/opt/homebrew/opt/openssl@3/lib', '/opt/homebrew/opt/openssl/lib', '/opt/homebrew/lib', '/usr/local/lib'])
ssl_lib = cc.find_library('ssl', dirs: ['/opt/homebrew/opt/openssl@3/lib', '/opt/homebrew/opt/openssl/lib', '/opt/homebrew/lib', '/usr/local/lib'])
openssl_inc = include_directories('/opt/homebrew/opt/openssl/include', '/opt/homebrew/include')
openssl_c_dep = openssl_dep.partial_dependency(compile_args: true, link_args: true, includes: true)
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

# Crypto library
openssl_inc = include_directories('/opt/homebrew/Cellar/openssl@4/4.1.0/include', '/opt/homebrew/include')

solas_crypto_native_lib = static_library('solas_crypto_native',
  'src/crypto/solas_crypto_native.c',
  dependencies: [crypto_lib, ssl_lib],
  include_directories: [solas_inc, openssl_inc]
)

solas_crypto_lib = static_library('solas_crypto',
  'src/crypto/crypto.vala',
  vala_args: ['--vapidir=' + meson.current_source_dir() / 'src/crypto', '--pkg=solas_crypto'],
  link_with: [solas_crypto_native_lib],
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, solas_core_dep],
  include_directories: solas_inc
)

solas_crypto_dep = declare_dependency(
  link_with: [solas_crypto_lib, solas_crypto_native_lib],
  include_directories: solas_inc,
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, crypto_lib, ssl_lib, solas_core_dep]
)

# Test Core
test_core_exe = executable('test_core',
  'tests/test_core.vala',
  dependencies: [solas_core_dep],
  include_directories: solas_inc
)
test('test_core', test_core_exe)

# Test Crypto
test_crypto_exe = executable('test_crypto',
  'tests/test_crypto.vala',
  vala_args: ['--vapidir=' + meson.current_source_dir() / 'src/crypto', '--pkg=solas_crypto'],
  dependencies: [solas_crypto_dep],
  include_directories: solas_inc
)
test('test_crypto', test_crypto_exe)
