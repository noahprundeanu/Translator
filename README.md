# Noah's Translator

A real-time, live speech translation tool that runs entirely from a single shell script. Speak into your microphone in any language, and see the translation appear instantly on screen — no installation required beyond Python 3.

---

## How It Works

The script:
1. Launches a tiny local web server (Python's built-in `http.server`) on port 5050
2. Opens your browser automatically to `http://localhost:5050`
3. Uses your **browser's built-in Speech Recognition** to capture speech
4. Sends recognized text to **Google Cloud Translation API** for translation
5. Displays both the original and translated text side-by-side in real time

No files are written to your disk. No data is stored. The Python script runs entirely in a temp file that is deleted on exit.

---

## Requirements

- **macOS or Linux** (Windows users can run this via WSL)
- **Python 3** — the script will attempt to install it automatically if missing
- **Google Chrome** — strongly recommended; the Web Speech API works best in Chrome
- **A Google Cloud Translation API key** — see setup below
- An active internet connection (for the API and Google Fonts)

---

## Setup

### 1. Get a Google Cloud Translation API Key

1. Go to [https://console.cloud.google.com/](https://console.cloud.google.com/)
2. Create a project (or select an existing one)
3. Navigate to **APIs & Services → Library** and enable **Cloud Translation API**
4. Go to **APIs & Services → Credentials → Create Credentials → API Key**
5. Copy the key

> **Tip:** It is recommended to restrict your API key to the Cloud Translation API only, and optionally to your IP address, to prevent unauthorized use.

### 2. Add Your API Key to the Script

Open `noahs_translator.sh` in any text editor and find this line near the top:

```bash
GOOGLE_API_KEY=""
```

Paste your key between the quotes:

```bash
GOOGLE_API_KEY="AIzaSyYourKeyHere"
```

Save the file.

---

## Running the Translator

```bash
bash noahs_translator.sh
```

Your browser will open automatically. If it doesn't, navigate to `http://localhost:5050` manually.

To stop the server, press **Ctrl+C** in the terminal.

---

## Using the Interface

| Control | Description |
|---|---|
| **From** dropdown | The language you will be speaking |
| **To** dropdown | The language to translate into |
| **⇄ Swap button** | Instantly swap source and target languages (also clears the transcript) |
| **Start Listening** | Begins capturing microphone audio |
| **Stop** | Stops listening (click the same button again) |
| **Clear transcript** | Clears both the original and translated text panes |

Both dropdowns contain every language supported by Google Translate — over 130 languages total.

---

## Language Support Notes

**Translation:** All 130+ languages supported by Google Cloud Translation API are available in both dropdowns.

**Speech Recognition:** The source language dropdown also sets the speech recognition locale used by your browser. Most major languages are supported, but some less common languages may fall back to a generic locale or show a `language-not-supported` error in Chrome. If this happens, try switching to a closely related language for recognition while keeping your intended target language for translation.

**Best supported source languages for speech recognition include:** English, Spanish, French, German, Portuguese, Italian, Japanese, Korean, Chinese (Simplified/Traditional), Arabic, Hindi, Russian, Dutch, Polish, Swedish, and many others.

---

## Troubleshooting

**"Microphone access denied"**
Your browser blocked mic access. Click the lock icon in the address bar, allow microphone access, and reload the page.

**"Speech recognition not supported"**
Switch to Google Chrome. Firefox and Safari do not fully support the Web Speech API.

**"API error 400" or "API error 403"**
Your API key is invalid, restricted, or the Cloud Translation API is not enabled on your Google Cloud project. Double-check both the key and that the API is enabled.

**"language-not-supported" error**
Your selected source language is not supported for speech recognition by your browser. Select a different source language, or use English as the source and a different target language.

**Port 5050 already in use**
Another process is using port 5050. You can change the `PORT = 5050` line inside the embedded Python section of the script to any available port (e.g., `5051`).

**Browser doesn't open automatically**
Navigate to `http://localhost:5050` manually in Chrome.

---

## Privacy

- Speech audio is processed **locally in your browser** by the Web Speech API (Chrome sends audio to Google's speech servers for recognition).
- Recognized text is sent to the **Google Cloud Translation API** via your local Python server using your own API key.
- No data is logged or stored by the script itself.
- All traffic goes directly from your machine to Google's APIs.

---

## Cost

Google Cloud Translation API pricing is usage-based. As of 2024, the first **500,000 characters per month** are free. Beyond that, charges apply per character. For typical use in meetings or sermons, usage generally stays within the free tier.

Check current pricing at: [https://cloud.google.com/translate/pricing](https://cloud.google.com/translate/pricing)
