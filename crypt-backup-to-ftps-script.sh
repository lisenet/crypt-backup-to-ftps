#!/bin/bash
# written by Tomas Nevar (tomas@lisenet.com)
# 25/08/2013 (dd/mm/yy)
# copyleft free software
#
# DEBIAN INSTALL: apt-get install gzip ccrypt ftp-ssl heirloom-mailx
# FTP client uses ~/.netrc file for authentication which looks like this:
# machine ftp.example.com login ftp_user password ftp_password
#--------------------------------------------
#
declare -r FTP_HOST="ftp.example.com"
declare -r SQL_DB="db_name"
declare -r SQL_USER="db_user"
declare -r SQL_PASS="db_passwd"
declare -r CCRYPT_FILE="/path/to/key/file"

declare -r FILEPATH="/path/to/local/backup/folder/"
declare -r REMOTE_PATH="/path/to/remote/ftp/backup/folder/"
declare -r FILENAME="sql_`date +'%Y-%m-%d'`.sql.gz"
declare -r ENCRYPTED="sql_`date +'%Y-%m-%d'`.sql.gz.cpt"
declare -r ENCRYPTED_REMOTE="sql_`date +'%Y-%m-%d'`.sql.gz.cpt.remote"

declare -r EMAIL_MSG_FAIL=""$ENCRYPTED" ftp upload failed, md5 hashes don't match!"
declare -r EMAIL_FROM="backup-script@example.com"
declare -r EMAIL_TO="user@example.com"

function sql-dump()
{
	echo "Dumping "$SQL_DB" database.";
	mysqldump -u "$SQL_USER" -p"$SQL_PASS" "$SQL_DB" | gzip >./"$FILENAME";

	echo "Database dumped as "$FILENAME", encrypting the file.";
	ccencrypt -fk "$CCRYPT_FILE" ./"$FILENAME";
	chmod 0640 "$ENCRYPTED";

	SIZE=$(du -bk "$ENCRYPTED" | cut -f1);
	echo "The size of the compressed database file is: "$SIZE"";
}
function ftp-upload()
{
	# start measuring FTP upload time
	local -r -i start=$(date +%s);

	echo "Database "$ENCRYPTED" file encrypted, opening passive FTP session.";

	# ftp credentials are stored under ~/.netrc
        # -p uses passive mode, -i turns off interactive prompting,
	# -v enables verbose and progress, 
	# -z secure prevent from switching back to unencrypted mode
	# if "-" is appended to <<, then all leading tabs are stripped from word and from the document

	ftp-ssl -pivz secure "$FTP_HOST" 990 <<End-Of-Session
binary
lcd "$FILEPATH"
cd "$REMOTE_PATH"
put "$ENCRYPTED"
bye
End-Of-Session

	local -r -i end=$(date +%s);
	DIFF=$(($end - $start));
	echo "It took "$DIFF" seconds to upload the file.";
}
function ftp-check()
{
	echo "Opening FTP session again to get the file for integrity check.";
	ftp-ssl -pivz secure "$FTP_HOST" 990 <<End-Of-Session
binary
lcd "$FILEPATH"
get "$REMOTE_PATH""$ENCRYPTED" "$ENCRYPTED_REMOTE"
bye
End-Of-Session

	# calculates md5 hashes for both backup files
	local -r a=$(md5sum -b "$ENCRYPTED" | cut -d" " -f1);
	local -r b=$(md5sum -b "$ENCRYPTED_REMOTE" | cut -d" " -f1);
	echo "md5sums: local "$a", remote "$b"";

	EMAIL_MSG=""$ENCRYPTED" | MD5sum: "$b"";

        # send email with md5 hash is successful, mail error otherwise
	if [ "$a" == "$b" ]; then
		echo "$EMAIL_MSG" | mail -s ""$ENCRYPTED" "$SIZE" "$DIFF"" -r "$EMAIL_FROM" "$EMAIL_TO";
		rm "$ENCRYPTED_REMOTE";
		echo "Files are identical."
	else
		echo "$EMAIL_MSG_FAIL" | mail -s ""$ENCRYPTED" FAILED" -r "$EMAIL_FROM" "$EMAIL_TO";
		echo "Files are different.";
	fi
}
main()
{
        cd "$FILEPATH";
        echo "Current working directory:" $(pwd);
	sql-dump;
	ftp-upload;
	ftp-check;
}
main "$@"
