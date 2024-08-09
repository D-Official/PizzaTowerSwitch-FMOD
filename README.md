# Really important information
To decrypt the .bins in the releases tab, see the relevant section below.
# Important Information
This repository contains the FMOD replacement code I created for the unofficial Pizza Tower Switch port.
With this file, the game's audio code becomes 100% GML, allowing it to be ported more easily.

As per the license, and the comment inside fmod.gml: You can do whatever with this code! (and credit would be nice). Go nuts! Port the game to your phone using this! Your smart microwave! 
Anything! It's yours!


This repository will also serve as an issue tracker: If you find any issue in the port please open an issue here.
***Note that issues should be for the Switch port only, and that any issues opened regarding this port running on Switch emulators will be ignored unless replicated on real hardware.
Same goes for the Android port of the Switch port (Yes, that's a thing)***

# Less Important Information

The official way to obtain the port is through HERE.


SR - Switch Release.
I don't remember when SR 1 and SR 2 were released.
SR 3 released on 9/5/2023.
SR 4 released on 13/11/2023.
SR 5 released on 24/11/2023, and SR 5 Fix 1 on 29/11/2023. 
SR 6 released on 08/08/2023.
If you want to verify that the file you have is good:
```
Name: Pizza Tower SR 6 [05000FD261232000][v0]
Size: 435466456 bytes (415 MB)
SHA256: 5A4A59D7688C4F21F0ACD743FEBCD8CED4CE4F272DDF1FD024CC57C74D092571
```

The port will always tell you the latest version if you launch it while connected to the internet. The information will be available on the bottom right of the save select screen.

This repository is replacing https://github.com/TurtleHouse/PizzaTowerSwitch-FMOD
as the person managing the owner account has lost access to it.

# New method of distribution
In order to decrypt the .bins found in the releases tab, you must:

1. Grab the .bin from the releases tab that has a Pizza Tower version in its name that you own. (It will not work if you use the data.win for, say V1.1.053 with the encrypted bin labelled with V1.1.063. It has to match exactly).
2. Install Python and download the decrypt.py script found in this repository's source code. You can do this by clicking on the file on the GitHub page, and locating the small "Download Raw File" icon above the file contents.
3. Copy the data.win from your Pizza Tower installation (Make sure it has NO MODS - it MUST be clean), the .py script and the .bin file to the same folder, and run the script.
4. Enjoy your .nsp!

By doing this you have "proven" ownership of Pizza Tower. And if the copy you used to prove ownership is pirated... That act of piracy is now also tied to the Switch port, as if you pirated it directly. This makes this method 100% Super Legal! I promise!
