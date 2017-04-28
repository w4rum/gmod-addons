# TTT Poison Dart Gun
A silenced gas pistol that fires a neurotoxin bullet which will slowly kill anyone it hits and slightly obscure the victims vision.

# Changes
I didn't create the original addon, I merely changed/added a few things:
- Forced the client to download the materials for this addon as well, removing a bug where the gun and it's shop icon would be missing and therefore be displayed as a red error text / black-purple checkered box. This is currently implemented by hardcoding a link to this workshop item.
- Added a "nausea" effect when poisoned by using motion blur and a yellow overlay
- Changed the damage encoding and removed some information from it: The poisoned victim will no longer get damage reports (red bars on the side of the screen) pointing towards the attacker current location.
- Added configuration options via CVars for ammo and the poison effect
- Changed default values:
    - onhit-damage: 5 (25 head) -> 0
    - poison_ticks: infinite -> 34
    - ammo: 3 -> 1

# Configuration
The addon works out of the box. You may, however, change some of the default settings:
- ttt_poisondart_interval - (default 1) The amount of seconds between each damage tick of the poison
- ttt_poisondart_damage - (default 3) The amount of damage each tick of the poison deals
- ttt_poisondart_ticks - (default 34) The amount of ticks the poison lasts before wearing off
- ttt_poisondart_ammo - (default 1) The amount of ammo a player gets when first purchasing the poison dart gun

# Credits
TFlippy - for creating the original addon. [Check out his workshop!](http://steamcommunity.com/id/TFlippy/myworkshopfiles/?appid=4000)
