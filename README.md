# duplicity

FlipFlop=#

[Duplicity](https://duplicity.gitlab.io) backs directories by producing
[encrypted](https://gnupg.org) tar-format volumes and uploading them to a
remote or local file server. Because duplicity uses librsync, the incremental
archives are space efficient and only record the parts of files that have
changed since the last backup. Because duplicity uses GnuPG to encrypt and/or
sign these archives, they will be safe from spying and/or modification by the
server.

This container image provides a mechanism for consolidating container backups
to offsite [AWS S3 storage](https://aws.amazon.com/s3/).

Volume Mounts:

- Source: Raw storage of the backup source
- Container: Duplicity Cache
- Backup: Filtered backup source

## Configuration

- Encrypter Key Set
  - Private Key
  - Public Key
  - Fingerprint
- Signer Key Set
  - Private Key
  - Public Key
  - Finger Print
- BASE_S3_URI

## Working directory

`/var/backup`

## Destination directory

`/opt/backup` which should be mounted via nfs from
`nfs:///<ip>/nas/volumes/duplicity/<container>`

## Setup

### AWS Setup

Create an S3 Bucket to hold duplicity archives. Because bucket names must be
unique globally a FQDN like `duplicity.fqdn.tld`
should probably be used. Next create an IAM user for CLI access and make sure
the user has the permissions
`arn:aws:iam::aws:policy/AmazonS3FullAccess` either directly or through a user
group.

Check that credentials are available through credentials file or environment
variables - Check login using boto3. `aws_test.py`

### GPG

This duplicity container image is designed to push the backup files outside of
the local environment and therefore must be both encrypted and signed in order
to guarantee data security. Two password protected public-private key sets
must be generated using `gpg` in development (or independently) then provided
to the production environment.

**Encrypter** - This key set is used to encrypt the backup.  The container
will use the public key to encrypt the data which can only be unlocked using
the private key. The private key should be protected with a very strong
password which is stored separately from the container.

**Signer** - This is used to verify that the file was created with access to
the private key (which is obviously limited).  This does not guarantee data
integrity only that the backup files were generated using the signer private
key.

## Commands

References for common commands used to build and/or setup the container image.

### GPG

[GNU Privacy Guard](https://gnupg.org) is a complete and free implementation
of the OpenPGP standard as defined by RFC4880 (also known as PGP). GnuPG
allows you to encrypt and sign your data and communications; it features a
versatile key management system, along with access modules for all kinds of
public key directories. GnuPG, also known as GPG, is a command line tool with
features for easy integration with other applications. This tools is used for
the encryption of the duplicity volumes.

[GPG Documentation](https://www.gnupg.org/documentation/manuals/gnupg/GPG-Configuration-Options.html)

```sh
gpg --trusted-key $BACKUP_KEY --import /opt/duplicity/testkey.pkey
```

```sh
gpg  --import /opt/duplicity/testkey.pkey`
```

#### List keys

```sh
/usr/bin/gpg --list-keys
```

#### Key Generation

This will need to be run for both the **Encrypter** and **Signer** key sets.

```sh
/usr/bin/gpg --generate-key
```

Interactive Responses:

- **Real Name**: `Duplicity Backup Encrypter` or `Duplicity Backup Signer`
- **Email address**: `duplicity-backup-`**[encrypter|signer]**`@example.com`
- **Change (N)ame, (E)mail, or (O)kay/(Q)uit?**: `O`
- **Password**: (Paste from password manager)

Note the following:

- **Fingerprint**: 40 character hexidecimal code (add to password manager)
- **Expiration**: If you want unlimited expiration use `--full-generate-key`
(add to password manager)

#### Export Keys

All of the keys should be exported so that they may be deployed in production.
Two variables must be set:

- **Name**`-a "..."`: Should be set to `Duplicity Backup`[Encrypter|Signer]
- **File**: should be set to [encrypter|signer]`.[p]key`

```sh
/usr/bin/gpg --export-secret-key -a \
"Duplicity Backup Encrypter" > /mnt/volumes/container/encrypter.pkey
```

The exported files should be attached to the password credentials in a
password manager. Also note the private will require the password to be
provided in order to export.

#### Import Keys

For valid operation only the Encrypter Public Key `encrypter.key` is required.
The container will attempt to import this key automatically. Below are the
manual operations for import.

##### Import public key

```
/usr/bin/gpg --import /mnt/volumes/container/encrypter.key
```

```sh
--trusted-key $FINGERPRINT
```

For optional but recommended signing of backups you will need to import
`signer.key` and `signer.pkey`

##### Import private key

```
gpg --allow-secret-key-import --import /mnt/volumes/container/encrypter.key
```

```sh
--trusted-key $FINGERPRINT
```

```sh
gpg --trusted-key $(gpg --show-keys /opt/backup/decryption.key  | sed -n '2p' | xargs) --import /opt/backup/decryption.key
```

Note that to decrypt a backup the `encrypter.pkey` must be imported manually.

##### Trust the imported key

The above imports provide an unknown key to the gpg keychain. To make sure the
key is trusted set the fingerprint to trusted-key in the `~/.gnupg/gpg.conf`

```
/bin/echo "trusted-key $DUPLICITY_ENCRYPTER_FINGERPRINT" >> ~/.gnupg/gpg.conf
```

### duplicity

#### Backup

```sh
/usr/bin/duplicity --encrypt-key $ENCRYPT_KEY /mnt/volumes/configmaps file:///home/duplicity/backup
```

- `duplicity full --encrypt-key <id> --name daily --dry-run /var/backup file:///opt/backup/alpine`
- `duplicity full --encrypt-key <fingerprint>  --archive-dir /etc file:///opt/duplicity`
- `duplicity full --encrypt-key <key-id> /var/backup file:///opt/backup`

## Restore

```
duplicity restore --archive-dir /tmp/backup file:///opt/backup /var/backup
```

## References

Common reference for information required for duplicity operation.

### Time Formats

duplicity uses time strings in two places. Firstly, many of the files
duplicity creates will have the time in their filenames in the w3 datetime
format as described in a w3 [note](http://www.w3.org/TR/NOTE-datetime).
Basically they look like "2001-07-15T04:09:38-07:00", which means what it
looks like. The "-07:00" section means the time zone is 7 hours behind UTC.
Secondly, the -t, --time, and --restore-time options take a time string,
which can be given in any of several formats:

1. the string `now` (refers to the current time)
2. a sequences of digits, like `123456890` (indicating the time in seconds
after the epoch)
3. A string like `2002-01-25T07:00:00+02:00` in datetime format
4. An interval, which is a number followed by one of the characters s, m, h,
D, W, M, or Y (indicating seconds, minutes, hours, days, weeks, months, or
years respectively), or a series of such pairs. In this case the string refers
to the time that preceded the current time by the length of the interval. For
instance, "1h78m" indicates the time that was one hour and 78 minutes ago. The
calendar here is unsophisticated: a month is always 30 days, a year is always
365 days, and a day is always 86400 seconds.
5. A date format of the form YYYY/MM/DD, YYYY-MM-DD, MM/DD/YYYY, or
MM-DD-YYYY, which indicates midnight on the day in question, relative to the
current time zone settings. For instance, "2002/3/5", "03-05-2002", and
"2002-3-05" all mean March 5th, 2002.

## Notes

- This container originally was going to be implemented using
[Duplicati](https://www.duplicati.com) that idea was dropped due to the
difficulty in implementing mono from source.
- 2024-04-12: Adding Links
  - [Manual page](https://linux.die.net/man/1/duplicity)
  - [GPG Cheat Sheet](https://gock.net/blog/2020/gpg-cheat-sheet)
  - [Duplicity to Amazon S3 Backup](https://easyengine.io/tutorials/backups/duplicity-amazon-s3/)
