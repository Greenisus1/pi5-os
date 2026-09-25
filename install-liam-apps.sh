#!/bin/bash
# Install Liam's Pi terminal apps (wishnow, wishtoday, coolpi) on a live
# 64-bit Raspberry Pi OS system (Pi 5). Run it with sudo, e.g.:
#   curl -fsSL https://raw.githubusercontent.com/Greenisus1/pi5-os/arm64/install-liam-apps.sh | sudo bash
# Upstream commit IDs and checksums pin the exact contents installed.
set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "This needs root. Run it with sudo, e.g.:" >&2
  echo "  curl -fsSL https://raw.githubusercontent.com/Greenisus1/pi5-os/arm64/install-liam-apps.sh | sudo bash" >&2
  exit 1
fi

for cmd in curl python3 sha256sum install; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Missing required command: $cmd" >&2; exit 1; }
done

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

curl -fLsS --retry 3 -o "$workdir/wishnow" 'https://raw.githubusercontent.com/Greenisus1/WISHNOW/f6548d166862654258b1c4d500316f3c1ea20d9f/wishnow.sh'
curl -fLsS --retry 3 -o "$workdir/wishtoday" 'https://raw.githubusercontent.com/Greenisus1/Wishtoday/beeb06d27993c87be500fe6dab5c8a12bc19ad83/wishtoday.sh'
curl -fLsS --retry 3 -o "$workdir/coolpi" 'https://raw.githubusercontent.com/Greenisus1/microsoftcopilotcodeusedonpi/0266847a44b9285e41931e5ed417d87c725f310e/coolpi.sh'
cd "$workdir"
printf '%s\n' \
  '8fcad4bb22bcd7402daaf064e07cec0456c740a426c27095f2a90b911ab2fc86  wishnow' \
  'a17d1b2e865f2cf561c0845b11f3d9eacb4f576afa0c277ec53cd8f35e90397e  wishtoday' \
  '020ed2c700746ff42610f043ff0e34ccc319bd9d29ed729e90026bb42d0b4e0d  coolpi' | sha256sum -c -

# CoolPi upstream has an unterminated delete-file case and an invalid self-update URL.
# Fix only the installed copy, not Liam's original GitHub repository.
python3 - "$workdir/coolpi" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = '''                            fi
                        
                        
                    0)
                        # Cancel file action
                        ;;
                    *)
                        echo "Invalid option."
                        
                esac'''
new = '''                            fi
                        fi
                        ;;
                    0)
                        # Cancel file action
                        ;;
                    *)
                        echo "Invalid option."
                        ;;
                esac'''
assert s.count(old) == 1, 'CoolPi syntax changed; inspect before changing the install'
s = s.replace(old, new)
# An automatic update to an invalid URL should not run every time the app starts.
old = 'update_script  # you can comment this out to disable auto-update on each run'
assert s.count(old) == 1, 'CoolPi startup changed; inspect before changing the install'
s = s.replace(old, '# Auto-update disabled: the upstream URL is a placeholder and upstream syntax is broken.')
# Avoid advertising a working updater when the source URL is not configured.
old = 'SCRIPT_URL="https://your-repo-or-url/coolpi.sh"  # URL to fetch latest script version for self-update'
assert s.count(old) == 1
s = s.replace(old, 'SCRIPT_URL=""  # Upstream auto-update unavailable; install a reviewed version instead.')
p.write_text(s)
PY
for app in wishnow wishtoday coolpi; do
  bash -n "$workdir/$app"
  install -D -m 0755 "$workdir/$app" /usr/local/bin/"$app"
done
echo "Installed: wishnow, wishtoday, coolpi -> /usr/local/bin"
