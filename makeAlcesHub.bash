#!/bin/bash

export IMAGENAME=ALCESHUB
MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export CUSTOMSCRIPT=$MYDIR/custom/alceshub.bash

bash -e $MYDIR/makeBase.bash
