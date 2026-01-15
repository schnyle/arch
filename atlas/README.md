# Arch - Atlas

Installation for home server.

## Usage

Run this command from the Arch live environment:

```bash
curl -fsSL https://raw.githubusercontent.com/schnyle/arch/main/atlas.sh | \
  tee atlas.sh | \
  sha256sum -c <(curl -fsSL https://raw.githubusercontent.com/schnyle/arch/main/atlas.sh.sha256) && \
  chmod +x atlas.sh && \
  bash install.sh
```

## Requirements

- Debian 13.2

## TODO

- update SSH hardening to disallow password auth
