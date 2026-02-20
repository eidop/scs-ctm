# SCS KUNDEPORTAL — FULLSTENDIG STRUKTURDOKUMENT
> Laget for AI-assistenter. Bruk dette som utgangspunkt for alle rebuilds og endringer.
> Sist oppdatert: Feb 2026 | Fil: scs-ctm-v10.html (~163KB, ~2530 linjer)

---

## 1. OVERORDNET ARKITEKTUR

Én enkelt HTML-fil. Ingen rammeverk, ingen bundler, ingen CDN-avhengigheter.
Vanilla JS + CSS-variabler + inline SVG/charts.

```
scs-ctm-v10.html
├── <head>          → Google Fonts (Instrument Sans, Syne), CSS-variabler, alle stiler
├── <body>
│   ├── #v-login    → Innloggingsskjerm (alltid synlig ved start)
│   ├── #v-admin    → Admin-grensesnitt (skjult til innlogging)
│   └── #v-client   → Klient-grensesnitt (skjult til innlogging)
└── <script>        → ALL JavaScript (ett stort inline script-tag)
```

**Synlighet styres av CSS-klassen `.on`** — elementer med `display:none` som default, `.on` gir `display:block/flex`.

---

## 2. DESIGN-SYSTEM

### Fargevariabler (CSS custom properties)
```css
--bg      /* Bakgrunn: mørk (default dark mode) */
--s2      /* Overflate 2: litt lysere */
--s3      /* Overflate 3: enda lysere (kort, rader) */
--b1      /* Border 1: svak */
--b2      /* Border 2: medium */
--tx      /* Tekst: primær */
--m2      /* Tekst: sekundær/dempet */
--mu      /* Tekst: veldig dempet */
--g       /* Grønn aksent: #00e5a0 */
--b1c     /* Blå aksent: #2f8bff */  (NB: --b1 er border, --b1c er blå farge)
--wa      /* Gul/advarsel: #ffaa00 */
--er      /* Rød/feil */
```

### Typografi
- **Instrument Sans** — ALL brødtekst, labels, knapper, tall
- **Syne** — KUN logo/merkevare (`.asb-logo`, `.l-logo`) og noen dekorative elementer
- **ALDRI Syne font-weight:800 på sidehoder** — bruk Instrument Sans 700

### Nøkkel-CSS-klasser
```
.btn          → Base knapp-stil
.btn-g        → Grønn primærknapp
.btn-gh       → Ghost/sekundærknapp
.btn-sm       → Liten knapp
.btn-er       → Rød/farlig knapp
.btn-wa       → Gul/advarsel-knapp
.bge          → Badge (liten pill)
.ba           → Badge aktiv (grønn)
.bp           → Badge pause (gul)
.fgi          → Form input
.fgt          → Form textarea
.fgs          → Form select
.fgl          → Form label
.fg1          → Form group (wrapper div)
.ccard        → Innholdskort (hvit/mørk boks med border)
.cch          → Kortoverskrift-container
.cct          → Korttittel-tekst
.on           → Synlighetstoggle (legges til/fjernes dynamisk)
.toast        → Toast-melding (auto-animert)
.mo           → Modal overlay
.mhd          → Modal header
.mbd          → Modal body
.mft          → Modal footer
.mcl          → Modal close button
.mo-close     → Klikk lukker modal (event delegation)
.tier-alert   → Tier-begrensning-advarselsboks
.hint         → Demo-tipp-knapper på innloggingsskjermen
.tmn          → "Tiny muted note" — liten grå hjelpetekst
```

---

## 3. DATAMODELLER

### USERS (objekt, nøkkel = email)
```javascript
USERS = {
  'admin@simplycomplex.no': {
    pass: 'admin123',
    role: 'admin',
    name: 'Eido'
  },
  'kunde@regnskapclient.no': {
    pass: 'klient123',
    role: 'client',
    company: 'Regnskap AS',
    tier: 2,                      // 1=Liten, 2=Medium, 3=Stor
    icon: '🏢',
    color: '#2f8bff',
    agentIdx: [0, 2],             // Indekser inn i AGENTS-arrayen
    stats: { actions: 412, leads: 14, voices: 0 },
    avtaleKr: 11900,
    besparingKr: 52000,
    timeSaved: 68,
    apiKostKr: 1840,
    apiGrenseKr: 2500,
    contact: 'Kari Holm',
    // Runtime-felt (satt etter innlogging):
    keyOpenAI: '',
    keyVapi: '',
    keyElevenLabs: '',
    keyTwilioSid: '',
    keyTwilioToken: '',
    keyHubspot: '',
    n8nUrl: '',
    webhookUrl: '',
    voiceProvider: 'VAPI',        // 'VAPI' | 'ElevenLabs' | 'Twilio'
    generalKnowledge: '',         // Fritekst fra klienten, deles med alle agenter
  }
}
```

### AGENTS (array, index = agentIdx verdi)
```javascript
AGENTS = [
  {
    nm: 'Email Support',          // Navn
    em: '📬',                     // Emoji
    bg: 'rgba(0,229,160,0.1)',    // Bakgrunnsfarge for ikon
    ch: 'Gmail · HubSpot',        // Kanaler
    act: 412,                     // Handlinger totalt
    rate: 96,                     // Suksessrate %
    status: 'aktiv',              // 'aktiv' | 'pause'
    klient: 'Regnskap AS',        // Hvilket firma agenten tilhører (company-navn)
    // Valgfrie felt:
    tone: 'Profesjonell',         // 'Profesjonell' | 'Vennlig' | 'Uformell' | 'Teknisk'
    greeting: '',                 // Åpningshilsen
    knowledge: '',                // Kunnskap satt av ADMIN (read-only for klient)
    clientKnowledge: '',          // Kunnskap lagt inn av KLIENTEN
    clientFeedback: '',           // Innspill fra klient til SCS
    webhook: '',                  // n8n webhook URL for agenten
    voiceName: 'Sofia',           // Stemnavn for voice-agenter
  }
]
```
**10 demo-agenter:** idx 0-2 → Regnskap AS, idx 1,3-6 → Eiendom Nord, idx 7-9 → Tech Solutions

### CLIENTS_DEMO / CLIENTS (array)
```javascript
// CLIENTS_DEMO er master-data, CLIENTS er runtime (populeres ved demo-login)
CLIENTS_DEMO = [
  {
    n: 'Regnskap AS',             // Navn (må matche USERS.company)
    b: 'Regnskap',                // Bransje
    t: 2,                         // Tier (1/2/3)
    ag: 2,                        // Antall agenter
    act: 1189,                    // Handlinger
    avtale: 11900,                // Avtale kr/mnd
    besparing: 52000,             // Sparing kr/mnd
    apiKost: 1840,                // API-kostnad kr/mnd
    apiGrense: 2500,              // API-grense kr/mnd
    s: 'aktiv',                   // Status: 'aktiv' | 'pause' | 'arkivert'
    av: 'R',                      // Avatar-bokstav
    c: '#2f8bff',                 // Farge
    agentIdx: [0, 2],             // Agenter (indekser til AGENTS)
    voiceProvider: 'VAPI',        // Voice-leverandør for klienten
    // Valgfrie felt (settes runtime):
    webhook: '',                  // Klientens webhook URL
  }
]
```

### TIER_CFG
```javascript
TIER_CFG = {
  1: { name: 'Liten',  max: 5,  icon: '⚡', color: 'var(--t1)' },
  2: { name: 'Medium', max: 10, icon: '🚀', color: 'var(--t2)' },
  3: { name: 'Stor',   max: 20, icon: '🏆', color: 'var(--t3)' },
}
```

### Global state-variabler
```javascript
let CU = null;           // Current User — spreaded kopi av USERS-objekt + email
let DEMO_MODE = false;   // Settes til true NÅR demo-hint klikkes (FØR innlogging)
let loginRole = 'admin'; // Hvilken fane er aktiv på login-skjermen
let rtA = null;          // setInterval-ID for admin realtime
let rtC = null;          // setInterval-ID for klient realtime
```

---

## 4. AUTENTISERING OG FLOW

```
Bruker åpner side
  → v-login vises
  → Kan velge rolle-tab (admin/client)
  → Kan klikke demo-hint (setter DEMO_MODE=true FØR fill)
  
doLogin()
  → Sjekker USERS[email].pass
  → Setter CU = { ...u, email }
  → Hvis DEMO_MODE: fyller CLIENTS fra CLIENTS_DEMO
  → Skjuler v-login, viser v-admin eller v-client
  → Kaller bootAdmin() eller bootClient()

logout()
  → CU = null, DEMO_MODE = false, CLIENTS = []
  → Viser v-login igjen
```

**VIKTIG — DEMO_MODE timing:**
```javascript
// Riktig rekkefølge i hint-handler:
DEMO_MODE = true;                    // MÅ settes FØR value-fill
el('lin-em').value = d[0];           // Trigger IKKE keydown
el('lin-pw').value = d[1];
// Keydown-listener resetter kun DEMO_MODE på printable chars (e.key.length===1)
```

---

## 5. NAVIGASJON

### Admin-navigasjon (`aGo(pageId)`)
```javascript
// Skjuler alle .pg-elementer, viser #pageId
// Nav-knapper har data-page attributt
aGo('a-db')    // Dashboard
aGo('a-kl')    // Klienter
aGo('a-ag')    // Agenter
aGo('a-email') // E-post & Leads
aGo('a-api')   // API-kostnader
aGo('a-voice') // Voice
aGo('a-crm')   // CRM
aGo('a-int')   // Integrasjoner
aGo('a-ny')    // Ny agent
aGo('a-fak')   // Fakturering
aGo('a-tiers') // Tier-konfig
aGo('a-set')   // Innstillinger
aGo('a-log')   // Logg
aGo('a-usr')   // Brukere
```

### Klient-navigasjon (`cGo(pageId)`)
```javascript
// Skjuler alle .cpg-elementer, viser #cpg-{pageId}
// VIKTIG: ved nav til 'c-api' kalles setTimeout(renderClientAgentConfig, 60)
cGo('c-db')    // #cpg-c-db  — Dashboard
cGo('c-ag')    // #cpg-c-ag  — Mine agenter
cGo('c-akt')   // #cpg-c-akt — Aktivitetslogg
cGo('c-email') // #cpg-c-email — E-post & Leads
cGo('c-api')   // #cpg-c-api — API-nøkler + Agent-oppførsel
cGo('c-set')   // #cpg-c-set — Innstillinger
cGo('c-sup')   // #cpg-c-sup — Support
```

---

## 6. MODALER

Alle modaler har `class="mo"` og `id="m-xxx"`. Åpnes/lukkes med:
```javascript
openModal('m-upgrade')           // Statisk modal (alltid i DOM)
openDynModal('m-klient-det', html) // Dynamisk modal (innerHTML erstattes)
closeModal('m-klient-det')       // Lukker spesifikk modal
// Alle elementer med class="mo-close" lukker nærmeste modal ved klikk
```

**Statiske modaler (alltid i DOM):**
| ID | Innhold |
|----|---------|
| `m-newcl` | Ny klient-skjema (admin) |
| `m-cl-done` | Klient opprettet (bekreftelse) |
| `m-invuser` | Inviter bruker |
| `m-upgrade` | Oppgrader plan (klient) |
| `m-glemt-pw` | Glemt passord |

**Dynamiske modaler (bygges runtime):**
| ID | Funksjon | Bygges av |
|----|----------|-----------|
| `m-klient-det` | Klientdetaljer + pause/arkiver + agent-kunnskap | `visKlientDetaljer(cl)` |
| `m-edit-agent` | Rediger agent (admin) | inline i renderAgentCards |
| `m-edit-user` | Rediger bruker | inline i renderUsersTable |

---

## 7. ADMIN-GRENSESNITT

### Sider og hva de inneholder

**a-db — Admin Dashboard**
- `#adb-cl` — Antall klienter
- `#adb-ag` — Antall agenter  
- `#adb-leads` — Leads
- `#adb-act` — Handlinger
- `#a-feed` — Live aktivitetsfeed (pushAdminFeed())
- Charts: `#aa1`–`#aa4` (buildChart)
- Statistikk-kort med sanntidsoppdatering (rtA interval)

**a-kl — Klienter**
- `#cl-tbody` — Klienttabell (renderClientsTable)
- `#cl-search` — Søkefelt
- `#cl-tier-filter` — Tier-filter
- `#btn-newcl` → åpner `m-newcl`
- Klikk på rad → `visKlientDetaljer(cl)`

**a-ag — Agenter**
- `#ag-cards` — Agentkort (renderAgentCards)
- `#btn-pause-alle` — Pause alle
- Klikk på ✏️ → dynamisk agent-redigeringsmodal

**a-voice — Voice AI**
- Admin-kontrollert voice provider (tabs: VAPI / ElevenLabs / Twilio)
- Kost-kalkulator per agent
- Klient-dropdown for å sette provider per klient

### visKlientDetaljer(cl) — Admin klientmodal
Bygger dynamisk innhold i `m-klient-det`:
- Stats-grid (6 felt: bransje, tier, ROI, agenter, avtale, sparing)
- **Statusknapper:**
  - `#adm-kl-toggle` — ⏸ Pause / ▶ Aktiver (toggler `cl.s` og alle `AGENTS[idx].status`)
  - `#adm-kl-archive` — 📦 Arkiver / Gjenopprett
  - `#adm-kl-save` — 💾 Lagre (lagrer tone, kunnskap, greeting, webhook per agent)
- **Per-agent editor** (`#adm-ag-list`):
  - `.adm-ag-status` — select: aktiv/pause
  - `.adm-ag-tone` — select: Profesjonell/Vennlig/Uformell/Teknisk
  - `.adm-ag-greeting` — input: åpningshilsen
  - `.adm-ag-know` — textarea: agent-kunnskap (kun admin, read-only for klient)
  - `.adm-ag-webhook` — input: webhook URL
  - Alle har `data-idx` attributt (AGENTS-indeks)

### Ny klient (`m-newcl`)
Skjemafelt:
- `#nc-nm` — Firmanavn
- `#nc-br` — Bransje
- `#nc-em` — E-post
- `#nc-pw` + `#btn-nc-genpw` — Passord (auto-generer)
- `#nc-cp` — Kontaktperson
- `#tier-sel` — Tier (pickTier())
- `#nc-avtale`, `#nc-besparing` — Økonomi
- ROI-preview: `#nc-roi-val`, `#nc-netto-val`, `#nc-pct-val`
- Submit: `addClient()` → fyller `m-cl-done`

---

## 8. KLIENT-GRENSESNITT

### Topbar
- `#c-icon` — Firma-emoji
- `#c-name` — Firmanavn
- `#c-tbadge` — Tier-badge
- `#c-clk` — Klokke
- `#c-logout-btn` → logout()

### cpg-c-db — Dashboard
- `#c-s-act` — Handlinger (liveV-animert)
- `#c-s-leads` — Leads
- `#c-s-ag` — Agenter
- `#c-roi-hero` — ROI-verdi
- `#c-hero-avtale`, `#c-hero-besparing`, `#c-hero-netto` — Økonomi
- `#c-feed` — Live aktivitetsfeed
- `#c-chart1` — Aktivitetsgraf
- `#c-greet` — Velkomsthilsen
- `#c-tier-alert` / `#c-tier-warn` — Tier-advarsler

### cpg-c-ag — Mine agenter
- `#c-aglist` — Agentoversikt (renderClientAgList)
- `#c-agcards` — Agentkort med statistikk (renderClientAgCards)
- `#c-actlog` — Aktivitetslogg (renderClientActLog)
- `#c-ag-alert` / `#c-ag-alert-desc` — Max-agenter-advarsel

### cpg-c-api — API-nøkler + Agent-oppførsel
**API-nøkler (redigerbare inputs):**
- `#c-key-openai` — OpenAI API Key
- `#c-key-hubspot` — HubSpot Token
- `#c-voice-key-fields` — Dynamisk rendered basert på voiceProvider:
  - VAPI: `#c-key-vapi`
  - ElevenLabs: `#c-key-elevenlabs`
  - Twilio: `#c-key-twilio-sid` + `#c-key-twilio-token`
- `#c-key-sendgrid`, `#c-key-supabase` — Hidden inputs
- `#c-voice-provider-name`, `#c-voice-provider-desc` — Info om valgt provider
- `#c-n8n-url` — n8n URL
- `#btn-lagre-api-setup` → lagrer alle nøkler til CU-objektet

**n8n Webhook:**
- `#c-webhook-url` — Webhook URL input
- `#c-webhook-copy` — Kopiér til clipboard

**Agent-oppførsel (`#c-agent-config-list`):**
Rendres av `renderClientAgentConfig()`:
- **Generell kunnskap** (alltid synlig, også uten agenter):
  - `#cl-general-knowledge` — textarea (lagres til `u.generalKnowledge`)
  - `#cl-save-general-know` — Lagre-knapp
- **Per-agent kort** (én per agent i `u.agentIdx`):
  - Admin-kunnskap: read-only display av `a.knowledge`
  - `.cl-ag-knowledge` — textarea for klientens tilleggskunnskap
  - `.cl-ag-feedback` — textarea for innspill til SCS
  - `.cl-ag-save` — Lagre-knapp per agent

### cpg-c-set — Innstillinger
- `#c-set-co` — Firmanavn
- `#c-set-em` — E-post (read-only)
- `#c-set-cp` — Kontaktperson
- `#btn-lagre-klient-set` → lagrer til CU

---

## 9. ALLE JAVASCRIPT-FUNKSJONER

### Utility
| Funksjon | Beskrivelse |
|----------|-------------|
| `el(id)` | `document.getElementById(id)` shorthand |
| `toast(msg, type)` | Viser toast. type: `'ok'` (grønn), `'warn'` (gul), `'er'` (rød) |
| `fmtKr(n)` | Formaterer tall til "1 234 kr" |
| `fmtKrK(n)` | Formaterer til "1,2k kr" |
| `openModal(id)` | Viser statisk modal |
| `openDynModal(id, html)` | Setter innerHTML + viser modal |
| `closeModal(id)` | Skjuler modal |
| `tickClock()` | Oppdaterer klokkeelementer |

### Auth
| Funksjon | Beskrivelse |
|----------|-------------|
| `doLogin()` | Validerer, setter CU, populerer CLIENTS hvis DEMO_MODE |
| `logout()` | Resetter CU, DEMO_MODE, CLIENTS |

### Animasjon / Live data
| Funksjon | Beskrivelse |
|----------|-------------|
| `liveV(id, val)` | Oppdaterer DOM-verdi UTEN animasjon (brukes i realtime intervals) |
| `animV(id, val)` | Oppdaterer med count-up animasjon (brukes kun ved boot) |
| `clearAllRT()` | Stopper alle setInterval (rtA, rtC) |
| `buildChart(id, color, vals)` | Bygger sparkline SVG-chart |
| `setConnBadge(live)` | Setter tilkoblings-badge status |

### Admin boot og render
| Funksjon | Beskrivelse |
|----------|-------------|
| `bootAdmin()` | Initialiserer admin-grensesnitt, kaller alle render-funksjoner |
| `renderClientsTable(filt, tier)` | Fyller `#cl-tbody` med klientrader |
| `visKlientDetaljer(cl)` | Åpner klientmodal med pause/arkiver/lagre + agent-editor |
| `renderAgentCards()` | Fyller `#ag-cards` med agentkort |
| `renderAdminFeed()` | Fyller `#a-feed` med aktivitet |
| `pushAdminFeed(flash)` | Legger til ny hendelse i admin-feed |
| `renderApiKostnader()` | Fyller API-kostnads-tabell |
| `renderAvtaleTabell()` | Fyller avtaleoversikt |
| `renderFakturering()` | Fyller faktureringsside |
| `renderLogFeed()` | Fyller systemlogg |
| `renderUsersTable()` | Fyller brukertabell |
| `updateAdminStats()` | Oppdaterer stats-kort |
| `addClient()` | Oppretter ny klient fra m-newcl skjema |

### Klient boot og render
| Funksjon | Beskrivelse |
|----------|-------------|
| `bootClient()` | Initialiserer klient-grensesnitt, setter opp voice provider, kaller render + `setTimeout(renderClientAgentConfig, 100)` |
| `renderClientAgCards()` | Fyller `#c-agcards` |
| `renderClientAgList()` | Fyller `#c-aglist` |
| `renderClientActLog()` | Fyller `#c-actlog` |
| `renderClientAgentConfig()` | Fyller `#c-agent-config-list` — generell kunnskap + per-agent kart |
| `updateClientROI()` | Oppdaterer ROI-display |
| `buildClientCharts()` | Bygger klient-grafer |
| `pushClientFeed()` | Ny hendelse i klient-feed |
| `saveSettings()` | Lagrer Supabase-innstillinger |

### Voice provider
Satt av admin per klient via `voiceProvider` felt på CLIENTS-entry.
`bootClient()` renderer riktige input-felter i `#c-voice-key-fields` basert på `vp`:
- `'VAPI'` → `#c-key-vapi` input + link til vapi.ai
- `'ElevenLabs'` → `#c-key-elevenlabs` input + `#c-key-vapi` hidden
- `'Twilio'` → `#c-key-twilio-sid` + `#c-key-twilio-token` + begge VAPI/EL hidden

---

## 10. REALTIME OPPDATERING

Admin (`rtA`) og klient (`rtC`) har separate `setInterval` som kjøres hvert 8. sekund:
- Øker stats tilfeldig
- Kaller `liveV()` (IKKE animV — ville flashe ved hver oppdatering)
- Pusher tilfeldige feed-hendelser
- Oppdaterer ROI

`clearAllRT()` kalles ved logout og ved ny boot for å hindre overlappende intervals.

---

## 11. KJENTE MØNSTRE OG GOTCHAS

### agentIdx lookup — 3 steg
```javascript
// renderClientAgentConfig bruker dette mønsteret:
const idxList = (u.agentIdx && u.agentIdx.length)
  ? u.agentIdx
  : AGENTS.map((_,i) => i).filter(i => AGENTS[i] && AGENTS[i].klient === u.company);
// Alltid: guard med (u.agentIdx||[])
```

### Dynamisk modal HTML — template literal i JS
```javascript
// Bruk kun backtick-strings for dynamisk HTML
// ALDRI nest template literals med samme type quotes
openDynModal('m-xxx', `<div>...</div>`);
// Etter åpning — wire event listeners umiddelbart:
el('btn-id').addEventListener('click', () => { ... });
```

### Modal save-pattern
```javascript
// Dynamiske modaler settes opp inline etter openDynModal:
el('adm-kl-save').addEventListener('click', () => {
  document.querySelectorAll('.adm-ag-know').forEach(k => {
    if (AGENTS[+k.dataset.idx]) AGENTS[+k.dataset.idx].knowledge = k.value.trim();
  });
  toast('Lagret ✓');
  renderClientsTable();
});
```

### Font-regler
```
Brødtekst, labels, knapper:  font-family:'Instrument Sans',sans-serif; font-weight:400/600/700
Logo/brand:                   font-family:'Syne',sans-serif; font-weight:700/800
ALDRI:                        Syne på sidehoder, statistikk-tall, tabeller
```

### Sidestørrelse og ytelse
- Fil er ~163KB / ~2530 linjer
- Alt er inline — ingen HTTP requests etter innlasting (untatt Google Fonts)
- Cloudflare CDN brukes IKKE — zero `cdn-cgi` referanser

---

## 12. UTVIDELSESGUIDE

### Legge til ny klientsideside
1. Legg til HTML: `<div class="cpg" id="cpg-c-NAVN">...</div>` i `#v-client`
2. Legg til nav-knapp: `<button class="cni" data-cpage="NAVN">Tittel</button>`
3. Hvis siden trenger data ved navigasjon: legg til i nav-handler:
   ```javascript
   if (item.dataset.cpage === 'NAVN') renderMinFunksjon();
   ```

### Legge til ny admin-side
1. HTML: `<div class="pg" id="pg-a-NAVN">...</div>` i `#v-admin`
2. Nav: `<button class="ani" data-page="a-NAVN">Tittel</button>`
3. Render-funksjon kalt fra `bootAdmin()`

### Legge til agent-felt
1. Legg til felt i `AGENTS`-array for alle 10 demo-agenter
2. Legg til i `visKlientDetaljer` admin-editor (`.adm-ag-xxx` klasse + `data-idx`)
3. Legg til i `adm-kl-save` handler: `document.querySelectorAll('.adm-ag-xxx').forEach(...)`
4. Vis i `renderClientAgentConfig` om relevant for klienten

### Toast-meldinger
```javascript
toast('Alt gikk bra ✓')           // Grønn
toast('Noe gikk galt', 'er')      // Rød
toast('Vær oppmerksom', 'warn')   // Gul
```

---

## 13. DEMO-BRUKERE

| E-post (base64-kodet) | Passord | Rolle | Firma |
|----------------------|---------|-------|-------|
| admin@simplycomplex.no | admin123 | admin | — |
| kunde@regnskapclient.no | klient123 | client | Regnskap AS (tier 2) |
| kontakt@eiendombord.no | klient123 | client | Eiendom Nord (tier 1) |
| admin@techsolutions.no | klient123 | client | Tech Solutions (tier 3) |

E-post er kodet med `atob()` i kildekoden for å unngå spam-indeksering.

Demo-hints på innloggingsskjermen fyller inn kredentiale automatisk.
`DEMO_MODE=true` aktiverer CLIENTS_DEMO → CLIENTS populering ved innlogging.

---

## 14. REBUIL-INSTRUKSER FOR AI

Når du bygger ny versjon fra dette dokumentet:

1. **Start med struktur** — `v-login`, `v-admin`, `v-client` som tre topnivå-divs
2. **CSS-variabler** — definer alle `--bg`, `--s2`, `--s3`, `--b1`, `--b2`, `--tx`, `--m2`, `--mu`, `--g`, `--b1c`, `--wa`, `--er` i `:root`
3. **Data først** — legg inn USERS, AGENTS, CLIENTS_DEMO, TIER_CFG nøyaktig som dokumentert
4. **DEMO_MODE** — `let DEMO_MODE = false;` rett etter `let` state-variablene
5. **doLogin** — sett `DEMO_MODE = true` i hint-handler FØR `el('lin-em').value = d[0]`
6. **bootClient** — kall `setTimeout(renderClientAgentConfig, 100)` mot slutten
7. **renderClientAgentConfig** — vis alltid generell kunnskap (uavhengig av agenter) + per-agent kort
8. **visKlientDetaljer** — inkluder `adm-kl-toggle`, `adm-kl-archive`, `adm-kl-save` + per-agent editor
9. **Voice keys** — renderer dynamisk i `#c-voice-key-fields` basert på `voiceProvider`
10. **Font-regel** — Instrument Sans overalt, Syne kun på logo

**JS-syntaksregler:**
- Alle event listeners etter `openDynModal`: wire umiddelbart etter kallet
- Bruk `||[]` guard på alle `agentIdx`-akseser
- Bruk `liveV()` i setInterval, `animV()` kun ved første render
- Template literals: unngå å neste backtick-strings — bruk string concatenation inne i template literals
