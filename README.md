# Really important information
To decrypt the .bins in the releases tab, see the relevant section below.
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

I don't remember when SR 1 and SR 2 were released.
SR 3 released on 9/5/2023.
SR 4 released on 13/11/2023.

SR 5 released on 24/11/2023, and SR 5 Fix 1 on 29/11/2023. If you want to verify that the file you have is good:
```
Name: Pizza Tower v1.0.5952 SR 5 [05000FD261232000][v0].nsp
Size: 361048064 bytes (344 MiB)
SHA256: 6c6b7fbd51d023bf6cc9cd5b98066c8d49c8c01c3a191cc722959818240b0203
MD5: 3fba5e517cdfd9072303919f1c6e3cc5
```
Sadly, SR 5 Fix 1 is NOT the same size as SR 5, like SR 5 was to SR 4. It is bigger by 48936 bytes. Still Praise Allah :pray:

The port will always tell you the latest version if you launch it while connected to the internet. The information will be available on the bottom right of the save select screen.

This repository is replacing https://github.com/TurtleHouse/PizzaTowerSwitch-FMOD
as the person managing the owner account has lost access to it.

# New method of distribution
In order to decrypt the .bins found in the releases tab, you must:

1. Take the bytes from the data.win of the matching PC Pizza Tower version
2. Remove every other (odd) byte
3. Duplicate the bytes until it matches in size with the .bin
4. XOR the new bytes we made with the bytes of the encrypted .bin file

(If you don't know how to do any of that, or if you're lazy, the `decrypt.py` Python script included in the repository's source files does all of these steps automatically! Simply place the data.win and the ENCRYPTED_SR_x.bin file in the same folder and run the script.)

The new list of bytes is the bytes for the NSP. By doing this, you have either proven ownership of Pizza Tower,
or you have committed piracy, in which case that action is proof that you know how to pirate games anyways and that none of this matters.
