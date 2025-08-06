# QBX HeliCam Configuration

Dette scriptet har blitt betydelig forbedret med en omfattende konfigurasjonsstruktur som gjør det enkelt å tilpasse alle aspekter av helikopterkameraet.

## Konfigurasjonsfiler

### `config/client.lua`
Hovedkonfigurasjonfil for client-side innstillinger:

#### Vehicle Authorization
```lua
authorizedHelicopters = {
    [`polmav`] = true,    -- Legg til flere helikoptermodeller her
}
```

#### Camera Settings
- `fovMax/fovMin`: Kameraets zoom-område
- `zoomSpeed`: Hvor raskt kameraet zoomer
- `leftRightSpeed/upDownSpeed`: Panorering hastighet
- `raycastDistance`: Hvor langt kameraet ser etter kjøretøy
- `attachOffset`: Kameraets posisjon på helikopteret

#### Performance Settings
- `vehicleCheckDelay`: Hvor ofte scriptet sjekker for kjøretøy (ms)
- `scanUpdateDelay`: Hvor ofte scan-fremgang oppdateres (ms)
- `vehicleInfoUpdateDelay`: Hvor ofte kjøretøyinfo oppdateres (ms)
- `speedUpdateThreshold`: Hastighetsforskjell før oppdatering (km/h)

#### Keybind Settings
- Konfigurer standardtaster for alle funksjoner
- Aktiver/deaktiver funksjoner

### `config/shared.lua`
Delt konfigurasjon mellom server og client:
- Debug-innstillinger
- Versjonsjekk
- Entity state innstillinger

## Ytelsesforbedringer

Scriptet har blitt optimalisert for å forhindre "network overflow":

1. **Redusert NUI-meldingsfrekvens**: Fra 10ms til 50ms for skanning
2. **Throttled oppdateringer**: Kun oppdater når data faktisk endres
3. **Konfigurerbare delays**: Alle timer-verdier kan justeres
4. **Raycast-optimalisering**: Sjekker kjøretøy hver 250ms i stedet for hver frame

## Tilpasning

### Legge til nye helikoptermodeller:
```lua
authorizedHelicopters = {
    [`polmav`] = true,
    [`buzzard`] = true,
    [`maverick`] = true,
    -- Legg til flere her
}
```

### Justere ytelse:
```lua
performance = {
    vehicleCheckDelay = 250,        -- Reduser for raskere respons
    scanUpdateDelay = 50,           -- Reduser for raskere skanning
    vehicleInfoUpdateDelay = 250,   -- Reduser for hyppigere oppdateringer
}
```

### Endre kontroller:
```lua
controls = {
    toggleCamera = 51,              -- E-taste
    toggleVision = 25,              -- Høyre mus
    toggleLockOn = 22,              -- Mellomrom
}
```

## Feilsøking

Hvis du opplever problemer:

1. **Network Overflow**: Øk delay-verdiene i `performance`-seksjonen
2. **Treg respons**: Reduser delay-verdiene
3. **Kamera fungerer ikke**: Sjekk at helikoptermodellen er i `authorizedHelicopters`
4. **Debug**: Aktiver `debug = true` i `shared.lua`

## Kompatibilitet

Dette scriptet er optimalisert for QBX Framework og bruker:
- ox_lib for lokalisering og keybinds
- qbx_core for playerdata og kjøretøyfunksjoner
- Standard FiveM natives for kamera og helikopterfunksjoner
