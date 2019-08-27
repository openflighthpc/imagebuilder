#!/bin/bash

export IMAGENAME=OPENFLIGHTHUB`date +%d%m%y%H%M`
MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export CUSTOMSCRIPT=$MYDIR/custom/openflighthub.bash

bash $MYDIR/makeBase.bash
