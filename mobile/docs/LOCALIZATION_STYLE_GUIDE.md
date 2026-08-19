# Localization Style Guide

Status: Current
Validated against: `mobile/lib/l10n/app_*.arb` (21 non-English locales) and the
l10n guards under `mobile/test/l10n/` on 2026-08-19.

This is the source of truth for **what translated copy should sound like**:
how to address the reader in each locale, which variety of a pluricentric
language we ship, which words never get translated, and who signs off.

It does not cover the mechanics of adding a key — `flutter gen-l10n`, ARB
metadata, `context.l10n`, deferring with `_knownUntranslatedDebt`. Those live
in [`.claude/rules/localization.md`](../../.claude/rules/localization.md) and
in `AGENTS.md`. Read this one when you are writing or reviewing the *words*.

The English voice this guide extends is
[`brand-guidelines/TONE_OF_VOICE.md`](../../brand-guidelines/TONE_OF_VOICE.md).

---

## Why this exists

Divine ships 22 locales — English plus 21 translations — from one app. Almost
nobody who reviews a translation PR reads the language it changes, so review
defaults to "the ARB parity guard is green", which proves a key exists, not
that it sounds like Divine.

Individually reasonable choices then accumulate, and they accumulate in a
pattern. **The drift is feature-shaped, not key-shaped**: in five locales the
register that departs from the file's own baseline is concentrated in the same
place, the video editor.

- **Spanish** ships two dialects. Its baseline is Rioplatense *voseo* —
  `Revisá tu Wi-Fi`, `Ingresá tu código`, `No tenés permiso` — present since
  the original l10n commit (#2930). *Tuteo* (`Inténtalo de nuevo`) arrived
  later through feature work and clusters in the video editor. Counting only
  markers that actually discriminate, roughly 230 keys are voseo and 25 are
  unambiguously tuteo.
- **Turkish** answers the same action two ways: `publishErrorServerUnreachable`
  says `Lütfen birazdan tekrar dene` (informal) and `videoEditorSplitFailed`
  says `Lütfen tekrar deneyin` (formal).
- **Romanian** and **Portuguese** drift in the same corner — `ro`'s polite
  2nd-person plural and `pt`'s European forms both cluster in the video editor
  and chroma-key screens.
- **Japanese** uses casual sentence-final よ/ね — `ネットに接続できないよ。` —
  where the surrounding app is です/ます polite.
- **Bulgarian** switches inside a single string:
  `Докосни произволно място, за да започнете да записвате` opens with a
  familiar imperative and closes with a polite one.

None of these is a bad translation. Each is a different app's voice arriving
one PR at a time, and the fact that five unrelated languages drift in the same
feature points at one upstream pipeline rather than five translators. This
guide exists so the next pass has an answer to check itself against, and so a
reviewer who does not speak the language still has something to review.

---

## What we ship

The locale contract, from the code:

- 22 ARB files, all **bare language codes** — `es`, not `es-419` or `es-ES`;
  `pt`, not `pt-BR`; `zh`, not `zh-Hans`
  (`mobile/lib/l10n/`, `mobile/l10n.yaml`).
- Each is advertised to users under **one native name** in the in-app language
  picker: `'es': 'Español'`, `'pt': 'Português'`, `'zh': '简体中文'`
  (`mobile/lib/services/locale_preference_service.dart`).
- Anything unmatched falls back to English
  (`mobile/lib/l10n/resolve_app_ui_locale.dart`).

**The consequence that drives every decision below: there is no second file to
send anyone to.** One `es` serves Madrid, Mexico City and Buenos Aires. One
`pt` serves São Paulo and Lisbon. A regional choice is not a flavour, it is a
decision that the other regions read as foreign. Write for the whole language
community, not for the first native speaker who happened to be available.

Adding a region-qualified locale (`pt-BR` alongside `pt`) is a product
decision, not a translation decision. Raise it as an issue; do not smuggle a
regionalism into the shared file instead.

---

## Register: how to address the reader

**Principle: use the register a popular consumer app in that language uses to
talk to its own users.** Not the most formal option, not the most familiar —
the unmarked one.

"Informal" is not a universal answer. German `du` and Japanese です/ます are
both correct here, and so is Urdu آپ, because each is what an ordinary app in
that language uses. Copying English's T-form instinct into Urdu or Japanese
produces copy that reads as rude, not as friendly.

| Locale | Address the reader as | Current tree | Notes |
|---|---|---|---|
| `am` Amharic | Polite እርስዎ / -ዎ; avoid gendered singular | **split** | Familiar and polite forms both appear, and they flip per verb: `ሰርዝ` 55 / `ይሰርዙ` 4 for delete, but `ተመልከት` 4 / `ይመልከቱ` 40 for watch. Adjacent keys disagree — `authCreateNewAccount` is polite, `authCreateNewAccountShort` familiar. Every familiar form is **masculine**; the feminine is used zero times, so those strings address every reader as male. That is the reason to prefer the polite form or a verbal noun, not tidiness. |
| `ar` Arabic | MSA; impersonal phrasing, masculine-singular imperative where a verb is unavoidable | consistent | No feminine or plural address anywhere in the file today. Prefer the verbal noun (الإرسال) to a command (أرسل) in new copy. No dialect. |
| `bg` Bulgarian | `ти` + familiar imperatives | **split** | The pronoun `Вие` is absent, but courtesy in Bulgarian is the 2nd-person **plural verb**, and it appears — including inside single strings: `Докосни ... за да започнете` and `Докосни за редактиране. Задръжте и плъзнете`. Checking the pronoun alone reports this file as clean. |
| `de` German | `du` | consistent | A handful of `Sie`/`Ihr` hits are pronoun ambiguity, not courtesy address. |
| `es` Spanish | `tú` (tuteo) | **split** | See [Variety and dialect](#variety-and-dialect). No *voseo*, no *vosotros*. |
| `fil` Filipino | Informal — no `po`/`kayo` | consistent | Taglish is the register: ~750 keys carry an English tech noun. Do not "purify" those into coined Filipino. |
| `fr` French | `tu` | **36 keys use `vous`** | Almost all are genuine vouvoiement drift, not plural. Only `userPickerEmptyFollowListBody` ("vous pouvez collaborer" = you-and-them) is a true plural; the two `minorAccountReview*EmailBody` keys are email templates the user sends to support, where formal is correct. The rest cluster in the video editor, recorder and database-failure copy. |
| `id` Indonesian | `kamu` | mostly consistent | ~13 keys use formal `Anda`, and `feedForYouEmpty` manages both in one sentence: `Feed Untuk Anda kamu kosong.` |
| `it` Italian | `tu` | consistent | Zero courtesy forms — a case-sensitive sweep for `Lei`/`Suo`/`Sua`/`Voi` returns nothing. Lowercase `suo`/`sua` appears but is third-person ("il **suo** profilo" = *their* profile), so do not grep case-insensitively here. |
| `ja` Japanese | です/ます polite; noun form for labels | **split** | No だ / よ / ね sentence endings. Politeness is the neutral register, not stiffness. |
| `ko` Korean | 해요체 | **split** | ~117 keys use 합니다체 across product surfaces, not just developer screens (`videoEngagementLikersEmpty`, `videoErrorVerifyAgeFailed`); ~17 use 반말 (`네 크루는 밖에 있어`), which is never correct in product copy. |
| `ms` Malay | `anda` | consistent | Deliberately different from Indonesian: `anda` is Malay's unmarked form. |
| `nl` Dutch | `je` | consistent | Never `u`. |
| `pl` Polish | `ty` + 2nd-person singular imperatives | consistent | Never `Pan`/`Pani`. |
| `pt` Portuguese | `você` | **split** | At least 16 keys carry European forms — `tu`-imperatives (`Verifica a tua ligação`), `utilizador`, and the chroma-key and people-lists screens. `userPickerConfirmSemanticLabel` says `utilizadores` beside `userPickerUnavailable`'s `usuários`, on one screen. See [Variety and dialect](#variety-and-dialect). |
| `ro` Romanian | `tu` | mostly consistent | `dumneavoastră` is absent, but Romanian politeness also lives in the verb: at least 7 keys use polite 2nd-person plural (`încercați`, `vă rugăm`), again clustered in the video editor. |
| `sv` Swedish | `du` | consistent | Sweden is du-reformed; `ni` reads as archaic. |
| `tr` Turkish | `sen` | **split** | Register lives in the suffix, not the pronoun. At least 26 keys use formal 2nd-person plural forms, clustered in the video editor, sound-sync, database-failure and auth copy. Direct collision for the same action: `publishErrorServerUnreachable` = `...tekrar dene`, `videoEditorSplitFailed` = `...tekrar deneyin`. |
| `ur` Urdu | `آپ` | consistent | `آپ` is the neutral form. `تم` reads as brusque, not friendly. |
| `vi` Vietnamese | `bạn` | consistent | |
| `zh` Chinese | `你` | consistent | Never `您`. Simplified script, mainland vocabulary — see below. |

"Current tree" is the shape of today's corpus, measured with the checks in
[Checks you can run](#checks-you-can-run-without-speaking-the-language) —
counts are floors, since a wider marker list finds more. Where it says
**split**, the decision in this table is the target and the file has not been
reconciled yet. Several rows read "consistent" only until someone greps the
verb instead of the pronoun; see
[Where a pronoun grep lies](#where-a-pronoun-grep-lies) before trusting a
clean result.

**When the table and the file disagree, follow the table for the keys you are
touching.** Do not reconcile the rest of the file in the same PR — a 400-key
register sweep buried in a feature PR is not reviewable. Reconciling a locale
is its own change, with its own issue and its own native-speaker review.

---

## Variety and dialect

### Spanish — neutral, pan-regional, tuteo

One `es` file serves every Spanish-speaking market we ship to.

**Read this before "fixing" the register.** The file's baseline is *voseo*, not
*tuteo*. `git log -S'Probá' -- mobile/lib/l10n/app_es.arb` traces it to #2930,
the original l10n commit; tuteo (`Inténtalo`) enters later, at #3142 and other
video-editor work. So the majority register is the Rioplatense one, and the
minority is standard tuteo — the opposite of what a quick read suggests.

- **Address: `tú` (tuteo).** This is a product decision, not a drift cleanup,
  and it is worth stating plainly: *voseo* is Rioplatense, so it reads as
  regional to the large majority of Spanish speakers, while `tú` is understood
  everywhere. Choosing it means rewriting the file's baseline (~230 keys), not
  patching an outlier — schedule it as its own change with native review, and
  do not half-apply it. If a maintainer prefers to keep voseo, change this row
  instead; what is not defensible is shipping both.
- **No *vosotros*** — it is Spain-only, and the corpus already contains none.
- **Vocabulary: whichever word is understood everywhere.** Prefer the
  pan-regional term over a marked one in either direction: not `ordenador`
  (Spain) and not `computadora` where `dispositivo` works.
- **Spelling: `video`, not `vídeo`.** Both are correct Spanish; `video` is the
  Latin-American form and the majority in the current file. This is the single
  most repeated noun in the app, so it is worth pinning.
- Keep `enlace`/`link`, `correo`/`email` consistent *within the file* — see
  [Terminology](#terminology).

### Portuguese — `você`, Brazilian base

One `pt` file serves Brazil and Portugal, and today it is Brazilian:
`usuário`, `arquivo`, `tela`, `celular`, with no European counterpart
(`utilizador`, `ficheiro`, `ecrã`, `telemóvel`) anywhere in the file. Keep
that base rather than mixing a second variety into it.

- **Address: `você`.** Eight keys currently use European `tu` forms —
  `Verifica a tua ligação`, `o teu comentário`, `Adiciona tags` — and are the
  exception, not a precedent.
- Where a word splits hardest between the two varieties, prefer a phrasing
  that avoids the split before defaulting to the Brazilian form.
- No slang either way. The colloquial contractions already in the invite copy
  (`pro`, `pra`) mark the ceiling.

### Chinese — Simplified, mainland vocabulary

The picker advertises **简体中文**. Ship Simplified characters only, with
mainland vocabulary (`视频`, `账号`, `设置`, `上传`), not Taiwan/HK forms
(`影片`, `帳號`, `設定`). Mixed script inside one file is a bug, and
`arb_script_integrity_test.dart` will not catch it — both scripts are `CJK`.

### Malay and Indonesian are not the same locale

`ms` and `id` are separate files on purpose. Do not translate one by copying
the other: `unggah`/`unduh`/`akun`/`pengaturan` are Indonesian;
`muat naik`/`muat turun`/`akaun`/`tetapan` are Malay.

### No regional slang, anywhere

Slang dates fast and localizes worse than plain language. The English source
gets to be playful because we can review it; a regional idiom in a language
nobody on the team reads is a liability with no upside.

---

## Voice: making the English tone survive

[`brand-guidelines/TONE_OF_VOICE.md`](../../brand-guidelines/TONE_OF_VOICE.md)
sets the dial — in-app UI is low-rebel, high-playful; error
messages are low-rebel, medium-playful; legal is neither. That dial applies to
translations too, with three additions.

**Translate the intent, not the words.** The brand guide's own no-results
example — "Nada. Try something different?" — is an instruction about register,
not a lexical puzzle. The target should be as light in its own language as the
English is in ours.

**When the joke does not travel, drop the joke and keep the meaning.** Do not
substitute a *different* joke — you are inventing untested brand voice in a
language nobody on the review path can check. Plain and correct beats clever
and unverifiable. `authWelcomeToDivine` is the counter-example: English
"Welcome to Divine!" became Japanese `やった！入れたよ！` ("Yes! I'm in!"),
which is charming, casual in a file that is otherwise polite, and no longer
contains the product name or the "Welcome Home" arrival language the brand
guide asks for.

**Never soften a load-bearing word.** Safety, consent, money, deletion and age
copy carry meaning that a friendlier synonym destroys. The repo already treats
this as a first-class reason to *defer* rather than approximate — see the
comment on `exploreFeaturedPaidPartnership` in
`mobile/test/l10n/arb_consistency_test.dart`, held out of machine translation
because "paid" is load-bearing and a softened rendering discloses nothing.

**Do not add emphasis the source did not have.** Exclamation marks, ALL CAPS
and emoji are decisions made in `app_en.arb`. Match them; do not introduce
them. The English source currently uses exactly one emoji, in
`videoFeedLoopCountLabel`.

---

## Terminology

### Locked terms — never translated, never transliterated

These are names and protocol tokens. Translating them breaks recognition; a
transliteration breaks it and cannot be typed back.

| Term | Why |
|---|---|
| `Divine` | Product name. Always this casing — never `DiVine` or `diVine` in copy. |
| `Nostr`, `NIP-XX` | Protocol names. |
| `npub`, `nsec`, `nevent`, `nprofile` | Bech32 prefixes users copy and paste. |
| `nostr:`, `bunker://`, `wss://`, `https://` | URI schemes. A translated or capitalized scheme is not typeable. |
| `Blossom`, `Keycast` | Service names. |

Bare Latin script is allowed in every locale precisely so these survive —
that is what `_allowedScripts` in `arb_script_integrity_test.dart` encodes.

The casing rule is currently broken at the source: seven keys in `app_en.arb`
(`nostrInfoIntroBuiltOn`, `listCollaboratorSearchHint`,
`collaboratorInviteDmBody`, `collaboratorInviteDmBodyUntitled`,
`invitesShareWithPeople`, `invitesShareMessage`, `invitesShareSubject`) write
`DiVine` or `diVine`, and every locale faithfully mirrored it. Fix that in
English first — a translator copying the source is doing the right thing.

### Everything else: consistent within a locale

Words like *loop*, *relay*, *repost*, *feed* are common nouns describing what
the product does. Whether a locale keeps the English word, adapts it, or
translates it is the translator's call — but **one rendering per term per
locale, used in every key.**

The current tree shows what the absence of that rule costs. `Loops` is the
label on a profile stat and the unit in a count, and today:

- Italian says `Loops` on the label and `{count} loop` in the count.
- Bulgarian says `Лупове` on the label and `{count} лупа` in the count.
- French translates *relay* in 18 of the 72 keys that use it and keeps the
  English word in the other 54.

Nobody chose that. Each key was individually fine.

When you introduce a term into a locale for the first time, grep the file for
how the same English word was rendered before, and match it.

---

## Reviewing a translation you cannot read

Most translation PRs here will be reviewed by someone who does not speak the
target language. That is the normal case, not a failure, and the review model
is built around it. Sort every finding into one of three tiers.

**Tier 1 — mechanical. Machine-checked; no language knowledge needed.**
Key parity, placeholder integrity, ICU plural arms, script contamination,
values shared across unrelated scripts. Already guarded — see
[What is enforced](#what-is-enforced-and-what-is-not). If CI is green, Tier 1
is done; do not re-check it by eye.

**Tier 2 — style-guide conformance. Any reviewer can check this.**
Register matches the table above. No locked term was translated. A term
introduced into a locale matches how that locale already renders it. No emoji
or exclamation marks the source did not have. Every check in this tier has a
command in the next section, and **none of them require reading the language.**
This tier is where a non-speaking reviewer adds real value, and it is exactly
where the drift in this repo has come from.

**Tier 3 — naturalness. Native speaker required.**
Idiom, humor, whether the copy sounds like a person. No command finds this.

### When a native speaker is required

Not for every ARB change — that rule would be unfollowable at 21 locales and
would simply be ignored. Require it for:

- a **new locale**,
- **onboarding and first-run** copy, which sets the voice for everything after,
- **safety, consent, deletion, age-gate, and money** copy, where a soft
  rendering changes what was disclosed,
- any string carrying **humor or wordplay**,
- a **register change** to this guide's table.

Everything else — a fixed typo, a new setting label, a restored missing key —
ships on Tier 1 + Tier 2.

### When no native speaker is available

This is the common case, and it has an answer.

1. Ship the **plain** variant, not the clever one. Drop the joke, keep the
   meaning (see [Voice](#voice-making-the-english-tone-survive)).
2. If the string is on the required-review list above and no reviewer exists,
   **defer instead of guessing**: leave the key out of that locale, add it to
   `_knownUntranslatedDebt` in `mobile/test/l10n/arb_consistency_test.dart`
   with a comment naming the reason and a tracking issue, and let it fall back
   to English. English is a worse experience; a confidently wrong safety
   string is a worse outcome.
3. Do **not** block a bug fix on Tier 3 review. Approve on Tier 1 + Tier 2 and
   say in the review that naturalness was not assessed.

### Who signs off

`.github/CODEOWNERS` routes every ARB change to `@divinevideo/reviewers`;
there is no per-locale owner today. So:

- **The reviewer of record** is whoever the team assignment picks. Their job is
  Tier 1 (read CI) and Tier 2 (run the checks). Approving with "looks fine" on
  a language you do not read is not a review — the parity guard already told
  you that much.
- **Tier 3 sign-off** is a named native speaker, in a review comment, on the
  triggers listed above. If that person is not a repo reviewer, quote their
  verdict in the PR and link the source.
- **This guide's decisions** are changed by a PR to this file, not by a
  translation PR that quietly disagrees with it.

---

## Checks you can run without speaking the language

Run from `mobile/`. Each maps to a Tier 2 rule.

```bash
# Tier 1 — the guards. Everything they cover is off your plate.
flutter test test/l10n/
```

```bash
# Register: does this locale mix address forms?  (example: fr)
python3 - <<'PY'
import json, re
d = json.load(open('lib/l10n/app_fr.arb'))
vals = {k: v for k, v in d.items() if not k.startswith('@') and isinstance(v, str)}
formal = [k for k, v in vals.items() if re.search(r'\b(vous|votre|vos)\b', v)]
print(len(formal), 'keys use vous/votre/vos'); print(formal[:20])
PY
```

Swap the pattern for the locale you are reviewing: `de` `\b(Sie|Ihnen|Ihre?)\b`,
`nl` `\b(u|uw)\b`, `it` `\b(Lei|Suo|Sua)\b` **case-sensitively**, `es` voseo
`\b(vos|sos|tenés|podés|Revisá|Probá|Elegí|Usá|Compartí)\b`, `ja`
`(だよ|してね|するよ|ないよ)`, `ko` `(습니다|ㅂ니다)` and `(있어$|없어$|이야$)`,
`zh` `您`, `id` `\bAnda\b`.

### Where a pronoun grep lies

The snippet above is a starting point, and in five of our locales it is not
enough. Every one of these produced a wrong answer during the audit that wrote
this guide, so treat a clean pronoun grep as *no information*, not as a pass:

- **Register can live in the verb, not the pronoun.** Turkish, Bulgarian,
  Romanian and Amharic all carry politeness in the verb ending. Bulgarian's
  courtesy pronoun `Вие` appears **zero** times in a file that nonetheless
  switches register mid-sentence. Grep the imperative — `dene` vs `deneyin`,
  `Докосни` vs `Докоснете`, `încearcă` vs `încercați`.
- **A possessive can belong to both registers.** Spanish `tu`/`tus` is shared
  by tuteo *and* voseo — there is no `vuestro` in voseo — so counting `tu` as a
  tuteo marker scores voseo strings as tuteo. 72 keys carry both. Use only
  markers the other register cannot produce: accented `tú`, `tienes`/`puedes`,
  or the accent-final imperatives `Revisá`/`Probá`.
- **Case-insensitive matching invents findings.** Italian `Suo`/`Sua` is
  courtesy; lowercase `suo`/`sua` is ordinary third person. Matching without
  case reports 15 offenders in a file that has none.
- **Short words match inside longer ones in unspaced scripts.** Urdu `تم`
  looks like the informal pronoun and appears in 51 keys — every one of them
  inside `ختم`, `تمام`, `مشتمل` or `تمباکو`. Word-boundary matching finds
  zero. Amharic `ህ` behaves the same way. Anchor on whole words or whole
  imperative forms.
- **`str.lower()` is not safe in Turkish.** Python lowercases `İ` to `i` plus
  a combining dot, so `'İptal Et'.lower()` does not contain `iptal et`. Use
  `re.IGNORECASE` rather than pre-lowering.

If the locale you are reviewing is in that list and you only ran the pronoun
grep, say so in the review rather than reporting the file as clean.

```bash
# Locked terms: did a translation drop a name or a protocol token?
python3 - <<'PY'
import json, glob, os
base = 'lib/l10n'
en = {k: v for k, v in json.load(open(f'{base}/app_en.arb')).items()
      if not k.startswith('@') and isinstance(v, str)}
for term in ['Divine', 'Nostr', 'npub', 'nsec', 'bunker://', 'wss://', 'Blossom']:
    keys = [k for k, v in en.items() if term.lower() in v.lower()]
    for f in sorted(glob.glob(f'{base}/app_*.arb')):
        loc = os.path.basename(f)[4:-4]
        if loc == 'en':
            continue
        d = json.load(open(f))
        missing = [k for k in keys
                   if isinstance(d.get(k), str) and term.lower() not in d[k].lower()]
        if missing:
            print(f'{loc}: {term!r} absent in {len(missing)} key(s): {missing[:4]}')
PY
```

```bash
# Term consistency: how does this locale render one English word? (example: relay in fr)
python3 - <<'PY'
import json
base = 'lib/l10n'
en = json.load(open(f'{base}/app_en.arb'))
fr = json.load(open(f'{base}/app_fr.arb'))
keys = [k for k, v in en.items()
        if not k.startswith('@') and isinstance(v, str) and 'relay' in v.lower()]
kept = [k for k in keys if isinstance(fr.get(k), str) and 'relay' in fr[k].lower()]
print(f'{len(kept)}/{len(keys)} keys keep the English word — the rest translate it')
PY
```

A non-zero result is not automatically a bug: French `vous` is correct as a
real plural, and a locale may legitimately keep an English word in some
grammatical positions. It is a **list of things to look at**, which is
precisely what a reviewer who does not read the language otherwise lacks.

---

## What is enforced and what is not

| Rule | Enforced by |
|---|---|
| Every locale defines every English key | `arb_consistency_test.dart` (+ `_knownUntranslatedDebt`) |
| Every placeholder the English value actually substitutes survives translation | `arb_consistency_test.dart` (selector-only arguments are deliberately exempt — see below) |
| No plural arm hardcodes a literal number, in any locale | `plural_arm_number_test.dart` |
| A named list of countable keys inflects **in English** | `countable_plural_test.dart` |
| `listVideoCount` / `profileFollowerCountUsers` keep their arms in `pl` and `ro` | `countable_plural_test.dart` (those two locales, those keys) |
| **A non-English value has a plural block at all** | **nothing — see below** |
| No wrong-script characters in a locale | `arb_script_integrity_test.dart` |
| No value shared across unrelated scripts (stale/wrong-language paste) | `arb_script_integrity_test.dart` |
| Named disclosures survive translation (`Divine`, `Nostr`, CSAM, Bluesky, Keycast) | `arb_consistency_test.dart`, per-key |
| Copy never reveals a block/mute relationship | `disclosure_invariant_test.dart` |
| Shipped locales match the Android/iOS declarations | `platform_locale_declarations_test.dart` |
| **Register matches this guide's table** | **review only** |
| **Locked terms survive in every key** | **review only** — a general guard is proposed in #7248 |
| **One rendering per term per locale** | **review only** |
| **Naturalness** | **native-speaker review only** |

A green CI proves the top half. It says nothing about the bottom half, which
is the half this guide is about.

Two gaps are worth knowing about, because both look like Tier 1 problems and
neither is.

**A partly-translated value passes every guard.** It has the key, the
placeholders and the right script, so nothing fires.
`collaboratorInviteDmBody` still ends in the English sentence
`Open diVine to review and accept.` in 19 of the 21 non-English locales.

**A flattened plural passes every guard outside English.** `countable_plural_test.dart`
proves the *English* value inflects, and spot-checks two keys in `pl` and one
in `ro`; nothing asserts that the other locales kept a plural block. Seven keys
that pair an int selector with a display string — `analyticsViewsCount`,
`analyticsCommentsCount`, `analyticsRepostsCount`, `analyticsInteractionsCount`,
`categoryVideoCount`, `messageRequestVideosCount`, `relaySettingsEventsSummary` —
are flat in **all 21** non-English locales, so they render the plural noun at
`n = 1`:

```
en  1 view          es  1 visualizaciones   de  1 Aufrufe
fr  1 vues          pl  1 wyświetleń        pt  1 visualizações
```

`listVideoCount` is the control: it is one of the keys the `pl`/`ro`
assertions cover, and it correctly renders `1 film` / `1 videoclip`. The bug
sits exactly where the guard does not reach.

The placeholder guard does not catch it either, and for a defensible reason.
It exempts selector-only arguments — the `count` in `{count, plural, …}`
substitutes no text of its own — because "a language without that distinction
may legitimately render a bare noun instead". That is right for Japanese,
Korean, Chinese and Vietnamese. It is not right for Polish, Spanish, German,
French or Portuguese, which all have the distinction and lost it anyway. The
exemption is sound; its blast radius is wider than its reason.

Fixing the copy needs per-language plural categories (Polish one/few/many,
Romanian one/few/other, Arabic six), so it is a translation change per the
rules above, not a mechanical sweep.

Related open work, so this guide does not duplicate it: #7248 (stale English
revisions and wrong-language values that survive the parity guard), #7755 (ICU
plural categories missing per CLDR), #6913 (orphaned ARB keys), #7632
(remaining deferred translation debt).

---

## Changing a decision here

Every row in the register table and every entry in the locked-term list is a
default, not a verdict. If a native speaker says a locale's row is wrong, they
are almost certainly right — open a PR against this file that changes the row
and says who assessed it. Reconciling the existing copy to the new row is a
separate PR with its own issue.
