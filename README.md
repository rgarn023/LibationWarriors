# Libation Warriors

Godot **4.7.1** mobile game: scan bottle barcodes to summon unique 16-bit **Libation Warriors**. Beverage type chooses the faction. Brand names and logos are never shown or stored.

## Factions

| Beverage | Faction |
|---|---|
| Rum | Pirate |
| Bourbon | Militiaman |
| Tequila | Bandit |
| Scotch | Druid |
| Vodka | Barbarian |
| Brandy / Cognac | Paladin |
| Gin | Alchemist |
| Liqueur / premade cocktails / other spirits listed as such | Bard |
| Red wine | Red Mage |
| White wine | White Mage |
| Other wine | Black Mage |
| Beer | Brawler |
| Sake | Samurai |
| Mead | Viking |
| Any other alcohol | Rogue |
| Non-alcoholic | Nimrod |

## Features

- Deterministic warrior generation from barcode (name, palette, ATK/DEF/HP, regular + special moves)
- One warrior per unique barcode (no duplicates)
- Collection browser
- Parties of 3
- Local turn-based battles (attack / special / defend)
- Online lobby (host/join via IP + ENet)
- Authentic 32×32 16-bit style sprites for all 16 factions

## Android APK

Built APK path after export:

`export/LibationWarriors.apk`

Package id: `com.libationwarriors.game`

### Rebuild

```bash
export PATH="$HOME/bin:$PATH"
export ANDROID_HOME="$HOME/android-sdk"
godot --headless --path . --export-debug "Android" export/LibationWarriors.apk
```

## Controls (mobile)

1. **Scan Bottle** — enter barcode, pick beverage type (optional category hint via Open Food Facts fields that exclude brand display), summon warrior  
2. **Collection** — view owned warriors  
3. **Party of Three** — assign 3 unique warriors  
4. **Battle** — local practice or online host/join  

Demo bottles are included on the scanner screen for quick testing.
