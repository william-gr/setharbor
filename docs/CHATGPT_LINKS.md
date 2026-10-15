# ChatGPT workout links — phone prototype

This experiment keeps SetHarbor free, MIT licensed and offline after a workout arrives. No API key, MCP connection, paid backend, copying JSON or document import is required. It tests an Android link handoff, not automatic access to the phone by ChatGPT.

## Try on your phone

1. Open https://william-gr.github.io/setharbor/ and install **SetHarbor Trial**. Its package is `com.william.treino.preview`, with separate data, so the existing personal app remains installed. The trial does **not** contain the E2E fixture CA.
2. Tap **Abrir treino de teste no SetHarbor** on that page. If it opens in the browser, tap **Abrir no SetHarbor**. Review the proposed three-day workout and tap **Aplicar treino**, or cancel to leave the plan unchanged.
3. For direct opening, tap **Abrir links do ChatGPT diretamente** in the trial app. On Android 12+, enable supported links and select `william-gr.github.io` in the system settings. Older Android versions may show an app chooser; select SetHarbor Trial.
4. To try a short prompt with the trial already installed, open **https://william-gr.github.io/setharbor/chatgpt/** in the Android browser, tap **Planejar com ChatGPT**, and select ChatGPT in the native share chooser. This shares only a short request and the public guide URL; it does not require updating/reinstalling the trial. In the updated app, **Planejar com ChatGPT** likewise sends a short request, the current revision and guide URL. **Revisar ficha com ChatGPT** adds the sanitized current plan for edits. No catalog is embedded in either prompt; sessions, loads, drafts and unknown metadata are excluded.
5. Ask for the routine you want. The instructions request a clickable **Abrir no SetHarbor** link. Tap it, review the full plan and apply. If the browser appears, use its open button. No file download/import is involved in applying a workout.

The user reported that the initial phone handoff appeared to work. The new short-prompt trial must establish whether ChatGPT can consult the public guide/catalog and then generate the same working link. Tool availability varies by conversation; if reading fails, ChatGPT must explain the limitation instead of inventing exercise IDs or encoding. No equipment-filtered fallback has been implemented yet. Code execution must be available in the ChatGPT conversation to reliably produce the encoded URL. These behaviors have not been established just by Android emulator tests. If ChatGPT is absent from the share chooser or cannot encode the link, report that result; the prototype must improve rather than asking users to copy/import manually.

## Link contract

```
https://william-gr.github.io/setharbor/open/#v1.BASE64URL
setharbor://workout#v1.BASE64URL
```

`BASE64URL` is unpadded URL-safe Base64 of the complete workout JSON in UTF-8. Maximum complete HTTPS URL length is 64,000 characters. Python encoding:

```python
import base64, json
payload = base64.urlsafe_b64encode(
    json.dumps(plan, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
).decode().rstrip('=')
url = 'https://william-gr.github.io/setharbor/open/#v1.' + payload
```

The app accepts only these exact hosts/paths, no query parameters, credentials or ports, and only link version `v1`. It rejects missing, oversized, malformed Base64/UTF-8/JSON and invalid workout plans before modifying state. The incoming plan is always reviewed; cold starts and `onNewIntent` use the same path. Drafts block replacement, including session exercise overrides. Confirmation preserves saved history and uses the existing plan validation/persistence rules. Links carry data, never arbitrary fetch URLs or executable actions.

Fragments stay out of the HTTP request to GitHub Pages. The fallback page decodes locally, uses `textContent` for its title, and performs no plan upload, remote lookup, storage or analytics. Its button uses a browsable Android intent URI, with a custom-scheme fallback. Links are not confidential once shared in a chat or browser history; the generated workout is sent to ChatGPT by the user's explicit share action.

## Domain association

These are **user-enabled HTTPS links**, not automatically verified Android App Links. GitHub project Pages can serve `/setharbor/`, but cannot publish the required domain-root `/.well-known/assetlinks.json`. Automatically verified links require control of that root and the installed signing certificate fingerprint. This prototype intentionally does not claim verification or make a new signing-key promise. Both trial and regular builds handle the same link contract; if both are installed, Android may ask which app to use.

## Publishing and checks

`workout-links.yml` tests the fallback parser, runs core coverage/lint, builds the separate trial APK and deploys free GitHub Pages. The site includes `SHA256SUMS` and `source-commit.txt` for the downloaded APK. APK signing is the CI debug key, as with the regular build workflow. A later CI build can have a different signature; retain trial backups before replacing a trial installation containing important data.

JVM tests exercise Unicode round trips, the real default plan, strict destinations, malformed content, size bounds and prompt metadata exclusion. E2E scenarios 36–40 exercise real Android intent routing, cold/warm opening, cancel/apply/history, three-day plans, malformed content, draft protection, rotation and replacing a pending link. Scenario 41 checks the real share chooser and link settings. They do not mock Activities or launch the personal package. The browser intent grammar is exercised through Android's intent parser. Scenario 41 now opens both create and revise sharing flows. The short-prompt guide retrieval on a real phone remains the final experiment.

References: [Android deep links](https://developer.android.com/training/app-links/create-deeplinks), [Chrome Android intents](https://developer.chrome.com/docs/android/intents).

The static guide is generated from the canonical catalog and WorkoutLink constants by `scripts/build_chatgpt_guide.py`; `--check` rejects stale HTML in CI. The deploy publishes the complete canonical JSON alongside a readable 90-row table with IDs, bilingual names, group, equipment and primary muscles. The Web Share button invokes native sharing only after an explicit click, with text only; unavailable sharing and cancellation show a message. Tests check these cases and exclude catalog/plan data from the shared web text.


## Flutter / iOS

A implementação compartilhada mantém o contrato do link e o preview com confirmação. iOS registra setharbor://workout; o botão do fallback web usa esse esquema no iPhone, e conserva Android intent no Android. Não há entitlement/associação de Apple universal links configurado para o domínio compartilhado GitHub Pages. Assinatura/distribuição e o fluxo completo no ChatGPT/iPhone real continuam pendentes; testes no simulador não comprovam esse fluxo externo. Veja docs/FLUTTER_MIGRATION.md.
