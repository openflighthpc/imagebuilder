# imagebuilder


## Notes added by Stu

To build an image with a custom script, run:

    IMAGENAME="myimagename" CUSTOMSCRIPT=/path/to/custom.bash bash makeBase.bash

IMAGENAME will automatically have the date appended and the CUSTOMSCRIPT can be an upstream script to be curled and ran.
