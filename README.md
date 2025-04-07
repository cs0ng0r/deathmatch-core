# DM Core - FiveM Deathmatch Core

A comprehensive deathmatch core for FiveM servers with security features, HUD, and leaderboards.

## Features

### Core Gameplay
- Money system with cash and bank accounts
- Kills and deaths tracking with rewards/penalties
- Automatic respawn at random spawn points
- Character appearance saving (using Illenium Appearance)
- Custom HUD with money, stats, weapon info, and location display

### Security Features
- Security token system to prevent unauthorized server interactions
- Weapon blacklist to prevent cheaters from using certain weapons
- Anti-cheat features:
  - God mode detection
  - Speed hack detection
  - Health hack detection
  - Suspicious vehicle spawn detection
  - Blacklisted weapon detection
- Tiered response system for detected cheating:
  - Warning for minor violations
  - Force respawn for moderate violations
  - Kick/ban for severe violations
- Discord webhook integration for security alerts
- Comprehensive security event logging

### Administrative Tools
- Ban and unban commands
- Leaderboard refresh command
- Security event logging to database

### UI Components
- Modern HUD displaying:
  - Cash and bank balance
  - Kills, deaths, and K/D ratio
  - Current weapon and ammo
  - Current location (street and zone)
- In-game notification system
- Interactive leaderboard (press F10 to toggle)

## Installation

1. Place the `dm-core` folder in your FiveM server's resources directory
2. Add `ensure dm-core` to your server.cfg file
3. Make sure you have the following dependencies:
   - oxmysql (or mysql-async)
   - illenium-appearance (optional, for skin saving)
4. Configure the `config.lua` file to your preferences
5. Start your server

## Configuration

The `config.lua` file contains all configurable options:

- Money settings (starting cash/bank, kill rewards, death penalties)
- Security settings (token lifetime, weapon blacklist)
- HUD settings (toggle various HUD elements)
- Spawn points (add or modify player spawn locations)
- Discord webhook for security alerts

## Commands

### Player Commands
- `/leaderboard` - Display the server leaderboard
- `/saveskin` - Save your current character appearance
- `/withdraw [amount]` - Withdraw money from bank to cash
- `/deposit [amount]` - Deposit cash into bank
- `F10` - Toggle leaderboard display
- `H` - Toggle HUD display

### Admin Commands
- `/ban [player_id] [days] [reason]` - Ban a player
- `/unban [identifier]` - Unban a player
- `/refreshleaderboard` - Force refresh the leaderboard cache

## Security System

The DM Core includes a robust security system to help prevent and detect cheating:

1. **Token System**: All client-server communications are verified with security tokens
2. **Weapon Blacklist**: Prevents players from using overpowered or modded weapons
3. **Anti-Cheat**: Detects common cheats like god mode, health hacks, and speed hacks
4. **Action System**: Takes appropriate action based on violation severity
5. **Logging**: All security events are logged to the database and optionally to Discord

## Database Structure

The system uses two main tables:

1. `players` - Stores player data:
   - Identifiers, name
   - Cash, bank balances
   - Kills, deaths
   - Character appearance
   - Ban information

2. `dm_logs` - Logs all significant player actions:
   - Security events
   - Money transactions
   - Kills and deaths
   - Chat messages
   - Login/logout events

## Developers

The DM Core provides several exports for developers to integrate with:

### Server Exports
- `getPlayer(source)` - Get player data for specified source
- `updateMoney(source, amount, type)` - Update player's money
- `getLeaderboard(callback)` - Get current leaderboard data

### Client Exports
- `getPlayerData()` - Get local player data

## License

This resource is open source and free to use/modify.

## Support

For issues or suggestions, please contact the developer.