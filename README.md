# Legacy Reddit

Initial iOS 12 arm64 native Reddit client.

## Build

This is a Theos application project. The GitHub Actions workflow builds the rootful Debian package without requiring a Mac.

The current implementation provides:
- iOS 12 UIKit UI
- Reddit `/r/all` feed
- Pull to refresh
- Post titles, subreddit, author
- Open post in Safari
- arm64/rootful `.deb`

## Install

After building, install the resulting `.deb` with your jailbreak package manager or:

    dpkg -i com.legacyreddit.client_1.0.0_iphoneos-arm64.deb
    uicache -p /Applications/LegacyReddit.app

Then respring if SpringBoard does not immediately show the icon.

## Important

Reddit API access can change independently of the app. The client currently uses the public JSON listing endpoint and a descriptive User-Agent. Full authenticated voting/commenting requires OAuth credentials and additional API integration.
