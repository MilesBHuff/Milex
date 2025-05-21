#!/usr/bin/env bash
function auto-hardlink {
    BIN='/usr/local/bin/rdfind'
    "$BIN" \
        -ignoreempty      'true' \
        -followsymlinks   'false' \
        -removeidentinode 'true' \
        -checksum         'sha256' \
        -deterministic    'true' \
        -makesymlinks     'false' \
        -makehardlinks    'true' \
        -deleteduplicates 'false' \
        -makeresultsfile  'true' \
        -outputname       'rdfind-results.txt' \
        "$@" 2>&1 | tee   'rdfind-output.txt'
#       -dryrun true \
}
