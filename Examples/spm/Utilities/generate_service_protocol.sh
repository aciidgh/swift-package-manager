#!/usr/bin/env bash
#
# This source file is part of the Swift.org open source project
#
# Copyright (c) 2020 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See http://swift.org/LICENSE.txt for license information
# See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRCROOT="`cd "${__dir}/..";pwd`"
SOURCES=${SRCROOT}

set -x

${__dir}/build_proto_toolchain.sh

TOOLCHAIN_BIN=${__dir}/tools/bin
PROTO_PATH=${SOURCES}/SPMServiceProtocol/Protos
GEN_PATH=${SOURCES}/SPMServiceProtocol/Generated
rm -rf ${GEN_PATH}
mkdir -p ${GEN_PATH}

${TOOLCHAIN_BIN}/protoc -I=${PROTO_PATH} \
    --plugin=${TOOLCHAIN_BIN}/protoc-gen-grpc-swift \
    --plugin=${TOOLCHAIN_BIN}/protoc-gen-swift \
    --swift_out=${GEN_PATH} \
    --grpc-swift_out=${GEN_PATH} \
    --swift_opt=Visibility=Public \
    --grpc-swift_opt=Visibility=Public \
    $(find ${PROTO_PATH} -name \*.proto)