#!/usr/bin/python

import datetime
import hashlib
import json
import os

import boto3
from boto3.s3.transfer import TransferConfig
from botocore.exceptions import ClientError

# https://stackoverflow.com/questions/58921396/boto3-multipart-upload-and-md5-checking
# This function is a re-worked function taken from here: https://stackoverflow.com/questions/43794838/multipart-upload-to-s3-with-hash-verification
# Credits to user: https://stackoverflow.com/users/518169/hyperknot


class BackupConfig:
    DEFAULT_FILE = "/etc/duplicity/synchronize.json"
    DEFAULT_CHUNK = 8 * 1024 * 1024  # 8388608 - Defaults upload chunk size
    DEFAULT_RTIMEOUT = (
        60 * 14
    )  # 840 - 14 minutes RUN TIMEOUT - Synch is designed to run every 15 mins
    DEFAULT_LTIMEOUT = (
        60 * 60 * 48
    )  # 172800 - 48 hours - Backup should never have any files 2+ days old
    DEFAULT_STIMEOUT = 60 * 60 * 2  # 7200 2 hours - Backup should have run every hour
    DEFAULT_FOLDER = "/opt/backup"

    def __init__(
        self,
        file="/etc/duplicity/synchronize.json",
        id=None,
        secret=None,
        bucket=None,
        chunk=None,
        ltimeout=None,
        stimeout=None,
        rtimeout=None,
        folder=None,
    ):
        with open(file) as config:
            self.__config = json.load(config)
        self.__config_overload("id", id, None)
        self.__config_overload("secret", secret, None)
        self.__config_overload("bucket", bucket, None)
        self.__config_overload("chunk", chunk, BackupConfig.DEFAULT_CHUNK)
        self.__config_overload("ltimeout", ltimeout, BackupConfig.DEFAULT_LTIMEOUT)
        self.__config_overload("stimeout", stimeout, BackupConfig.DEFAULT_STIMEOUT)
        self.__config_overload("rtimeout", rtimeout, BackupConfig.DEFAULT_RTIMEOUT)
        self.__config_overload("folder", folder, BackupConfig.DEFAULT_FOLDER)

    def __config_overload(self, key, value, default):
        if value is not None:
            self.__config[key] = value
        elif key not in self.__config:
            self.__config[key] = default
        assert key in self.__config, f"Key({key}) must be in the config"
        assert self.__config[key] is not None, f"Value for key({key}) cannot be nil."
        # assert key in self.__config, "Key(%s) must be in the config" % key
        # assert self.__config[key] is not None, "Value for key(%s) cannot be nil." % key

    @property
    def id(self):
        return self.__config["id"]

    @property
    def secret(self):
        return self.__config["secret"]

    @property
    def bucket(self):
        return self.__config["bucket"]

    @property
    def chunk(self):
        return self.__config["chunk"]

    @property
    def ltimeout(self):
        return self.__config["ltimeout"]

    @property
    def stimeout(self):
        return self.__config["stimeout"]

    @property
    def rtimeout(self):
        return self.__config["rtimeout"]

    @property
    def folder(self):
        return self.__config["folder"]


class BackupSynchronize:
    def __init__(self, config):
        self.__config = config
        self.__client = boto3.client(
            "s3",
            aws_access_key_id=self.__config.id,
            aws_secret_access_key=self.__config.secret,
        )
        self.__transfer_config = TransferConfig(multipart_chunksize=self.__config.chunk)

    # keep a list of the caches that have a problem.
    def synchronize(self):
        backupstructs = self.__structure_backup()  # self.__config.folder)
        start = datetime.datetime.utcnow().timestamp()
        timestamp = datetime.datetime.utcnow().timestamp()
        timeout = False  # noqa: F841
        for backupstruct in backupstructs:
            folder = backupstruct["folder"]
            cache = os.path.basename(folder)
            recent = False  # noqa: F841
            last = 0
            for file in backupstruct["files"]:
                path = f"{folder}/{file}"
                # path = "%s/%s" % (folder, file)
                stats = os.stat(path)
                print(stats.st_mtime)
                if last < stats.st_mtime:
                    last = stats.st_mtime
                # self.__synchronize_file(self.__client, self.__config.bucket, cache, path)
                self.__synchronize_file(cache, path)
                timestamp = datetime.datetime.utcnow().timestamp()
                if timestamp - start >= self.__config.rtimeout:
                    run_timeout = True  # noqa: F841
                    break
            print((timestamp - last), self.__config.ltimeout, self.__config.stimeout)
            if timestamp - last >= self.__config.ltimeout:
                print(f"[ERROR]: long timeout hit for {cache}")
            elif timestamp - last >= self.__config.stimeout:
                print(f"[ WARN]: Short timeout hit for {cache}")
                # print("[ WARN]: Short timeout hit for %s" % cache)
            # if timesout - <= :
            #     print("[ERROR] Timeout, will need to complete the one-way synch on the next run")
            #    break

    def __file_checksum(self, file):
        chunk_md5s = []
        with open(file, "rb") as fp:
            while True:
                data = fp.read(self.__config.chunk)
                if not data:
                    break
                chunk_md5s.append(hashlib.md5(data))
        num_hashes = len(chunk_md5s)
        if not num_hashes:
            # do whatever you want to do here
            raise ValueError
        if num_hashes == 1:
            return f"{chunk_md5s[0].hexdigest()}"
        digest_byte_string = b"".join(m.digest() for m in chunk_md5s)
        digests_md5 = hashlib.md5(digest_byte_string)
        return f"{digests_md5.hexdigest()}-{num_hashes}"

    def __s3_checksum(self, resource):
        try:
            return self.__client.head_object(Bucket=self.__config.bucket, Key=resource)[
                "ETag"
            ][1:-1]
        except ClientError:
            # do whatever you want to do here
            return "00000000000000000000000000000000"
            # raise ClientError

    def __structure_backup(self):
        folder = self.__config.folder
        backupstructs = []
        for pathstruct in os.walk(folder):
            if len(backupstructs) >= 1:
                assert len(pathstruct[1]) == 0 and len(pathstruct[2]) > 1, (
                    "Path structure must be a directory with just files"
                )
                for filename in pathstruct[2]:
                    assert filename[-4:] == ".gpg", (
                        f"Filename({filename}) must have the .gpg extension"
                        # "Filename(%s) must have the .gpg extension" % filename
                    )
            backupstructs.append({"folder": pathstruct[0], "files": pathstruct[2]})
        return backupstructs[1:]

    def __synchronize_file(self, cache, path):
        assert path is not None, "File cannot be nil."
        assert os.path.exists(path), f"File({path}) must exist."
        # assert os.path.exists(path), "File(%s) must exist." % path
        week = datetime.datetime.utcnow().strftime("%U")
        resource = f"{week}/{cache}/{os.path.basename(path)}"
        # resource = "%s/%s/%s" % (week, cache, os.path.basename(path))
        s3_checksum = self.__s3_checksum(resource)
        file_checksum = self.__file_checksum(path)
        if s3_checksum != file_checksum:
            print(f"[SYNCING] {week} {path}")
            # print("[SYNCING] %s %s" % (week, path))
            self.__client.upload_file(
                path, self.__config.bucket, resource, Config=self.__transfer_config
            )
            s3_checksum = self.__s3_checksum(resource)
            assert s3_checksum == file_checksum, (
                f"Checksums must be equal(S3={s3_checksum}|File={file_checksum})"
                # "Checksums must be equal(S3=%s|File=%s)" % (s3_checksum, file_checksum)
            )
        else:
            print(f"[SYNCHED] {week} {path}")
            # print("[SYNCHED] %s %s" % (week, path))


class BackupArchive:
    pass


config = BackupConfig()
print(config.id)
sync = BackupSynchronize(config)
sync.synchronize()
