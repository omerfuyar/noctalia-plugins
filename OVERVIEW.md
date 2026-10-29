# Overview

What the plugins in this repository are and why they exist. How they are built is in [DESIGN.md](DESIGN.md).

## Contents

1. [What this is](#1-what-this-is)
2. [Principles](#2-principles)
3. [Scope](#3-scope)
4. [Plugins](#4-plugins)
5. [Contributions to other plugins](#5-contributions-to-other-plugins)
6. [Glossary](#6-glossary)

## 1. What this is

1. A collection of plugins for Noctalia v5, by omerfuyar.
2. Many of them bring features of Omarchy plugins to Noctalia. They are rebuilt for Noctalia, not copied.
3. The repository is itself a plugin source: anyone can add it to Noctalia and install from it.
4. Finished plugins are also offered to community-plugins, so people find them in Noctalia's plugin store.

## 2. Principles

In order of priority:

1. **User friendly.** A plugin works right after it is enabled. Its defaults make sense for most people.
2. **Easy to configure.** Few settings, each with a clear label and a default. Rare settings are hidden as advanced.
3. **Little to no setup or upkeep.** Few dependencies. When a plugin really needs something the user must install or set up once, it says so itself and offers to do it, from a place that is easy to reach.
4. **In the bar.** Plugins live mostly in the bar. Details and controls open from the bar item.
5. **Better than the default.** A plugin adds what Noctalia lacks, or joins related controls that Noctalia keeps apart. It does not repeat what Noctalia already does well.
6. **Native look.** A plugin looks and feels like the rest of Noctalia and follows the user's theme. It never depends on one machine: no fixed monitor names, paths or screen sizes.
7. **No AI features.**

## 3. Scope

### 3.1 In scope

1. Features Noctalia lacks.
2. Features Noctalia has but in a weaker form, where one plugin can do clearly better.

### 3.2 Out of scope

1. Features Noctalia already does well: clipboard history, notifications and their history, media controls, system monitor, tray, window switcher, keyboard layout, Wi-Fi, Bluetooth, audio devices and app volumes, screen time, theming and the lock screen.
2. Features that existing community plugins cover well: Proton VPN, prayer times, daily Quran verses, keybinding cheat sheet.
3. AI features.
4. Tools that only make sense on Omarchy, such as managing Omarchy plugins or Omarchy updates.

## 4. Plugins

Directory names are working names; section 2 of [DESIGN.md](DESIGN.md) says how a final name is chosen.

### 4.1 Screen Control

One bar item for everything about the screens. It shows brightness for each monitor, dims a screen further than its lowest brightness, and switches night light. It can dim each workspace on its own.

Brought from: Omarchy's screen-comfort plugin.

### 4.2 Downloader

Downloads video or audio from a link with yt-dlp. The user pastes a link, picks audio or video, and follows the queue and progress from the bar.

Brought from: Omarchy's otoru plugin.

### 4.3 Agenda

Shows the next calendar event in the bar, with a countdown. The panel lists today's and this week's events, and a Join button opens a meeting link. It uses the calendars already set up in Noctalia, so it needs no setup of its own.

Brought from: Omarchy's calendar plugin.

### 4.4 Overview

A full-screen view of all workspaces and their windows. The user clicks a window to focus it, and drags it to move it to another workspace.

Brought from: Omarchy's Mirador plugin.

### 4.5 Display Layout

Arranges monitors by dragging, with snapping. It sets resolution, refresh rate, scale, VRR and HDR, keeps layout profiles, and maps workspaces to monitors.

Brought from: Omarchy's screens plugin.

### 4.6 Phone Cam

Uses an Android phone as a webcam, and mirrors its screen.

Brought from: Omarchy's dori plugin.

### 4.7 Radio

Finds and plays internet radio stations by country and genre, with favorites.

Brought from: Omarchy's radio-atlas plugin.

### 4.8 Resurrect

Saves the system's setup (packages, dotfiles, Noctalia settings and enabled services) to a git repository, and restores it on a new install.

Brought from: Omarchy's resurrect plugin.

## 5. Contributions to other plugins

The owner improves community plugins they use by offering changes to their authors. Each change follows section 2.

| Plugin            | Change                                                                                                 |
| ----------------- | ------------------------------------------------------------------------------------------------------ |
| Crashes           | Also show failed services and errors from the system log since boot. Make the AI diagnosis optional.   |
| Hyprland Settings | The monitor features of section 4.5, if its author agrees. Otherwise they stay in Display Layout.      |

## 6. Glossary

| Term              | Meaning                                                                                        |
| ----------------- | ---------------------------------------------------------------------------------------------- |
| community-plugins | The repository `noctalia-dev/community-plugins`. Its plugins appear in Noctalia's plugin store. |
| Noctalia          | The desktop shell these plugins are for: bar, panels, launcher and more, on Wayland.           |
| Omarchy           | A Linux setup with its own shell and plugin store. Many plugins here started as its plugins.   |
| Plugin source     | A git repository or folder that Noctalia installs plugins from.                                |
