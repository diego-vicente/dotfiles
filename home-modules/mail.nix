{ config, lib, pkgs, emacsPkg ? pkgs.emacs, ... }:

# GOTCHA: first time around, you should run this commands after activating the
# module:
#  $ mu init --maildir=~/docs/maildir --my-address=mail@diego.codes
#  $ mbsync -a

{
  # These three packages are the ones in charge of fetching and indexing all the
  # mail from in my machine
  home.packages = with pkgs; [
    isync
    msmtp
    mu
  ];

  accounts.email.maildirBasePath = "docs/maildir";
  accounts.email.accounts.personal = {
    # Identity settings
    realName = "Diego Vicente";
    address = "mail@diego.codes";
    gpg = {
      key = "05655462B962E44888EAA98627A4876C982E4518";
      signByDefault = true;
    };
    # Configure the server connection details
    primary = true;
    userName = "mail@diego.codes";
    passwordCommand = "${pkgs.gnupg}/bin/gpg --decrypt ${../passwords/mail.asc} 2> /dev/null";
    imap = {
      host = "imap.migadu.com";
      port = 993;
    };
    smtp = {
      host = "smtp.migadu.com";
      port = 465;
    };
    # Enable the different services to take care of the mail
    mbsync = {
      enable = true;
      create = "maildir";
    };
    msmtp.enable = true;
  };

  programs.mbsync.enable = true;

  systemd.user = {
    # Define a new service to fetch the mail using systemd
    services = {
      mailsync = {
        Unit = {
          Description = "Mail synchronization";
          Documentation = [ "man:mbsync(1)" "man:mu(1)" "man:emacsclient(1)" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = ''${emacsPkg}/bin/emacsclient --eval "(mu4e-update-mail-and-index t)"'';
        };
        Install = {
          Path = [ "${pkgs.gnupg}/bin" ];
          After = [ "network-online.target" "gpg-agent.service" ];
          WantedBy = [ "default.target" ];
        };
      };
    };
    # Invoke the service once every 2 minutes
    timers = {
      mailsync = {
        Unit = {
          Description = "Periodical mail syncronization";
          Documentation = [ "man:mbsync(1)" "man:mu(1)" "man:emacsclient(1)" ];
        };
        Timer = {
          OnCalendar = "*:0/2";
          Persistent = true;
        };
        Install = {
          WantedBy = [ "timers.target" ];
        };
      };
    };
  };
}
