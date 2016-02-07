# crypt-backup-to-ftps

The script dumps a MySQL database and an htdocs folder, gzips them and encrypts with a public GPG key, calculates a SHA1 hash of the database backup file and then uploads files to a remote FTPS server.

After the upload is done, the script downloads the uploaded database file back from the FTPS server and calculates a SHA1 hash, then compares it with the original backup file. An email is sent regardless of the outcome (whether the hashes are the same or different).

# Installation on Debian Wheezy

The following packages are used by the script:
 
* Gzip
* GPG
* FTP-SSL
* Heilroom-mailx
 
To install:

<pre># apt-get install gzip gpgv ftp-ssl heirloom-mailx</pre>

FTP client uses the <strong>~/.netrc</strong> file for authentication which looks like this:

<code>machine ftp.example.com login ftp_user password ftp_password</code>
