# BlackEye – Educational Phishing Lab (v1.3)

> **⚠️ Lab‑Only Use**
> This tool is _strictly_ for controlled, educational environments.  It must **never** be deployed against real users without explicit, documented consent.  The `--lab` flag (default when you run the script with `--lab`) injects a clear warning banner on every generated phishing page.

---

## 📚 Overview
`blackeye` is a lightweight Bash/PHP framework that automates the creation of credential‑phishing pages for a variety of social‑media platforms.  It was designed for **security‑training labs** where students can practice detecting and responding to phishing attacks.

Key features (v1.3):
- **Platform menu** – over 40 pre‑configured templates (Instagram, Facebook, etc.)
- **Tunnelling** – LocalTunnel **or** Ngrok for public URL exposure
- **Lab‑mode banner** – red warning banner on pages when `--lab` is used
- **Telegram alerts** – optional real‑time notifications for captured IPs and credentials
- **JSON‑structured per‑session logs** stored under `sites/<platform>/logs/`
- **Session summary** – printed on exit (counts + log path)
- **Environment file** `.env` for easy configuration (tokens, flags, etc.)

---

## 🚀 Quick Start
1. **Prerequisites** (all must be on your PATH):
   - `bash` (Git Bash, WSL, or Cygwin)
   - `php` (>=7.4)
   - `node` (for `node_modules` utilities)
   - `lt` (LocalTunnel CLI)
   - `ngrok` (optional, for ngrok tunnelling)
   - `jq` (for JSON handling)
   - `curl`
2. **Clone / download** the repository and `cd` into the project root.
3. **Create a `.env` file** (optional) – example:
   ```dotenv
   TELEGRAM_BOT_TOKEN=123456:ABC-DEF...
   TELEGRAM_CHAT_ID=987654321
   NGROK_AUTHTOKEN=your-ngrok-token
   LAB_MODE=1   # set to 1 to enable lab‑mode by default
   ```
4. **Run the script** (lab‑mode is recommended):
   ```bash
   bash blackeye.sh --lab
   ```
5. Choose a platform number, then select tunnelling method:
   - `1` – LocalTunnel (default)
   - `2` – Ngrok (requires ngrok installed)
6. Share the generated public URL with your lab participants.  When a victim visits the page, the script will:
   - Capture IP/UA data → JSON log + Telegram alert (if configured)
   - Capture credentials → JSON log + Telegram alert
   - Display a red **[LAB MODE]** banner on the phishing page.
7. **Stop the session** with `Ctrl+C`.  A summary like:
   ```
   Session Summary:
   • IPs captured: 3
   • Credentials captured: 2
   • Log file: sites/instagram/logs/20261009_144500.json
   ```
   will be printed.

---

## 📂 Project Layout
```
blackeye/
├─ blackeye.sh          # main Bash driver (v1.3)
├─ .env                 # optional env configuration
├─ sites/               # platform‑specific files
│   ├─ instagram/
│   │   ├─ ip.php       # captures visitor IP & UA
│   │   ├─ login.php    # fake login page
│   │   ├─ logs/        # per‑session JSON logs (auto‑created)
│   │   └─ ...
│   └─ ...
└─ README.md            # **this file**
```

---

## 🛠️ Development & Extending Templates
1. **Add a new platform**
   - Create a folder under `sites/` (e.g., `myapp`).
   - Populate `ip.php` and `login.php` (or any additional pages).
   - Ensure the PHP scripts write to the shared log via the environment variable `LOG_FILE` (set by `blackeye.sh`).
2. **Custom lab‑mode banner**
   - Edit `createpage()` in `blackeye.sh` or modify the PHP template to include:
   ```php
   <?php if ( getenv('LAB_MODE') == '1' ) { echo '<div style="...">[LAB MODE] ...</div>'; } ?>
   ```
3. **Telegram integration** – if you prefer PHP‑side alerts, call the helper script `send_telegram_alert.sh` (included) with the message payload.

---

## ⚠️ Legal & Ethical Use
- **Never** use this tool against unsuspecting users.  All participants must be briefed and give informed consent.
- Keep the `--lab` banner visible at all times during training.
- Store captured data securely and delete it after the lab.
- This project is provided **as‑is** for educational purposes only; the author assumes no liability for misuse.

---

## 📜 License
Distributed under the **MIT License** – see `LICENSE` for details.

---

## 🙋‍♀️ Support
For questions, open an issue on the repository or contact the maintainer via the Telegram bot (if configured).
