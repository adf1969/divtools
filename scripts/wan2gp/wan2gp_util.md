That's not a bad idea, but is NOT the exact way I want you to implement that.
I would prefer if there was a SETTING in the file, or even in the .env.wan2gp that allowed me to SPECIFY the location for the ckpts link destination.
If that is specified, it creates it and links the file.
However, if it does that, and doesn't FIRST check the contents, what it REALLY needs to do, is MOVE all the contents in the ckpts folder (or copy it) to the DESTINATION location, if it doestn't exist.

And those sorts of tasks are NOT tasks I want a "service" at launch to perform.
Best to create a util script that can do these sorts of tasks, reading the .env.wan2gp file in the wan2gp folder in scripts and doing what it says.
Write a script called:
wan2gp_util.sh

Every flag should have 3 versions:
-<flagname> --<flagname> -<1-2 letter name>
The 1-2 letter name, is just a 1-2 letter version.
For -relocate-ckpts, it would be: -rc

It should provide the following functionality:
* Relocate the ckpts folder and create a link to the destination, based upon the settings in $DIVTOOLS/scripts/wan2gp/.env.wan2gp
  * flag: -relocate-ckpts
    When this relocation takes place, it needs to create the destination folder, if it doesn't exist.
    IF the folder does exist, it can check the contents, to see if it matches the contents in the existing ckpts folder.
    If it doesn't, it should cp the ckpts contents to the destination location.
    Once that is done, it should MOVE the ckpts folder to ckpts.ORIG
    It should then create the soft-link from ckpts -> destination location

* Relocate the loras folder
  * flag: -relocate-loras
  * This would be handled simialr to the ckpts folder

