{ config, lib, pkgs, hostSpecific, ... }:

{
  # There is some manual requirements to perform before activating this module.
  # The full steps can be found in [1] but the short summary is:
  #
  #   $ sudo su -
  #   # mkdir /root/borgbackup
  #   # cd borgbackup
  #   # ssh-keygen -f ssh_key -t ed25519 -C "Borg Backup"
  #   # nano passcode  # create a new passcode and store it in the password manager
  #   # ssh -i ./ssh_key XXXXXXXX@XXXXXXXX.repo.borgbase.com
  #
  # Remember to upload the key to the repository in BorgBase and grant full
  # access to it.
  #
  # [1]: https://christine.website/blog/borg-backup-2021-01-09
  services.borgbackup.jobs."borgbase" = {
    paths = hostSpecific.backup.paths;
    exclude = hostSpecific.backup.exclude;
    repo = hostSpecific.backup.borgbaseRepo;
    encryption = {
      mode = "repokey-blake2";
      passCommand = "cat /root/borgbackup/passcode";
    };
    environment.BORG_RSH = "ssh -i /root/borgbackup/ssh_key";
    compression = "auto,lzma";
    startAt = hostSpecific.backup.schedule;
  };
}
