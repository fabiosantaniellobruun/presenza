# Presenza

**Il Mac si blocca quando ti alzi.**

Presenza è una piccola app per la barra dei menu di macOS. Guarda nella fotocamera e, quando non ti
vede più, fa uscire dal notch un avviso con il conto alla rovescia, poi blocca lo schermo. Se ti eri
solo girato un attimo, premi **Annulla**.

> L'interfaccia è in **italiano** e in **inglese**: segue la lingua del sistema, oppure la scegli
> nelle Impostazioni. [English README](README.md).

## Requisiti

- macOS 14 Sonoma o successivo, su Mac con Apple silicon o Intel.
- Una fotocamera: quella del Mac o una esterna.

## Installazione

1. Scarica `Presenza-1.0.dmg`.
2. Aprilo e trascina **Presenza** in **Applicazioni**.
3. Avvia Presenza e consenti l'accesso alla fotocamera quando macOS lo chiede. Presenza vive nella
   barra dei menu, con l'icona di un occhio (non c'è l'icona nel Dock).

### Il primo avvio

Presenza non è firmata con un Developer ID di Apple (a pagamento): macOS non può verificarla e la
prima volta la blocca. Basta autorizzarla una volta:

1. Apri Presenza. macOS dice che non è stata aperta perché Apple non ha potuto verificarla: premi **Fine**.
2. Apri **Impostazioni di Sistema → Privacy e sicurezza** e scorri fino a *Sicurezza*: accanto a
   "Il Mac ha bloccato Presenza.app per garantire la sicurezza" premi **Apri comunque**, e conferma
   con la password o il Touch ID.

Oppure, dal Terminale, togli il segno di quarantena che il browser ha messo sul file scaricato:

```bash
xattr -dr com.apple.quarantine /Applications/Presenza.app
```

## Come si usa

- Quando la fotocamera non vede né la tua faccia né testa e spalle, in alto al centro compare
  **"Te ne stai andando?"** con i secondi che mancano. Allo zero lo schermo si blocca.
- **Annulla** ferma il blocco e lascia stare per 30 secondi.
- Quando torni, sblocca il Mac come sempre: Touch ID, Apple Watch o password. Presenza non sblocca:
  macOS non lo permette, e non sarebbe sicuro, perché riconosce *una* persona, non *te*.
- Dal menu dell'occhio: **Pausa**, **Blocca ora** e **Impostazioni…**, dove scegli dopo quanti
  secondi bloccare (da 3 a 60, di base 8), la lingua e se aprire Presenza all'avvio del Mac.

## Privacy

Le immagini della fotocamera vengono analizzate sul Mac, una al secondo, con il framework Vision di
Apple. Non vengono salvate né inviate: Presenza non usa la rete. Mentre lo schermo è bloccato o
Presenza è in pausa, la fotocamera è spenta.

## Disinstallare

Se l'avevi messa all'avvio del Mac, togli prima la spunta nelle Impostazioni. Poi esci da Presenza
dal menu dell'occhio e trascinala nel Cestino. Le preferenze si tolgono con
`defaults delete it.fabiosbruun.Presenza`.

## Compilare dal codice

Serve Xcode 26 o successivo (per `swiftc` e per `actool`, che compila l'icona).

```bash
./build.sh
```

crea `Presenza.app`, firmata ad hoc, e ne esegue il selftest.

```bash
./build.sh dmg
```

crea anche `dist/Presenza-<versione>.dmg`, da distribuire.
