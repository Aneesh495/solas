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

# STUN library
stun_sources = files(
  'src/protocol/stun/stun_types.vala',
  'src/protocol/stun/stun_attribute.vala',
  'src/protocol/stun/stun_message.vala'
)

solas_stun_lib = static_library('solas_stun',
  stun_sources,
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, solas_core_dep, solas_crypto_dep],
  include_directories: solas_inc
)

solas_stun_dep = declare_dependency(
  link_with: solas_stun_lib,
  include_directories: solas_inc,
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, solas_core_dep, solas_crypto_dep]
)

# SDP library
sdp_sources = files(
  'src/protocol/sdp/sdp_types.vala',
  'src/protocol/sdp/sdp_models.vala',
  'src/protocol/sdp/sdp_parser.vala',
  'src/protocol/sdp/sdp_serializer.vala',
  'src/protocol/sdp/sdp_negotiator.vala'
)

solas_sdp_lib = static_library('solas_sdp',
  sdp_sources,
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, solas_core_dep],
  include_directories: solas_inc
)

solas_sdp_dep = declare_dependency(
  link_with: solas_sdp_lib,
  include_directories: solas_inc,
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, solas_core_dep]
)

# RTP library
rtp_sources = files(
  'src/protocol/rtp/rtp_extension.vala',
  'src/protocol/rtp/rtp_packet.vala',
  'src/protocol/rtp/sequence_unwrapper.vala'
)

solas_rtp_lib = static_library('solas_rtp',
  rtp_sources,
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, solas_core_dep],
  include_directories: solas_inc
)

solas_rtp_dep = declare_dependency(
  link_with: solas_rtp_lib,
  include_directories: solas_inc,
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, solas_core_dep]
)

# RTCP library
rtcp_sources = files(
  'src/protocol/rtcp/rtcp_types.vala',
  'src/protocol/rtcp/rtcp_packet.vala',
  'src/protocol/rtcp/sender_report.vala',
  'src/protocol/rtcp/receiver_report.vala',
  'src/protocol/rtcp/feedback_nack.vala',
  'src/protocol/rtcp/feedback_pli_fir.vala',
  'src/protocol/rtcp/feedback_remb.vala',
  'src/protocol/rtcp/feedback_twcc.vala'
)

solas_rtcp_lib = static_library('solas_rtcp',
  rtcp_sources,
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, solas_core_dep],
  include_directories: solas_inc
)

solas_rtcp_dep = declare_dependency(
  link_with: solas_rtcp_lib,
  include_directories: solas_inc,
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, solas_core_dep]
)

# SRTP library
srtp_sources = files(
  'src/protocol/srtp/replay_window.vala',
  'src/protocol/srtp/srtp_context.vala',
  'src/protocol/srtp/srtp_session.vala'
)

solas_srtp_lib = static_library('solas_srtp',
  srtp_sources,
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, solas_core_dep, solas_crypto_dep, solas_rtp_dep, solas_rtcp_dep],
  include_directories: solas_inc
)

solas_srtp_dep = declare_dependency(
  link_with: solas_srtp_lib,
  include_directories: solas_inc,
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, solas_core_dep, solas_crypto_dep, solas_rtp_dep, solas_rtcp_dep]
)

# Media library
media_sources = files(
  'src/media/codec_types.vala',
  'src/media/depacketizer.vala',
  'src/media/depacketizer_vp8.vala',
  'src/media/depacketizer_h264.vala',
  'src/media/depacketizer_opus.vala'
)

solas_media_lib = static_library('solas_media',
  media_sources,
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, m_dep, solas_core_dep, solas_rtp_dep],
  include_directories: solas_inc
)

solas_media_dep = declare_dependency(
  link_with: solas_media_lib,
  include_directories: solas_inc,
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, m_dep, solas_core_dep, solas_rtp_dep]
)

# Jitter library
jitter_sources = files(
  'src/engine/jitter/packet_buffer.vala',
  'src/engine/jitter/playout_delay.vala',
  'src/engine/jitter/nack_queue.vala',
  'src/engine/jitter/frame_assembler.vala'
)

solas_jitter_lib = static_library('solas_jitter',
  jitter_sources,
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, m_dep, solas_core_dep, solas_rtp_dep, solas_rtcp_dep],
  include_directories: solas_inc
)

solas_jitter_dep = declare_dependency(
  link_with: solas_jitter_lib,
  include_directories: solas_inc,
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, m_dep, solas_core_dep, solas_rtp_dep, solas_rtcp_dep]
)

# Congestion Control library
congestion_sources = files(
  'src/engine/congestion/trendline_estimator.vala',
  'src/engine/congestion/aimd_rate_controller.vala',
  'src/engine/congestion/loss_controller.vala',
  'src/engine/congestion/bandwidth_estimator.vala',
  'src/engine/congestion/pacer.vala'
)

solas_congestion_lib = static_library('solas_congestion',
  congestion_sources,
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, m_dep, solas_core_dep, solas_rtp_dep, solas_rtcp_dep],
  include_directories: solas_inc
)

solas_congestion_dep = declare_dependency(
  link_with: solas_congestion_lib,
  include_directories: solas_inc,
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, m_dep, solas_core_dep, solas_rtp_dep, solas_rtcp_dep]
)

# SFU Core library
sfu_sources = files(
  'src/engine/sfu/track.vala',
  'src/engine/sfu/active_speaker.vala',
  'src/engine/sfu/simulcast_router.vala',
  'src/engine/sfu/peer.vala',
  'src/engine/sfu/room.vala'
)

solas_sfu_lib = static_library('solas_sfu',
  sfu_sources,
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, m_dep,
                 solas_core_dep, solas_rtp_dep, solas_rtcp_dep, solas_sdp_dep,
                 solas_media_dep, solas_jitter_dep, solas_congestion_dep],
  include_directories: solas_inc
)

solas_sfu_dep = declare_dependency(
  link_with: solas_sfu_lib,
  include_directories: solas_inc,
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, m_dep,
                 solas_core_dep, solas_rtp_dep, solas_rtcp_dep, solas_sdp_dep,
                 solas_media_dep, solas_jitter_dep, solas_congestion_dep]
)

# Distribution library
distribution_sources = files(
  'src/distribution/fmp4_boxes.vala',
  'src/distribution/segmenter.vala',
  'src/distribution/hls_playlist.vala'
)

solas_distribution_lib = static_library('solas_distribution',
  distribution_sources,
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, m_dep, solas_core_dep, solas_rtp_dep],
  include_directories: solas_inc
)

solas_distribution_dep = declare_dependency(
  link_with: solas_distribution_lib,
  include_directories: solas_inc,
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, m_dep, solas_core_dep, solas_rtp_dep]
)

# Network library
network_sources = files(
  'src/network/protocol_demuxer.vala',
  'src/network/websocket_framing.vala',
  'src/network/metrics_exporter.vala',
  'src/network/static_web_assets.vala',
  'src/network/http_server.vala',
  'src/network/udp_server.vala'
)

solas_network_lib = static_library('solas_network',
  network_sources,
  vala_args: ['--vapidir=' + meson.current_source_dir() / 'src/crypto', '--pkg=solas_crypto'],
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, m_dep, solas_core_dep, solas_crypto_dep, solas_sdp_dep, solas_sfu_dep],
  include_directories: solas_inc
)

solas_network_dep = declare_dependency(
  link_with: solas_network_lib,
  include_directories: solas_inc,
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, m_dep, solas_core_dep, solas_crypto_dep, solas_sdp_dep, solas_sfu_dep]
)

# Server library
server_sources = files(
  'src/server/config.vala',
  'src/server/ice_agent.vala',
  'src/server/dtls_transport.vala',
  'src/server/signaling_session.vala',
  'src/server/server.vala'
)

solas_server_lib = static_library('solas_server',
  server_sources,
  vala_args: ['--vapidir=' + meson.current_source_dir() / 'src/crypto', '--pkg=solas_crypto'],
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, json_glib_dep, m_dep,
                 solas_core_dep, solas_crypto_dep, solas_stun_dep, solas_sdp_dep, solas_sfu_dep, solas_network_dep],
  include_directories: solas_inc
)

solas_server_dep = declare_dependency(
  link_with: solas_server_lib,
  include_directories: solas_inc,
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, json_glib_dep, m_dep,
                 solas_core_dep, solas_crypto_dep, solas_stun_dep, solas_sdp_dep, solas_sfu_dep, solas_network_dep]
)

# Solas Server Executable
posix_dep = valac.find_library('posix')
solas_server_exe = executable('solas-server',
  'src/main.vala',
  vala_args: ['--vapidir=' + meson.current_source_dir() / 'src/crypto', '--pkg=solas_crypto'],
  dependencies: [solas_server_dep, posix_dep],
  include_directories: solas_inc,
  install: true
)

# CLI Library
cli_sources = files(
  'src/cli/cli_args.vala',
  'src/cli/cli_client.vala'
)

solas_cli_lib = static_library('solas_cli',
  cli_sources,
  vala_args: ['--vapidir=' + meson.current_source_dir() / 'src/crypto', '--pkg=solas_crypto'],
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, json_glib_dep, m_dep, solas_core_dep, solas_stun_dep],
  include_directories: solas_inc
)

solas_cli_dep = declare_dependency(
  link_with: solas_cli_lib,
  include_directories: solas_inc,
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, json_glib_dep, m_dep, solas_core_dep, solas_stun_dep]
)

# Solas CLI Executable
solas_cli_exe = executable('solas-cli',
  'src/cli/main.vala',
  vala_args: ['--vapidir=' + meson.current_source_dir() / 'src/crypto', '--pkg=solas_crypto'],
  dependencies: [solas_cli_dep],
  include_directories: solas_inc,
  install: true
)

# Benchmark Library
bench_sources = files(
  'src/bench/synthetic_publisher.vala',
  'src/bench/network_impairment.vala',
  'src/bench/bench_runner.vala'
)

solas_bench_lib = static_library('solas_bench',
  bench_sources,
  vala_args: ['--vapidir=' + meson.current_source_dir() / 'src/crypto', '--pkg=solas_crypto'],
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, json_glib_dep, m_dep,
                 solas_core_dep, solas_rtp_dep, solas_sdp_dep, solas_sfu_dep],
  include_directories: solas_inc
)

solas_bench_dep = declare_dependency(
  link_with: solas_bench_lib,
  include_directories: solas_inc,
  dependencies: [glib_dep, gobject_dep, gio_dep, gee_dep, json_glib_dep, m_dep,
                 solas_core_dep, solas_rtp_dep, solas_sdp_dep, solas_sfu_dep]
)

# Solas Benchmark Executable
solas_bench_exe = executable('solas-bench',
  'src/bench/main.vala',
  vala_args: ['--vapidir=' + meson.current_source_dir() / 'src/crypto', '--pkg=solas_crypto'],
  dependencies: [solas_bench_dep],
  include_directories: solas_inc,
  install: true
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

# Test STUN
test_stun_exe = executable('test_stun',
  'tests/test_stun.vala',
  dependencies: [solas_stun_dep],
  include_directories: solas_inc
)
test('test_stun', test_stun_exe)

# Test SDP
test_sdp_exe = executable('test_sdp',
  'tests/test_sdp.vala',
  dependencies: [solas_sdp_dep],
  include_directories: solas_inc
)
test('test_sdp', test_sdp_exe)

# Test RTP
test_rtp_exe = executable('test_rtp',
  'tests/test_rtp.vala',
  dependencies: [solas_rtp_dep],
  include_directories: solas_inc
)
test('test_rtp', test_rtp_exe)

# Test RTCP
test_rtcp_exe = executable('test_rtcp',
  'tests/test_rtcp.vala',
  dependencies: [solas_rtcp_dep],
  include_directories: solas_inc
)
test('test_rtcp', test_rtcp_exe)

# Test SRTP
test_srtp_exe = executable('test_srtp',
  'tests/test_srtp.vala',
  dependencies: [solas_srtp_dep],
  include_directories: solas_inc
)
test('test_srtp', test_srtp_exe)

# Test Media
test_media_exe = executable('test_media',
  'tests/test_media.vala',
  dependencies: [solas_media_dep],
  include_directories: solas_inc
)
test('test_media', test_media_exe)

# Test Jitter
test_jitter_exe = executable('test_jitter',
  'tests/test_jitter.vala',
  dependencies: [solas_jitter_dep],
  include_directories: solas_inc
)
test('test_jitter', test_jitter_exe)

# Test Congestion
test_congestion_exe = executable('test_congestion',
  'tests/test_congestion.vala',
  dependencies: [solas_congestion_dep],
  include_directories: solas_inc
)
test('test_congestion', test_congestion_exe)

# Test SFU
test_sfu_exe = executable('test_sfu',
  'tests/test_sfu.vala',
  dependencies: [solas_sfu_dep],
  include_directories: solas_inc
)
test('test_sfu', test_sfu_exe)

# Test HLS
test_hls_exe = executable('test_hls',
  'tests/test_hls.vala',
  dependencies: [solas_distribution_dep],
  include_directories: solas_inc
)
test('test_hls', test_hls_exe)

# Test Network
test_network_exe = executable('test_network',
  'tests/test_network.vala',
  vala_args: ['--vapidir=' + meson.current_source_dir() / 'src/crypto', '--pkg=solas_crypto'],
  dependencies: [solas_network_dep, solas_sfu_dep],
  include_directories: solas_inc
)
test('test_network', test_network_exe)

# Test Signaling
test_signaling_exe = executable('test_signaling',
  'tests/test_signaling.vala',
  vala_args: ['--vapidir=' + meson.current_source_dir() / 'src/crypto', '--pkg=solas_crypto'],
  dependencies: [solas_server_dep],
  include_directories: solas_inc
)
test('test_signaling', test_signaling_exe)

# Test Server
test_server_exe = executable('test_server',
  'tests/test_server.vala',
  vala_args: ['--vapidir=' + meson.current_source_dir() / 'src/crypto', '--pkg=solas_crypto'],
  dependencies: [solas_server_dep],
  include_directories: solas_inc
)
test('test_server', test_server_exe)

# Test CLI
test_cli_exe = executable('test_cli',
  'tests/test_cli.vala',
  dependencies: [solas_cli_dep],
  include_directories: solas_inc
)
test('test_cli', test_cli_exe)

# Test Bench
test_bench_exe = executable('test_bench',
  'tests/test_bench.vala',
  vala_args: ['--vapidir=' + meson.current_source_dir() / 'src/crypto', '--pkg=solas_crypto'],
  dependencies: [solas_bench_dep],
  include_directories: solas_inc
)
test('test_bench', test_bench_exe)
