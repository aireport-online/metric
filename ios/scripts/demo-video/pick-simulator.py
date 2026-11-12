#!/usr/bin/env python3
"""Kiest een simulatortype en -runtime voor de demovideo.

Gebruik: pick-simulator.py iOS|watchOS <sdk-versie>
Uitvoer: <devicetype-id> TAB <runtime-id> TAB <naam>
"""
import json
import subprocess
import sys

PREFERRED = {
    "iOS": ["iPhone 16", "iPhone 16 Pro", "iPhone 17", "iPhone 15", "iPhone 15 Pro"],
    "watchOS": [
        "Apple Watch Series 10 (46mm)",
        "Apple Watch Series 11 (46mm)",
        "Apple Watch Series 9 (45mm)",
        "Apple Watch Ultra 2 (49mm)",
    ],
}
NAME_PREFIX = {"iOS": "iPhone", "watchOS": "Apple Watch"}


def version(text):
    return tuple(int(part) for part in text.replace("-", ".").split(".") if part.isdigit())


def main():
    platform, sdk = sys.argv[1], version(sys.argv[2])
    listing = subprocess.run(
        ["xcrun", "simctl", "list", "devices", "available", "--json"],
        check=True, capture_output=True, text=True,
    ).stdout
    runtimes = []
    for key, devices in json.loads(listing)["devices"].items():
        tail = key.rsplit(".", 1)[-1]  # bv. iOS-18-5
        if not tail.startswith(platform + "-"):
            continue
        devices = [
            device for device in devices
            if device.get("isAvailable", True)
            and device["name"].startswith(NAME_PREFIX[platform])
            and device.get("deviceTypeIdentifier")
        ]
        if devices:
            runtimes.append((version(tail[len(platform) + 1:]), key, devices))
    if not runtimes:
        sys.exit(f"Geen beschikbare {platform}-simulator gevonden.")

    # Liefst de nieuwste runtime die niet nieuwer is dan de SDK van de gekozen Xcode.
    runtimes.sort(key=lambda item: (item[0][:2] <= sdk[:2], item[0]), reverse=True)
    _, runtime, devices = runtimes[0]
    choice = next((d for name in PREFERRED[platform] for d in devices if d["name"] == name), None)
    if choice is None:
        regular = [d for d in devices if " SE" not in d["name"] and "mini" not in d["name"]]
        choice = sorted(regular or devices, key=lambda d: d["name"])[-1]
    print(choice["deviceTypeIdentifier"], runtime, choice["name"], sep="\t")


if __name__ == "__main__":
    main()
