# Rover-Setup
Scripts for single command setup for rpi rover

## Setup SSH

First create an SSH key and print the public key:

```bash
ssh-keygen -t ed25519 -C "rover@$(hostname)" -f ~/.ssh/id_ed25519 -N "" && cat ~/.ssh/id_ed25519.pub
```

Then go to GitHub > Settings > SSH and GPG keys > New SSH key
and paste the ssh key to setup ssh access to the git repository

The install script also does this automatically for the `rover` user and prints the key before cloning.
