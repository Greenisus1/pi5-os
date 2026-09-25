#!/bin/bash -eu
# Install Liam's Pi terminal apps during the 64-bit Raspberry Pi OS image build.
# Upstream commit IDs and checksums pin the contents used for this image.
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
# Fix only the image's copy, not Liam's original GitHub repository.
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
assert s.count(old) == 1, 'CoolPi syntax changed; inspect before changing the build'
s = s.replace(old, new)
# An automatic update to an invalid URL should not run every time the app starts.
old = 'update_script  # you can comment this out to disable auto-update on each run'
assert s.count(old) == 1, 'CoolPi startup changed; inspect before changing the build'
s = s.replace(old, '# Auto-update disabled: the upstream URL is a placeholder and upstream syntax is broken.')
# Avoid advertising a working updater when the source URL is not configured.
old = 'SCRIPT_URL="https://your-repo-or-url/coolpi.sh"  # URL to fetch latest script version for self-update'
assert s.count(old) == 1
s = s.replace(old, 'SCRIPT_URL=""  # Upstream auto-update unavailable; use a reviewed image rebuild instead.')
p.write_text(s)
PY
bash -n "$workdir/wishnow" "$workdir/wishtoday" "$workdir/coolpi"
install -D -m 0755 "$workdir/wishnow" /usr/local/bin/wishnow
install -D -m 0755 "$workdir/wishtoday" /usr/local/bin/wishtoday
install -D -m 0755 "$workdir/coolpi" /usr/local/bin/coolpi
