# Problem
Desktop casting occasionally skips. A one-second prebuffer and 200 ms capture latency fixed the skipping in a live trial, but the extra delay made YouTube unusable.

# Why this fix
Add an optional Buffer audio toggle to the Sonos panel and CLI. Default to the existing low-delay path; use the successful trial settings only when enabled. Reconnect active casting when switching so disabling also clears queued audio.

# Blast radius
Only this plugin's stream handler, controls, and runtime preference. The selection survives casting off/on within the login session; a fresh runtime directory defaults to off. No changes to browser routing or speaker volume.

# Revert
Revert the implementation commit and restart casting. The extra runtime preference is ignored by the original code.
