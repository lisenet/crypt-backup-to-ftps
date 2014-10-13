# crypt-backup-to-ftps

The script dumps a MySQL database, gzips it and encrypts with ccrypt, calculates an MD5 hash of the backup file and then uploads it to a remote FTPS server.

After the upload is done, the script downloads the uploaded file back from the FTPS server and calculates an MD5 hash, then compares it with the original backup file. An email is sent regardless of the outcome (whether the hashes are the same or different).

# Installation on Debian Wheezy

The following packages are used by the script:
 
* Gzip
* Ccrypt
* FTP-SSL
* Heilroom-mailx
 
To install:

<pre># apt-get install gzip ccrypt ftp-ssl heirloom-mailx</pre>

FTP client uses the <strong>~/.netrc</strong> file for authentication which looks like this:

<code>machine ftp.example.com login ftp_user password ftp_password</code>
