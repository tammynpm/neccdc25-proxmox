import yaml

# Team range
start_team = 0
end_team = 10

inventory = {
    "ctrl_plane": {
        "hosts": {
            f"10.0.{team}.250": {
                "team": team
            }
            for team in range(start_team, end_team + 1)
        },
        "vars": {
            "hostname": "ctrl-plane"
        }
    },
    "database": {
        "hosts": {
            f"10.0.{team}.196": {
                "team": team
            }
            for team in range(start_team, end_team + 1)
        },
        "vars": {
            "hostname": "database"
        }
    },
    "firewall": {
        "hosts": {
            f"10.255.{team}.254": {
                "team": team
            }
            for team in range(start_team, end_team + 1)
        },
        "vars": {
            "hostname": "firewall"
        }
    },
    "graylog": {
        "hosts": {
            f"10.0.{team}.169": {
                "team": team
            }
            for team in range(start_team, end_team + 1)
        },
        "vars": {
            "hostname": "graylog"
        }
    },
    "teleport": {
        "hosts": {
            f"10.0.{team}.180": {
                "team": team
            }
            for team in range(start_team, end_team + 1)
        },
        "vars": {
            "hostname": "teleport"
        }
    },
    "node_0": {
        "hosts": {
            f"10.0.{team}.200": {
                "team": team
            }
            for team in range(start_team, end_team + 1)
        },
        "vars": {
            "hostname": "node-0"
        }
    },
    "node_1": {
        "hosts": {
            f"10.0.{team}.211": {
                "team": team
            }
            for team in range(start_team, end_team + 1)
        },
        "vars": {
            "hostname": "node-1"
        }
    },
    "node_2": {
        "hosts": {
            f"10.0.{team}.222": {
                "team": team
            }
            for team in range(start_team, end_team + 1)
        },
        "vars": {
            "hostname": "node-2"
        }
    },
    "windows_ca": {
        "hosts": {
            f"10.0.{team}.32": {
                "team": team
            }
            for team in range(start_team, end_team + 1)
        },
        "vars": {
            "hostname": "ca-01"
        }
    },
    "windows_dc": {
        "hosts": {
            f"10.0.{team}.4": {
                "team": team
            }
            for team in range(start_team, end_team + 1)
        },
        "vars": {
            "hostname": "dc-01"
        }
    },
    "windows_dc_2": {
        "hosts": {
            f"10.0.{team}.120": {
                "team": team
            }
            for team in range(start_team, end_team + 1)
        },
        "vars": {
            "hostname": "dc-02"
        }
    },
    "windows_workstation": {
        "hosts": {
            f"10.0.{team}.67": {
                "team": team
            }
            for team in range(start_team, end_team + 1)
        },
        "vars": {
            "hostname": "win-01"
        }
    },
    "windows_workstation_2": {
        "hosts": {
            f"10.0.{team}.76": {
                "team": team
            }
            for team in range(start_team, end_team + 1)
        },
        "vars": {
            "hostname": "win-02"
        }
    }
}

with open('0-inventory.yaml', 'w') as file:
    yaml.dump(inventory, file, default_flow_style=False)
