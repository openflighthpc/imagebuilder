#!/bin/bash

export IMAGENAME=OPENFLIGHTHUB
MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export CUSTOMSCRIPT=$MYDIR/custom/openflighthub.bash

bash -e $MYDIR/makeBase.bash
