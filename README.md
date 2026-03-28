# 🚀 Laravel 13 + React + FrankenPHP Auto-Deployer (Debian 12)

![Laravel 13 Auto-Deployer Banner](./docs/images/banner.png)

A high-performance, one-click shell script to automate the deployment of **Laravel 13**, **React**, **FrankenPHP**, and **MariaDB** on a clean **Debian 12 (Bookworm)** VPS.

[![PHP Version](https://img.shields.io/badge/php-8.4-777bb4.svg?style=flat-square&logo=php)](https://www.php.net/)
[![Laravel Version](https://img.shields.io/badge/laravel-13-ff2d20.svg?style=flat-square&logo=laravel)](https://laravel.com/)
[![React Version](https://img.shields.io/badge/react-19-61dafb.svg?style=flat-square&logo=react)](https://react.dev/)
[![FrankenPHP](https://img.shields.io/badge/server-FrankenPHP-00add8.svg?style=flat-square)](https://frankenphp.dev/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)

---

## 🏗️ Technical Stack

- **OS**: Debian 12 (Bookworm)
- **Engine**: PHP 8.4 (Sury Repo)
- **Frontend**: Node.js 22 LTS & NPM
- **Database**: MariaDB (MySQL Compatible)
- **App Server**: FrankenPHP (Modern, Go-based, ultra-fast)
- **Web Server**: Nginx (Reverse Proxy for Certbot/SSL)
- **Security**: UFW Firewall & Automated DB Hardening

---

## ✨ Features

![Key Features Grid](./docs/images/features.png)

- **Zero-Config SSL**: Automated Let's Encrypt (Certbot) setup.
- **Worker Mode Compatible**: Optimized for FrankenPHP's high-speed worker mode.
- **Auto-Deployment**: Handles `git clone`, `composer install`, and `npm build` automatically.
- **Smart Architecture Detection**: Automatically detects `x86_64` or `ARM64` system architecture to download the correct binaries.
- **Supervisor Management**: Ensures your application server stays alive 24/7.

---

## 🚀 Quick Start

Ensure you are running on a clean **Debian 12** installation. Run the following command as root:

```bash
# Clone the repository
git clone https://github.com/wiratmoko1708/auto-setp-laravel13.git && cd auto-setp-laravel13

# Make it executable
chmod +x auto.sh

# Run the installer
sudo ./auto.sh
```

### 📋 Prerequisites

- A fresh VPS running **Debian 12**.
- A Domain Name pointing to your VPS IP.
- Root or Sudo access.

---

## 🛡️ Security by Default

- **UFW Firewall**: Only opens SSH (22), HTTP (80), and HTTPS (443). All other ports (including Database) are closed to the public.
- **Hardened Database**: Automatically performs `mysql_secure_installation` steps, sets a root password, and creates a limited-access user for your app.
- **Modern Permissions**: Sets the correct recursive ownership (`www-data`) for `storage/` and `bootstrap/cache/`.

---

## 🛠️ Configuration Details

Once the script finishes, your application will be running on:
- **Internal Port**: 8000 (FrankenPHP)
- **External Ports**: 80/443 (Nginx Reverse Proxy)
- **Supervisor Config**: `/etc/supervisor/conf.d/frankenphp-YOURDOMAIN.conf`
- **Application Logs**: `/var/log/frankenphp-YOURDOMAIN.log`

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👨‍💻 Author

Created with ❤️ by **[wiratmoko1708](https://github.com/wiratmoko1708)**.

> *Empowering developers with lightning-fast Laravel deployments.*
