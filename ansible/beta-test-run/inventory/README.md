## General Setup

Add this to your shell profile script (bashrc/zshrc) and update the path to match your setup

```bash
export ANSIBLE_CONFIG=$HOME/ccdc/neccdc-2025/ansible/regionals/inventory/ansible.cfg
```

### Usage
To view all of the hosts and variables

```bash
ansible-inventory --list
```


## Generating Inventory

The initial inventory is generated with a python script since theres some weird subnets and the builtin loop did not cover the use case easily.

For development set the `teams` to **0** this will only setup the black team environment. When actually deploying set it to the total number of blue teams.

```bash
# Requires yaml module
python3 inventory-generator.py
```
