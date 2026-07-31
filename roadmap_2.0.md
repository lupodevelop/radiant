# Radiant 2.0

Questo file raccoglieva il piano che ha portato alla release 2.0. Le funzionalità descritte
sono ora implementate; per il lavoro futuro fare riferimento a [ROADMAP.md](ROADMAP.md).

## Cosa è entrato in 2.0

- Facciata compatibile con `import radiant`.
- Implementazione divisa nei moduli `radiant/router`, `request`, `context`, `response`,
  `middleware` e `testing`.
- `RadiantError` al posto di `Error(Nil)` per accessori request e reverse routing.
- `wrap` per middleware applicati a un singolo handler.
- `key_named` per context key namespaced.
- Supporto QUERY tramite `query_method`, `query_route` e `any`.
- HEAD, OPTIONS, CORS e reverse routing documentati e coperti da test.
- Guide esterne aggiornate per Mist, Wisp, testing e migrazione 1.x → 2.0.

## Limiti intenzionali

Radiant resta un router e un set di middleware essenziali. Non include sessioni, cookie, CSRF,
WebSocket, template rendering o accesso al database. Per questi aspetti usare Wisp o librerie
dedicate.

Il limite `get1`–`get6` deriva dall’assenza di generics variadici in Gleam. Oltre sei parametri,
raggruppare i valori in un tipo di dominio e usare un handler di parsing dedicato.

Le context key sono tipizzate nel codice Gleam, ma l’identità runtime è basata sul nome. Usare
sempre `key_named("modulo", "nome")` per evitare collisioni.
