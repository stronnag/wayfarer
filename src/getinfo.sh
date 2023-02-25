#!/usr/bin/env bash

OUTPUT=${1:-wayvers.h}

TNOW=$(date -u +%FT%T)
NODE=$(uname -n)
PLAT=$(uname -smr)

CC=${CC:-cc}
LD=${LD-ld}

CVERS=$($CC -v 2>&1 | grep " version ")
VVERS=$(valac --version 2>&1)
LDVERS=$($LD -v 2>&1)
GITVERS=$(git rev-parse  --short HEAD)
GITBRANCH=$(git branch --show-current)
GITSTAMP=$(git log -1 --format=%cI)

> $OUTPUT echo "#define BUILDINFO \"${TNOW}Z ${PLAT} ${NODE}\""
>> $OUTPUT echo "#define COMPINFO \"${CVERS} / ${LDVERS} / ${VVERS}\""
>> $OUTPUT echo "#define WAYFARER_GITVERS \"${GITVERS}\""
>> $OUTPUT echo "#define WAYFARER_GITBRANCH \"${GITBRANCH}\""
>> $OUTPUT echo "#define WAYFARER_GITSTAMP \"${GITSTAMP}\""
