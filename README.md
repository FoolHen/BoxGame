# BoxGame
Minigame for Battlefield 3 / Venice Unleashed.

## Set up
Set the map to ``MP_Subway RushLarge0 2`` and include [BlueprintManager](https://github.com/BF3RM/BlueprintManager) mod. Round will start when two players have loaded in. When a round ends it will automatically restart.

## Config
It's recommended to limit the number of players accordingly to the playable surface, best is between 2 and 8 players. To adjust the size, change ``AreaWidth`` ``AreaLength`` and ``AreaHeight`` in ``ext/Shared/config.lua``.

There are 3 different modes that you can change as well in said config:

- ``RoundMode.Normal``: Team gamemode. Default mode. Players spawn on top of boxes separated by a wall, with an M416 and a grenade launcher. Shooting grenades to the boxes breaks them, allowing the creation of paths leading to the enemy.

- ``RoundMode.Normal_NoWeapons``: Team gamemode. Same as previous mode, except that players spawn with only the grenade launcher. The only way to win is to make all enemies fall to their deaths.

- ``RoundMode.Flat``. Free-for-all. Players spawn with only the grenade launcher. The area is only one box high. The only way to win is to be the last one standing on the plataform.

These mods can also be changed ingame by typing ``!normal``, ``!noweapons`` and ``!flat`` in chat. Keep in mind that these commands can be typed by anyone.