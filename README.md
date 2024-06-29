<div align="center">
    <h1 align="center">hevi</h1>
    <h3>a hex viewer</h3>
</div>

![ci status](https://github.com/Arnau478/hevi/actions/workflows/ci.yml/badge.svg)

![example image](web/example.png)

## What is hevi?
Hevi is a hex viewer, just like `xxd` or `hexdump`.

## But it's missing X...
Hevi is under development. But if you think it's missing any feature, please open an issue. I will address it as soon as possible.

## Usage
The command should be used as `hevi <file> [flags]`. The flags are described [below](#flags).

### Flags
| Flag(s)                          | Description                                             |
| -------------------------------- | ------------------------------------------------------- |
| `-h`/`--help`                    | Show a help message                                     |
| `-v`/`--version`                 | Show version information                                |
| `--color`/`--no-color`           | Enable or disable colored output                        |
| `--lowercase`/`--uppercase`      | Toggle between lowercase and uppercase hex              |
| `--size`/`--no-size`             | Enable or disable the line showing the size at the end  |
| `--offset`/`--no-offset`         | Enable or disable showing the offset                    |
| `--ascii`/`--no-ascii`           | Enable or disable ASCII interpretation                  |
| `--skip-lines`/`--no-skip-lines` | Enable or disable skipping of identical lines           |
| `--raw`                          | Raw format (disables most features)                     |
| `--show-palette`                 | Show the current color palette in a table               |
| `--parser`                       | Specify the parser to use. For a list use `hevi --help` |

### Environment variables
The `NO_COLOR` variable is supported, and disables color (see <https://no-color.org/>) printing. Note that it can be overwritten by an explicit `--color`.

### Config file
You can create a config file and specify the default values for the flags. It follows the `.json` syntax. Example:
```json
{
    "color": true,
    "uppercase": true,
    "show_size": false,
    "show_offset": true,
    "show_ascii": false,
    "skip_lines": true,
    "parser": "data",
    "palette": {
        "normal": { "base": "yellow", "dim": false },
        "normal_alt": { "base": "yellow", "dim": true },
        "c1": { "base": "red", "dim": false },
        "c1_alt": { "base": "red", "dim": true },
        "c2": { "base": "green", "dim": false },
        "c2_alt": { "base": "green", "dim": true },
        "c3": { "base": "blue", "dim": false },
        "c3_alt": { "base": "blue", "dim": true },
        "c4": { "base": "magenta", "dim": false },
        "c4_alt": { "base": "magenta", "dim": true },
        "c5": { "base": "cyan", "dim": false },
        "c5_alt": { "base": "cyan", "dim": true }
    }
}
```
**Note**: for the `palette` field you must specify all palettes!

The config file is located at:
| OS                                     | Path                                                                                             |
| -------------------------------------- | ------------------------------------------------------------------------------------------------ |
| Linux, MacOS, FreeBSD, OpenBSD, NetBSD | `$XDG_CONFIG_HOME/hevi/config.json` or if the env doesn't exist `$HOME/.config/hevi/config.json` |
| Windows                                | `%APPDATA%/hevi/config.json`                                                                     |
| Other                                  | Not supported. No config file will be read                                                       |

**Note**: hevi has a precedence for configuration and is:
1. Flags
2. Environment variables
3. Config file
4. Defaults

## About
It is written in [zig](https://github.com/ziglang/zig), in an attempt to simplify hex viewers.

## Installation
### AUR
If you're using Arch Linux, you can install it from the AUR (`hevi-bin`).
### Other platforms
You can download a binary from the [releases](https://github.com/Arnau478/hevi/releases/) page. You can also clone the repository and compile it with `zig build` (using a `zig` master build).

## Contribute
Contributions are welcome! Even if you don't want to write code, you can help a lot creating new issues or testing this software.

## License
See [LICENSE](LICENSE)

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
