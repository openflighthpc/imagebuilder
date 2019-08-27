#!/bin/bash

export IMAGENAME=ALCESHUB`date +%d%m%y%H%M`
MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export CUSTOMSCRIPT=$MYDIR/custom/alceshub.bash

bash $MYDIR/makeBase.bash
