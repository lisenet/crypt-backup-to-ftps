#!/bin/bash
# AUTHOR:   Tomas Nevar (tomas@lisenet.com)
# NAME:     crypt-backup-to-ftps.sh
# VERSION:  1.1
# DATE:     25/08/2013 (dd/mm/yy)
# LICENCE:  Copyleft free software
#
# DEBIAN INSTALL: apt-get install gzip ftp-ssl heirloom-mailx gpgv
# FTP client uses ~/.netrc file for authentication which looks like this:
# machine ftp.example.com login ftp_user password ftp_password
#--------------------------------------------
#
##############################################
# Revision History
#
# Version 1.0 - Tomas Nevar
# Change notes: Initial release.
#
# Version 1.1 - Tomas Nevar
# Change notes: a) ccrypt is replaced with GPG,
#               b) MD5 is replaced with SHA1,
#               c) old local backups are deleted on Saturdays,
#               d) script backups htdocs folder as well.
#
#############################################

declare -r FTP_HOST="ftp.example.com";
declare -r SQL_DB="db_name"
declare -r SQL_USER="db_user"
declare -r SQL_PASS="db_passwd"
# The GPG key should be trusted
declare -r GPG_USER="user@example.com";

# Backup /var/www/htdocs
declare -r WWW="/var/www";
declare -r WWW_DIR="htdocs";
declare -r WWW_BACKUP="htdocs_$(date +%F).tgz";
declare -r WWW_BACKUP_ENCRYPTED="htdocs_$(date +%F).tgz.gpg";

# Filepath as /backups/July (example)
declare -r BACKUP_DIR="/path/to/local/backup/folder";
declare -r BACKUP_PATH=""$BACKUP_DIR"/$(date +%B)";
declare -r REMOTE_PATH="/";
declare -r FILENAME="db_$(date +'%Y-%m-%d').sql.gz";
declare -r ENCRYPTED="db_$(date +'%Y-%m-%d').sql.gz.gpg";
declare -r ENCRYPTED_REMOTE="sql_$(date +'%Y-%m-%d').sql.gz.gpg.remote";

declare -r EMAIL_MSG_FAIL=""$ENCRYPTED" ftp upload failed, SHA1 hashes don't match!";
declare -r EMAIL_FROM="backup-script@example.com";
declare -r EMAIL_TO="user@example.com";

function backup_www()
{
    if [ ! -d "$WWW" ]; then
        echo ""$WWW" does not exists.";
        exit 1;
    fi

    cd "$WWW";
    echo "Current working directory:" $(pwd);
    tar cfz ./"$WWW_BACKUP" "$WWW_DIR";

    echo "Directory "$WWW_DIR" archived as "$WWW_BACKUP", encrypting the file.";
    $GPG_CMD --output "$WWW_BACKUP_ENCRYPTED" "$WWW_BACKUP";
    chmod 0640 "$WWW_BACKUP_ENCRYPTED";

    SIZE=$(du -bk "$WWW_BACKUP_ENCRYPTED"|cut -f1);
    echo "The size of the compressed "$WWW_BACKUP_ENCRYPTED" file is: "$SIZE"B";

    mv "$WWW_BACKUP_ENCRYPTED" "$BACKUP_PATH"/;
    rm -f "$WWW_BACKUP";
}

function sql_dump()
{
    cd "$BACKUP_PATH";
    echo "Current working directory:" $(pwd);

    echo "Dumping "$SQL_DB" database.";
    mysqldump --user="$SQL_USER" --password="$SQL_PASS" --events --triggers \
      "$SQL_DB" | gzip >./"$FILENAME";

    echo "Database dumped as "$FILENAME", encrypting the file.";
    $GPG_CMD --output "$ENCRYPTED" "$FILENAME";
    chmod 0640 "$ENCRYPTED";
    rm -f "$FILENAME";

    SIZE=$(du -bk "$ENCRYPTED"|cut -f1);
    echo "The size of the compressed database file is: "$SIZE"B";
}

function ftp_upload()
{
    # Start measuring FTP upload time
    local -r -i start=$(date +%s);

    echo "Database "$ENCRYPTED" file encrypted, opening passive FTP session.";

    # ftp credentials are stored under ~/.netrc
    # -p uses passive mode, -i turns off interactive prompting,
    # -v enables verbose and progress, 
    # -z secure prevent from switching back to unencrypted mode
    # if "-" is appended to <<, then all leading tabs are stripped from word and from the document

    ftp-ssl -pivz secure "$FTP_HOST" 990 <<End-Of-Session
binary
lcd "$BACKUP_PATH"
cd "$REMOTE_PATH"
put "$ENCRYPTED"
put "$WWW_BACKUP_ENCRYPTED"
bye
End-Of-Session

    local -r -i end=$(date +%s);
    DIFF=$(($end - $start));
    echo "It took "$DIFF" seconds to upload the file.";
}

function ftp_check()
{
    echo -e "\nOpening FTP session again to get the DB file for integrity check.\n";
    ftp-ssl -pivz secure "$FTP_HOST" 990 <<End-Of-Session
binary
lcd "$BACKUP_PATH"
get "$REMOTE_PATH""$ENCRYPTED" "$ENCRYPTED_REMOTE"
bye
End-Of-Session

    # Calculates SHA1 hashes for both backup files
    local -r a=$(sha1sum -b "$ENCRYPTED" | cut -d" " -f1);
    local -r b=$(sha1sum -b "$ENCRYPTED_REMOTE" | cut -d" " -f1);
    echo "sha1sum: local "$a", remote "$b"";

    EMAIL_MSG=""$ENCRYPTED" | SHA1: "$b"";

    # Send email with SHA1 hash is successful, mail error otherwise
    if [ "$a" == "$b" ]; then
        echo "$EMAIL_MSG" | mail -s ""$ENCRYPTED" "$SIZE" "$DIFF"" -r "$EMAIL_FROM" "$EMAIL_TO";
	    rm "$ENCRYPTED_REMOTE";
	    echo "Files are identical."
    else
        echo "$EMAIL_MSG_FAIL" | mail -s ""$ENCRYPTED" FAILED" -r "$EMAIL_FROM" "$EMAIL_TO";
	echo "Files are different.";
    fi
}

delete_local_backups()
{
    current_month=$(date +'%B');
    previous_month=$(date --date='-1 month' +'%B');
    for month in $(\ls -1t "$BACKUP_DIR"); do
        if [[ "$month" != "$current_month" && "$month" != "$previous_month" ]]; then 
            rm -r "$BACKUP_DIR"/"$month";
        fi
    done
}

main()
{
    if [ ! -d "$BACKUP_PATH" ]; then
        echo ""$BACKUP_PATH" does not exists, creating.";
        mkdir -p -m 0750 "$BACKUP_PATH";
    fi
 
    GPG_CMD="gpg --encrypt --recipient "$GPG_USER" --trust-model always";
    backup_www;
    sql_dump;
    ftp_upload;
    ftp_check;
    
    # Run delete_local_backups routine on Saturdays 
    if [ "$(date +%u)" == "6" ]; then
        delete_local_backups;
    fi
}
main "$@"
