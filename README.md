# 🎶 FCM Song Broadcast App

An iOS app built with **SwiftUI** and **Firebase Cloud Messaging (FCM)**.  
The app displays a **main poster screen** with a set list of songs, allows navigation to **individual song screens**, and reacts to **push notifications** by navigating directly to the corresponding song.

---

## Features

- **Main Screen**
  - Poster image
  - Welcome message
  - Toggle to load set list either from **local JSON file** (bundled) or an **external web URL**

- **Song Screens**
  - One screen per song
  - Configurable `title`, `lyrics`, `backgroundColor`, `foregroundColor`
  - Occupies the whole screen

- **Push Notifications**
  - Notification body contains a **song title**
  - App navigates automatically to the matching SongView
  - Uses Firebase Cloud Messaging (FCM) and APNs

- **Consistent Theming**
  - Global app background color (e.g. pink) applied across all screens


https://console.firebase.google.com/u/0/project/tiefblau-2025/notification/compose






---
