#!/bin/sh
nvme format "$DEVICE" --lbaf=1 --ses=1 --force #WARN: Only works if there is an lsbaf of index 1.
