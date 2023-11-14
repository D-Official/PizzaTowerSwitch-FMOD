# Important Information
This repository contains select code files related to FMOD from the unofficial Pizza Tower Switch port.
With these files, the game's audio code will become 100% GML, allowing it to be ported more easily.

As per the license, and the comment inside fmod.gml: You can do whatever with this code! (and credit would be nice). Go nuts! Port the game to your phone using this! Your smart microwave! 
Anything! It's yours!


This repository will also serve as an issue tracker: If you find any issue in the port please open an issue here.
***Note that issues should be for the Switch port only, and that any issues opened regarding this port running on Switch emulators will be ignored unless replicated on real hardware.
Same goes for the Android port of the Switch port (Yes, that's a thing)***

# Less Important Information

The official way to obtain the port is through Tinfoil shops. Pretty much all the popular ones have it, as far as I know.

SR 4 released on 13/11/2023. If you want to verify that the file you have is good:
```
Name: Pizza Tower v1.0.5952 SR 4 [05000FD261232000][v0].nsp
Size: 360999128 bytes (344 MiB)
MD5: e286b8c4f3db3b6ba14adff07cb34036
SHA256: ad6be6ef445e56d8cfeb22e271452e7375dbe8ea26d9fc5dd896eea4ed36b304

This repository is replacing https://github.com/TurtleHouse/PizzaTowerSwitch-FMOD
as the person managing the owner account has lost access to it.

```
# New method of distribution
Starting from SR 4 this repository will (MAYBE, might not happen if Tinfoil shops become available again) also distribute encrypted .bin files of the port ***in the releases tab*** (if it's empty, I haven't decided to do this yet). In order to decrypt it, you must
1. Take the data.win of the matching PC Pizza Tower version
2. Remove every other (odd) byte
3. Duplicate the bytes until it matches in size with the .bin
4. XOR the new bytes we made with the bytes of the encrypted .bin file

The new list of bytes is the bytes for the NSP. By doing this, you have either proven ownership of Pizza Tower,
or you have committed piracy, in which case that action is proof that you know how to pirate games anyways and that none of this matters.

Luckily for you, the `decrypt.py` script included in the repository does all of this automatically! Just be sure to place all the right files with the correct names next to the script.

