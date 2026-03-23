#!/bin/bash
# =============================================================================
#  Noah's Translator
#  Single-file launcher — works on Mac and Linux
#  Just run:  bash noahs_translator.sh
# =============================================================================

set -e

# =============================================================================
#  PASTE YOUR GOOGLE CLOUD TRANSLATION API KEY BELOW
# =============================================================================
GOOGLE_API_KEY=""
# =============================================================================

# ── 1. Locate or install Python 3 ─────────────────────────────────────────────

PYTHON=""

# Try common names
for cmd in python3 python; do
  if command -v "$cmd" &>/dev/null; then
    VER=$("$cmd" -c 'import sys; print(sys.version_info.major)')
    if [ "$VER" = "3" ]; then
      PYTHON="$cmd"
      break
    fi
  fi
done

if [ -z "$PYTHON" ]; then
  echo ""
  echo "  Python 3 not found. Attempting to install..."
  echo ""

  OS="$(uname -s)"

  if [ "$OS" = "Darwin" ]; then
    # macOS — use Homebrew, install brew first if needed
    if ! command -v brew &>/dev/null; then
      echo "  Installing Homebrew (this may take a few minutes)..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      # Add brew to PATH for Apple Silicon
      if [ -f "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      fi
    fi
    echo "  Installing Python 3 via Homebrew..."
    brew install python3
    PYTHON="python3"

  elif [ "$OS" = "Linux" ]; then
    if command -v apt-get &>/dev/null; then
      echo "  Installing Python 3 via apt..."
      sudo apt-get update -qq && sudo apt-get install -y python3
      PYTHON="python3"
    elif command -v dnf &>/dev/null; then
      echo "  Installing Python 3 via dnf..."
      sudo dnf install -y python3
      PYTHON="python3"
    elif command -v pacman &>/dev/null; then
      echo "  Installing Python 3 via pacman..."
      sudo pacman -Sy --noconfirm python
      PYTHON="python3"
    else
      echo ""
      echo "  ERROR: Could not detect a package manager to install Python 3."
      echo "  Please install Python 3 manually from https://www.python.org/downloads/"
      echo "  then re-run this script."
      exit 1
    fi
  else
    echo "  ERROR: Unsupported OS: $OS"
    exit 1
  fi

  echo ""
  echo "  Python 3 installed successfully."
  echo ""
fi

echo "  Using Python: $($PYTHON --version)"

# ── 2. Check API key ──────────────────────────────────────────────────────────

if [ -z "$GOOGLE_API_KEY" ]; then
  echo ""
  echo "  ============================================================"
  echo "   ERROR: No API key set!"
  echo ""
  echo "   Open this script in a text editor and paste your Google"
  echo "   Cloud Translation API key into the GOOGLE_API_KEY line"
  echo "   near the top of the file."
  echo ""
  echo "   How to get a key:"
  echo "   1. Go to https://console.cloud.google.com/"
  echo "   2. Enable the Cloud Translation API"
  echo "   3. Go to APIs & Services → Credentials → Create API Key"
  echo "   4. Paste it between the quotes: GOOGLE_API_KEY=\"your-key-here\""
  echo "  ============================================================"
  echo ""
  read -rp "  Press Enter to exit..."
  exit 1
fi

# ── 3. Write the Python app to a temp file and run it ─────────────────────────

TMPFILE="$(mktemp /tmp/noahs_translator_XXXXXX.py)"
trap 'rm -f "$TMPFILE"' EXIT

cat > "$TMPFILE" << 'PYEOF'
import http.server, json, os, sys, threading, urllib.request, webbrowser

PORT = 5050

# ── Load API key ──────────────────────────────────────────────────────────────
def load_api_key():
    key = os.environ.get('SERMON_API_KEY', '').strip()
    if not key:
        print("ERROR: API key not set. Open the .sh file and fill in GOOGLE_API_KEY.")
        sys.exit(1)
    return key

API_KEY = load_api_key()

# ── Embedded HTML ─────────────────────────────────────────────────────────────
HTML = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1.0"/>
<title>Noah's Translator</title>
<link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;700&family=Source+Sans+3:wght@300;400;600&display=swap" rel="stylesheet"/>
<style>
:root{--bg:#0f0e0c;--surface:#1a1814;--border:#2e2b25;--gold:#c9a84c;--gold-dim:#8a6e2f;--text:#e8e0d0;--text-dim:#7a7060;--red:#c0392b;--green:#27ae60;--radius:10px}
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
body{background:var(--bg);color:var(--text);font-family:'Source Sans 3',sans-serif;font-weight:300;min-height:100vh;display:flex;flex-direction:column;align-items:center}
header{width:100%;padding:28px 40px 20px;border-bottom:1px solid var(--border);display:flex;align-items:center;justify-content:space-between;gap:20px;flex-wrap:wrap}
.brand{display:flex;align-items:baseline;gap:12px}
.brand h1{font-family:'Playfair Display',serif;font-size:1.55rem;font-weight:700;letter-spacing:.02em;color:var(--gold)}
.brand span{font-size:.78rem;color:var(--text-dim);letter-spacing:.12em;text-transform:uppercase}
.controls{display:flex;align-items:center;gap:14px;flex-wrap:wrap}
label.select-label{font-size:.78rem;color:var(--text-dim);letter-spacing:.1em;text-transform:uppercase}
select.lang-select{background:var(--surface);color:var(--text);border:1px solid var(--border);border-radius:var(--radius);padding:8px 34px 8px 14px;font-family:'Source Sans 3',sans-serif;font-size:.9rem;cursor:pointer;outline:none;appearance:none;background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='8' viewBox='0 0 12 8'%3E%3Cpath d='M1 1l5 5 5-5' stroke='%23c9a84c' stroke-width='1.5' fill='none' stroke-linecap='round'/%3E%3C/svg%3E");background-repeat:no-repeat;background-position:right 12px center;transition:border-color .2s;max-width:240px}
select.lang-select:hover{border-color:var(--gold-dim)}
select.lang-select:focus{border-color:var(--gold)}
.swap-btn{background:none;border:1px solid var(--border);color:var(--text-dim);border-radius:50%;width:34px;height:34px;display:flex;align-items:center;justify-content:center;cursor:pointer;font-size:1rem;transition:border-color .2s,color .2s,transform .3s;flex-shrink:0}
.swap-btn:hover{border-color:var(--gold-dim);color:var(--gold);transform:rotate(180deg)}
#toggleBtn{display:flex;align-items:center;gap:9px;padding:9px 22px;border-radius:999px;border:1.5px solid var(--gold);background:transparent;color:var(--gold);font-family:'Source Sans 3',sans-serif;font-size:.88rem;font-weight:600;letter-spacing:.08em;text-transform:uppercase;cursor:pointer;transition:background .2s,color .2s,border-color .2s,box-shadow .2s}
#toggleBtn:hover{background:var(--gold);color:var(--bg);box-shadow:0 0 18px rgba(201,168,76,.35)}
#toggleBtn.listening{background:var(--red);border-color:var(--red);color:#fff;animation:pulse-ring 1.8s ease-in-out infinite}
#toggleBtn.listening:hover{background:#a93226;border-color:#a93226;box-shadow:0 0 18px rgba(192,57,43,.4)}
.dot{width:8px;height:8px;border-radius:50%;background:currentColor;flex-shrink:0}
.listening .dot{animation:blink 1s step-start infinite}
@keyframes blink{50%{opacity:0}}
@keyframes pulse-ring{0%{box-shadow:0 0 0 0 rgba(192,57,43,.5)}70%{box-shadow:0 0 0 10px rgba(192,57,43,0)}100%{box-shadow:0 0 0 0 rgba(192,57,43,0)}}
#statusBar{width:100%;padding:7px 40px;font-size:.75rem;letter-spacing:.08em;color:var(--text-dim);border-bottom:1px solid var(--border);min-height:32px;display:flex;align-items:center;gap:8px;transition:color .3s}
#statusBar.error{color:#e74c3c}
#statusBar.ok{color:var(--green)}
main{width:100%;max-width:1400px;flex:1;display:grid;grid-template-columns:1fr 1fr;gap:0;padding:32px 40px}
@media(max-width:700px){main{grid-template-columns:1fr;padding:20px 18px}header{padding:20px 18px 16px}#statusBar{padding:7px 18px}.controls{gap:10px}}
.pane{padding:0 24px}
.pane:first-child{padding-left:0;border-right:1px solid var(--border);padding-right:32px}
.pane:last-child{padding-left:32px;padding-right:0}
.pane-label{font-size:.7rem;letter-spacing:.18em;text-transform:uppercase;color:var(--text-dim);margin-bottom:16px;display:flex;align-items:center;gap:8px}
.pane-label::after{content:'';flex:1;height:1px;background:var(--border)}
.transcript-box{min-height:300px;max-height:calc(100vh - 260px);overflow-y:auto;padding:4px 2px;display:flex;flex-direction:column;gap:10px}
.transcript-box::-webkit-scrollbar{width:4px}
.transcript-box::-webkit-scrollbar-track{background:transparent}
.transcript-box::-webkit-scrollbar-thumb{background:var(--border);border-radius:2px}
.sentence-text{font-size:1.12rem;line-height:1.65;color:var(--text)}
.sentence-text.interim{color:var(--text-dim);font-style:italic}
.shimmer{height:1.1em;width:60%;border-radius:4px;background:linear-gradient(90deg,var(--border) 25%,#2e2b25cc 50%,var(--border) 75%);background-size:200% 100%;animation:shimmer 1.2s infinite}
@keyframes shimmer{0%{background-position:200% 0}100%{background-position:-200% 0}}
@keyframes fadeUp{from{opacity:0;transform:translateY(6px)}to{opacity:1;transform:translateY(0)}}
.placeholder{color:var(--text-dim);font-style:italic;font-size:.95rem;margin-top:8px}
footer{width:100%;padding:14px 40px;border-top:1px solid var(--border);font-size:.72rem;color:var(--text-dim);display:flex;justify-content:space-between;flex-wrap:wrap;gap:6px}
#clearBtn{background:none;border:1px solid var(--border);color:var(--text-dim);border-radius:6px;padding:3px 12px;font-family:'Source Sans 3',sans-serif;font-size:.72rem;cursor:pointer;transition:border-color .2s,color .2s;letter-spacing:.06em}
#clearBtn:hover{border-color:var(--gold-dim);color:var(--gold)}
</style>
</head>
<body>
<header>
  <div class="brand">
    <h1>Noah&#39;s Translator</h1>
    <span>Live &amp; Real-Time</span>
  </div>
  <div class="controls">
    <label class="select-label" for="sourceLang">From</label>
    <select id="sourceLang" class="lang-select"></select>
    <button class="swap-btn" id="swapBtn" title="Swap languages">⇄</button>
    <label class="select-label" for="targetLang">To</label>
    <select id="targetLang" class="lang-select"></select>
    <button id="toggleBtn">
      <span class="dot"></span>
      <span id="btnLabel">Start Listening</span>
    </button>
  </div>
</header>
<div id="statusBar">Ready — select languages and press Start Listening.</div>
<main>
  <div class="pane">
    <div class="pane-label" id="originalLabel">Original</div>
    <div class="transcript-box" id="originalBox">
      <p class="placeholder">Speech will appear here...</p>
    </div>
  </div>
  <div class="pane">
    <div class="pane-label" id="translationLabel">Translation</div>
    <div class="transcript-box" id="translationBox">
      <p class="placeholder">Translation will appear here...</p>
    </div>
  </div>
</main>
<footer>
  <span>Uses your browser&#39;s microphone &amp; Google Cloud Translation API &middot; Chrome recommended</span>
  <button id="clearBtn">Clear transcript</button>
</footer>
<script>
// ── All Google Translate supported languages ──────────────────────────────────
const LANGUAGES = [
  ["af","Afrikaans"],["sq","Albanian"],["am","Amharic"],["ar","Arabic"],
  ["hy","Armenian"],["as","Assamese"],["ay","Aymara"],["az","Azerbaijani"],
  ["bm","Bambara"],["eu","Basque"],["be","Belarusian"],["bn","Bengali"],
  ["bho","Bhojpuri"],["bs","Bosnian"],["bg","Bulgarian"],["ca","Catalan"],
  ["ceb","Cebuano"],["ny","Chichewa"],["zh","Chinese (Simplified)"],
  ["zh-TW","Chinese (Traditional)"],["co","Corsican"],["hr","Croatian"],
  ["cs","Czech"],["da","Danish"],["dv","Dhivehi"],["doi","Dogri"],["nl","Dutch"],
  ["en","English"],["eo","Esperanto"],["et","Estonian"],["ee","Ewe"],
  ["tl","Filipino"],["fi","Finnish"],["fr","French"],["fy","Frisian"],
  ["gl","Galician"],["ka","Georgian"],["de","German"],["el","Greek"],
  ["gn","Guarani"],["gu","Gujarati"],["ht","Haitian Creole"],["ha","Hausa"],
  ["haw","Hawaiian"],["iw","Hebrew"],["hi","Hindi"],["hmn","Hmong"],
  ["hu","Hungarian"],["is","Icelandic"],["ig","Igbo"],["ilo","Ilocano"],
  ["id","Indonesian"],["ga","Irish"],["it","Italian"],["ja","Japanese"],
  ["jw","Javanese"],["kn","Kannada"],["kk","Kazakh"],["km","Khmer"],
  ["rw","Kinyarwanda"],["gom","Konkani"],["ko","Korean"],["kri","Krio"],
  ["ku","Kurdish (Kurmanji)"],["ckb","Kurdish (Sorani)"],["ky","Kyrgyz"],
  ["lo","Lao"],["la","Latin"],["lv","Latvian"],["ln","Lingala"],
  ["lt","Lithuanian"],["lg","Luganda"],["lb","Luxembourgish"],["mk","Macedonian"],
  ["mai","Maithili"],["mg","Malagasy"],["ms","Malay"],["ml","Malayalam"],
  ["mt","Maltese"],["mi","Maori"],["mr","Marathi"],["mni-Mtei","Meitei (Manipuri)"],
  ["lus","Mizo"],["mn","Mongolian"],["my","Myanmar (Burmese)"],["ne","Nepali"],
  ["no","Norwegian"],["or","Odia (Oriya)"],["om","Oromo"],["ps","Pashto"],
  ["fa","Persian"],["pl","Polish"],["pt","Portuguese"],["pa","Punjabi"],
  ["qu","Quechua"],["ro","Romanian"],["ru","Russian"],["sm","Samoan"],
  ["sa","Sanskrit"],["gd","Scots Gaelic"],["nso","Sepedi"],["sr","Serbian"],
  ["st","Sesotho"],["sn","Shona"],["sd","Sindhi"],["si","Sinhala"],
  ["sk","Slovak"],["sl","Slovenian"],["so","Somali"],["es","Spanish"],
  ["su","Sundanese"],["sw","Swahili"],["sv","Swedish"],["tg","Tajik"],
  ["ta","Tamil"],["tt","Tatar"],["te","Telugu"],["th","Thai"],["ti","Tigrinya"],
  ["ts","Tsonga"],["tr","Turkish"],["tk","Turkmen"],["ak","Twi"],["uk","Ukrainian"],
  ["ur","Urdu"],["ug","Uyghur"],["uz","Uzbek"],["vi","Vietnamese"],["cy","Welsh"],
  ["xh","Xhosa"],["yi","Yiddish"],["yo","Yoruba"],["zu","Zulu"]
];

// BCP-47 codes used by the Web Speech API for recognition
const SPEECH_LOCALES = {
  "af":"af-ZA","sq":"sq-AL","am":"am-ET","ar":"ar-SA","hy":"hy-AM",
  "az":"az-AZ","eu":"eu-ES","be":"be-BY","bn":"bn-BD","bs":"bs-BA",
  "bg":"bg-BG","ca":"ca-ES","ceb":"en-US","zh":"zh-CN","zh-TW":"zh-TW",
  "hr":"hr-HR","cs":"cs-CZ","da":"da-DK","nl":"nl-NL","en":"en-US",
  "eo":"eo","et":"et-EE","tl":"fil-PH","fi":"fi-FI","fr":"fr-FR",
  "gl":"gl-ES","ka":"ka-GE","de":"de-DE","el":"el-GR","gu":"gu-IN",
  "ht":"fr-HT","ha":"ha","haw":"en-US","iw":"he-IL","hi":"hi-IN",
  "hu":"hu-HU","is":"is-IS","ig":"ig","id":"id-ID","ga":"ga-IE",
  "it":"it-IT","ja":"ja-JP","jw":"jv-ID","kn":"kn-IN","kk":"kk-KZ",
  "km":"km-KH","ko":"ko-KR","ky":"ky-KG","lo":"lo-LA","lv":"lv-LV",
  "lt":"lt-LT","mk":"mk-MK","ms":"ms-MY","ml":"ml-IN","mt":"mt-MT",
  "mi":"mi-NZ","mr":"mr-IN","mn":"mn-MN","my":"my-MM","ne":"ne-NP",
  "no":"nb-NO","fa":"fa-IR","pl":"pl-PL","pt":"pt-BR","pa":"pa-IN",
  "ro":"ro-RO","ru":"ru-RU","sm":"sm","sr":"sr-RS","sk":"sk-SK",
  "sl":"sl-SI","so":"so-SO","es":"es-ES","sw":"sw-KE","sv":"sv-SE",
  "tg":"tg-TJ","ta":"ta-IN","te":"te-IN","th":"th-TH","tr":"tr-TR",
  "tk":"tk-TM","uk":"uk-UA","ur":"ur-PK","uz":"uz-UZ","vi":"vi-VN",
  "cy":"cy-GB","xh":"xh-ZA","yi":"yi","yo":"yo-NG","zu":"zu-ZA"
};

// ── Populate dropdowns ─────────────────────────────────────────────────────────
const sourceLang = document.getElementById('sourceLang');
const targetLang = document.getElementById('targetLang');

LANGUAGES.forEach(([code, name]) => {
  const o1 = new Option(name, code);
  const o2 = new Option(name, code);
  sourceLang.appendChild(o1);
  targetLang.appendChild(o2);
});

// Default: English → Spanish
sourceLang.value = 'en';
targetLang.value = 'es';
updatePaneLabels();

// ── Swap button ────────────────────────────────────────────────────────────────
document.getElementById('swapBtn').addEventListener('click', () => {
  const tmp = sourceLang.value;
  sourceLang.value = targetLang.value;
  targetLang.value = tmp;
  updatePaneLabels();
  clearTranscript();
});

sourceLang.addEventListener('change', updatePaneLabels);
targetLang.addEventListener('change', updatePaneLabels);

function updatePaneLabels() {
  const srcName = sourceLang.options[sourceLang.selectedIndex].text;
  const tgtName = targetLang.options[targetLang.selectedIndex].text;
  document.getElementById('originalLabel').childNodes[0]
    ? (document.getElementById('originalLabel').firstChild.textContent = 'Original — ' + srcName)
    : (document.getElementById('originalLabel').textContent = 'Original — ' + srcName);
  document.getElementById('translationLabel').childNodes[0]
    ? (document.getElementById('translationLabel').firstChild.textContent = 'Translation — ' + tgtName)
    : (document.getElementById('translationLabel').textContent = 'Translation — ' + tgtName);
}

// Use a simpler label approach
function setLabel(el, text) {
  // Remove text nodes, leave ::after pseudo-element alone (it's CSS)
  el.textContent = text;
}

function updatePaneLabels() {
  const srcName = sourceLang.options[sourceLang.selectedIndex].text;
  const tgtName = targetLang.options[targetLang.selectedIndex].text;
  setLabel(document.getElementById('originalLabel'), 'Original — ' + srcName);
  setLabel(document.getElementById('translationLabel'), 'Translation — ' + tgtName);
}

// ── Core translation logic ─────────────────────────────────────────────────────
let recognition=null,listening=false,interimEl=null,interimTransEl=null,hasContent=false;
const toggleBtn=document.getElementById('toggleBtn'),btnLabel=document.getElementById('btnLabel'),
      statusBar=document.getElementById('statusBar'),originalBox=document.getElementById('originalBox'),
      transBox=document.getElementById('translationBox');

if(!('webkitSpeechRecognition'in window)&&!('SpeechRecognition'in window)){
  setStatus('⚠ Speech recognition not supported. Please use Google Chrome.','error');
  toggleBtn.disabled=true;
}

toggleBtn.addEventListener('click',()=>{if(!listening)startListening();else stopListening()});

function getSpeechLocale(code) {
  return SPEECH_LOCALES[code] || (code + '-' + code.toUpperCase());
}

function startListening(){
  const SR=window.SpeechRecognition||window.webkitSpeechRecognition;
  recognition=new SR();
  recognition.continuous=true;recognition.interimResults=true;
  recognition.lang = getSpeechLocale(sourceLang.value);
  recognition.maxAlternatives=1;
  recognition.onstart=()=>{listening=true;toggleBtn.classList.add('listening');btnLabel.textContent='Stop';setStatus('🎙 Listening…','ok')};
  recognition.onresult=(event)=>{
    let interim='';
    for(let i=event.resultIndex;i<event.results.length;i++){
      const r=event.results[i];
      if(r.isFinal){const t=r[0].transcript.trim();if(t)commitSentence(t);}
      else interim+=r[0].transcript;
    }
    showInterim(interim);
  };
  recognition.onerror=(e)=>{
    if(e.error==='no-speech')return;
    if(e.error==='not-allowed'){setStatus('⚠ Microphone access denied. Allow mic access and reload.','error');stopListening();return;}
    if(e.error==='language-not-supported'){setStatus('⚠ Source language not supported for speech recognition in this browser. Try a different source language or use Chrome.','error');stopListening();return;}
    setStatus('Speech error: '+e.error,'error');
  };
  recognition.onend=()=>{if(listening)recognition.start()};
  recognition.start();
}

function stopListening(){
  listening=false;
  if(recognition){recognition.onend=null;recognition.stop();recognition=null;}
  toggleBtn.classList.remove('listening');btnLabel.textContent='Start Listening';
  setStatus('Stopped.','');
  if(interimEl){interimEl.classList.remove('interim');interimEl=null;interimTransEl=null;}
}

function showInterim(text){
  clearPlaceholders();
  if(!interimEl){
    interimEl=makeEl('p','sentence-text interim');originalBox.appendChild(interimEl);
    interimTransEl=makeEl('div','shimmer');transBox.appendChild(interimTransEl);
  }
  interimEl.textContent=text||'…';scrollBoth();
}

function commitSentence(text){
  clearPlaceholders();
  let origEl,transEl;
  if(interimEl){
    origEl=interimEl;origEl.className='sentence-text';origEl.textContent=text;
    transEl=interimTransEl;interimEl=null;interimTransEl=null;
  } else {
    origEl=makeEl('p','sentence-text');origEl.textContent=text;originalBox.appendChild(origEl);
    transEl=makeEl('div','shimmer');transBox.appendChild(transEl);
  }
  scrollBoth();
  translateText(text, sourceLang.value, targetLang.value)
    .then(t=>{transEl.className='sentence-text';transEl.textContent=t;scrollBoth();});
}

async function translateText(text, source, target){
  try{
    const res=await fetch('/translate',{method:'POST',headers:{'Content-Type':'application/json'},
      body:JSON.stringify({text, source, target})});
    const data=await res.json();
    if(data.error){setStatus('Translation error: '+data.error,'error');return'[error]';}
    if(listening)setStatus('🎙 Listening…','ok');
    return data.translatedText||'[empty]';
  }catch(err){setStatus('Server error: '+err.message,'error');return'[error]';}
}

function clearTranscript(){
  originalBox.innerHTML='<p class="placeholder">Speech will appear here...</p>';
  transBox.innerHTML='<p class="placeholder">Translation will appear here...</p>';
  hasContent=false;interimEl=null;interimTransEl=null;
}
function clearPlaceholders(){if(!hasContent){originalBox.innerHTML='';transBox.innerHTML='';hasContent=true;}}
function makeEl(tag,cls){const e=document.createElement(tag);e.className=cls;return e;}
function scrollBoth(){originalBox.scrollTop=originalBox.scrollHeight;transBox.scrollTop=transBox.scrollHeight;}
function setStatus(msg,type){statusBar.textContent=msg;statusBar.className=type||'';}

document.getElementById('clearBtn').addEventListener('click', clearTranscript);
</script>
</body>
</html>"""

# ── Request handler ───────────────────────────────────────────────────────────
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def do_GET(self):
        if self.path in ('/', '/index.html'):
            body = HTML.encode()
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', len(body))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_error(404)

    def do_POST(self):
        if self.path == '/translate':
            length = int(self.headers.get('Content-Length', 0))
            body = json.loads(self.rfile.read(length))
            text   = body.get('text', '').strip()
            source = body.get('source', 'en')
            target = body.get('target', 'es')
            if not text:
                self._json({'translatedText': ''})
                return
            try:
                payload = json.dumps({
                    'q': text,
                    'source': source,
                    'target': target,
                    'format': 'text'
                }).encode()
                url = f'https://translation.googleapis.com/language/translate/v2?key={API_KEY}'
                req = urllib.request.Request(url, data=payload,
                      headers={'Content-Type': 'application/json'}, method='POST')
                with urllib.request.urlopen(req, timeout=10) as r:
                    result = json.loads(r.read())
                translated = result['data']['translations'][0]['translatedText']
                self._json({'translatedText': translated})
            except urllib.error.HTTPError as e:
                print(f'API error {e.code}: {e.read().decode()}')
                self._json({'error': f'API error {e.code}'}, 502)
            except Exception as e:
                print(f'Error: {e}')
                self._json({'error': str(e)}, 500)
        else:
            self.send_error(404)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'POST, GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def _json(self, data, status=200):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', len(body))
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(body)

if __name__ == '__main__':
    server = http.server.HTTPServer(('localhost', PORT), Handler)
    url = f'http://localhost:{PORT}/'
    print('=' * 50)
    print("  Noah's Translator")
    print(f'  Open: {url}')
    print('  Press Ctrl+C to stop.')
    print('=' * 50)
    threading.Timer(1.2, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\n  Stopped.')
PYEOF

# ── 4. Run it ─────────────────────────────────────────────────────────────────

echo ""
echo "  Starting Noah's Translator..."
echo "  Press Ctrl+C to stop."
echo ""
SERMON_API_KEY="$GOOGLE_API_KEY" "$PYTHON" "$TMPFILE"
