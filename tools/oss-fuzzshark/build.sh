#!/bin/bash -eux
# Copyright 2017 Google Inc.
#
# SPDX-License-Identifier: GPL-2.0-or-later

# List of dissectors compiled below, which should be turned off.
# This is done to avoid single fuzzer (like IP) to call UDP protocols, which can go back to IP, and so on..
# While doing so might find some bugs, but it's likely to be the problem for too big corpus in oss-fuzzer
# (see: https://github.com/google/oss-fuzz/issues/1087).
# + udplite - it's sharing most of code with UDP.
DISSECTOR_LIST='"ip", "udp", "udplite", "ospf", "bgp", "bootp", "json"'

FUZZ_DISSECTORS="ip"

FUZZ_IP_PROTO_DISSECTORS="udp ospf"

FUZZ_TCP_PORT_DISSECTORS="bgp"
# FUZZ_TCP_PORT_DISSECTORS="$FUZZ_TCP_PORT_DISSECTORS bzr"   # disabled, cause of known problem.
# FUZZ_TCP_PORT_DISSECTORS="$FUZZ_TCP_PORT_DISSECTORS echo"  # disabled, too simple.

FUZZ_UDP_PORT_DISSECTORS="dns bootp"
# FUZZ_UDP_PORT_DISSECTORS="$FUZZ_UDP_PORT_DISSECTORS bfd"   # disabled, too simple.

FUZZ_MEDIA_TYPE_DISSECTORS="json"

# TODO: support specifing targets in args. Google oss-fuzz specifies 'all'.

# generate_fuzzer <fuzzer_target> <fuzzer_cflags>
generate_fuzzer()
{
  local fuzzer_target="$1" fuzzer_cflags="$2" fuzzer_name

  fuzzer_name="fuzzshark_$1"

  $CC $CFLAGS -I $WIRESHARK_INSTALL_PATH/include/wireshark/ `pkg-config --cflags glib-2.0` \
      $SRC/wireshark/tools/oss-fuzzshark/fuzzshark.c \
      -c -o $WORK/${fuzzer_name}.o \
      $fuzzer_cflags -DFUZZ_DISSECTOR_LIST="$DISSECTOR_LIST"

  $CXX $CXXFLAGS $WORK/${fuzzer_name}.o \
      -o $OUT/${fuzzer_name} \
      ${WIRESHARK_FUZZERS_COMMON_FLAGS}

  echo -en "[libfuzzer]\nmax_len = 1024\n" > $OUT/${fuzzer_name}.options
  if [ -d "$SAMPLES_DIR/${fuzzer_target}" ]; then
    zip -j $OUT/${fuzzer_name}_seed_corpus.zip $SAMPLES_DIR/${fuzzer_target}/*/*.bin
  fi
}

WIRESHARK_FUZZERS_COMMON_FLAGS="-lFuzzingEngine \
    -L"$WIRESHARK_INSTALL_PATH/lib" -lwireshark -lwiretap -lwsutil \
    -Wl,-Bstatic `pkg-config --libs glib-2.0` -pthread -lpcre -lgcrypt -lgpg-error -lz -Wl,-Bdynamic"

for dissector in $FUZZ_DISSECTORS; do
  generate_fuzzer "${dissector}" -DFUZZ_DISSECTOR_TARGET=\"$dissector\"
done

for dissector in $FUZZ_IP_PROTO_DISSECTORS; do
  generate_fuzzer "ip_proto-${dissector}" "-DFUZZ_DISSECTOR_TABLE=\"ip.proto\" -DFUZZ_DISSECTOR_TARGET=\"$dissector\""
done

for dissector in $FUZZ_TCP_PORT_DISSECTORS; do
  generate_fuzzer "tcp_port-${dissector}" "-DFUZZ_DISSECTOR_TABLE=\"tcp.port\" -DFUZZ_DISSECTOR_TARGET=\"$dissector\""
done

for dissector in $FUZZ_UDP_PORT_DISSECTORS; do
  generate_fuzzer "udp_port-${dissector}" "-DFUZZ_DISSECTOR_TABLE=\"udp.port\" -DFUZZ_DISSECTOR_TARGET=\"$dissector\""
done

for dissector in $FUZZ_MEDIA_TYPE_DISSECTORS; do
  generate_fuzzer "media_type-${dissector}" "-DFUZZ_DISSECTOR_TABLE=\"media_type\" -DFUZZ_DISSECTOR_TARGET=\"$dissector\""
done
