# Moodle LMS - Production Docker Setup

This repository contains a production-ready Docker setup for [Moodle LMS](https://moodle.org/).

## ✅ Features

- Bitnami Moodle image with persistent storage
- MariaDB database with UTF-8 support
- Moodle cron job (background scheduler)
- Environment-based secrets/configs
- Minimal and clean production-ready config

---

## 📁 Directory Structure

/
└──
  ├── docker-compose.yml
  ├── .env.example ← Rename to .env and fill in
  ├── README.md
  └── data/
    ├── moodle/ ← Moodle app files
    ├── moodledata/ ← Uploaded files, sessions
    └── mariadb/ ← MariaDB data
