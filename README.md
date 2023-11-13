# PizzaTowerSwitch-FMOD
This repository contains select code files related to FMOD from the unofficial Pizza Tower Switch port.
With these files, the game's audio code will become 100% GML, allowing it to be ported more easily.

The official way to obtain the port is through Tinfoil shops. Pretty much all the popular ones have it, as far as I know.

This repository will also serve as an issue tracker: If you find any issue in the port please open an issue here.
***Note that issues should be for the Switch port only, and that any issues opened regarding this port running on Switch emulators will be ignored unless replicated on real hardware.
Same goes for the Android port of the Switch port (Yes, that's a thing)***

This repository is replacing https://github.com/TurtleHouse/PizzaTowerSwitch-FMOD
as the person managing the owner account has lost access to it.

As per the license, and the comment inside fmod.gml: You can do whatever with this code! (and credit would be nice). Go nuts! Port the game to your phone using this! Your smart microwave! 
Anything! It's yours!

# New method of distribution
Starting from SR 4 this repository will (MAYBE, might not happen if Tinfoil shops become available again) also distribute encrypted .bin files of the port. In order to decrypt it, you must
1. Take the data.win of the matching PC Pizza Tower version
2. Remove every other (odd) byte
3. Duplicate the bytes until it matches in size with the .bin
4. XOR the new bytes we made with the bytes of the encrypted .bin file

The new list of bytes is the bytes for the NSP. By doing this, you have either proven ownership of Pizza Tower,
or you have committed piracy, in which case that action is proof that you know how to pirate games anyways and that none of this matters.

Luckily for you, the `decrypt.py` script included in the repository does all of this for you! Just be sure to place all the right files with the correct names next to the script.

