+++
title = "How I Fixed Missing H.264 Codecs on a Fresh Fedora Install"
date = 2026-01-09T01:43:00+05:00
slug = "fixing-h264-codec-fedora"
path = "posts/fixing-h264-codec-fedora"
draft = false

[taxonomies]
tags = ["linux","fedora","troubleshooting","multimedia"]

[extra]
author = "Jameel Ahmad"
description = "A deep dive into why H.264 videos don't play on Fedora by default and how to swap \"ffmpeg-free\" for the full version."
featured = true
og_image = "/assets/images/fixing-h264-codec-fedora.png"
original_file_path = "src/data/blog/fixing-h264-codec-fedora.md"
+++

I freshly installed Fedora Linux Workstation 43 on my PC and tried to play a video. The video played, but it was blank. It turned out there was an issue with the missing video decoder required to run this video: **H.264**.

![Retro style pixel art of a Linux terminal fixing codecs](/assets/images/fixing-h264-codec-fedora.png)

The issue is that this encoder is proprietary and does not come with Fedora by default due to licensing restrictions. To fix this, I had to dive into the world of FFmpeg and package management.

## Table of contents

## The Mystery of the "Missing" FFmpeg

There is a huge library of multimedia encoders and decoders out there called FFmpeg. I needed to check if FFmpeg was installed in Fedora and if it included the H.264 encoder.

I used the command:
```bash
dnf list installed | grep ffmpeg

```

Surprisingly, I got nothing. However, when I ran `ffmpeg` directly in the terminal, the command worked! It was strange to me how a command-line utility could be available even when it didn't appear as "installed" in my package list.

## Finding the Culprit: ffmpeg-free

It turns out Fedora comes with a "free" version of FFmpeg that excludes proprietary encoders. To solve the mystery, I first checked where the command was running from:

```bash
which ffmpeg
# Output: /usr/bin/ffmpeg

```

Then, I passed this path to RPM to check which package exactly owned this file:

```bash
rpm -qf /usr/bin/ffmpeg

```

The result: `ffmpeg-free-7.1.2-2.fc43.x86_64`.

This confirmed that the "free" version was installed, which lacks the H.264 proprietary encoder.

## The Solution: Swapping to RPM Fusion

To fix this, I needed to enable the **RPM Fusion** repositories and swap the limited version for the full one.

### 1. Enable Repositories

First, I enabled the free and non-free RPM Fusion repositories:

```bash
sudo dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

```

### 2. Swap the Packages

Then, I used this command to install the proprietary version of FFmpeg and remove the pre-installed free one:

```bash
sudo dnf swap ffmpeg-free ffmpeg --allowerasing

```

## Fixing Lag and Crashes

The codec was installed successfully and the video played, but I hit another problem: the video was lagging heavily and the player sometimes crashed.

The default video player tries to find the right codec automatically, but sometimes it tries to roll back to the "free" version or struggles with dependencies. To enforce all multimedia apps to use the preferred encoding packages, I ran:

```bash
sudo dnf update @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin

```

### What does this command do?

* **`@multimedia`**: This is the group in which all multimedia-related apps are grouped by Fedora.
* **`install_weak_deps=False`**: This prevents the system from pulling back in the limited "free" versions as optional dependencies.
* **`--exclude=PackageKit-gstreamer-plugin`**: This stops the GUI software store from interfering with our manual codec setup.

After running this, the H.264 videos played perfectly smooth!
