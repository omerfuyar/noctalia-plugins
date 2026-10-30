# Noctalia Plugins

Plugins for [Noctalia](https://noctalia.dev) v5. I solved some problems for myself and want to share them with others.

## Install

The repository is itself a plugin source, add it as a plugin source with command:

```bash
noctalia msg plugins source add omerfuyar git https://github.com/omerfuyar/noctalia-plugins
```

Then enable plugins in Noctalia's settings, under Plugins.

## Uninstall

Disable each plugin you enabled, in Noctalia's settings under Plugins or with the command below, then remove the plugin source:

```bash
noctalia msg plugins disable omerfuyar/<plugin>
noctalia msg plugins source remove omerfuyar
```

A plugin keeps its data in `~/.local/state/noctalia/plugins/data/omerfuyar/<plugin>/`; delete that folder to remove it too.

Finished plugins are also offered to community-plugins, so people find them in Noctalia's plugin store by default

## Principles

- **User friendly.** A plugin works right after it is enabled. Its defaults make sense for majority.
- **Easy to configure.** Few settings, each with a clear label and a default. Rare settings are hidden as advanced. Leaving room for further configuration.
- **Little to no setup or upkeep.** Few dependencies. When a plugin really needs something the user must install or set up once, it says so itself and offers to do it, from a place that is easy to reach. Stated explicitly.
- **Better than the default.** A plugin adds what Noctalia lacks, or joins related controls that Noctalia keeps apart. It does not repeat or conflict what Noctalia already does well.
- **Native look.** A plugin looks and feels like the rest of Noctalia and follows the user's theme. It never depends on one machine: no fixed monitor names, paths or screen sizes.

## Plugins

See directories in repo for plugins, they have their own readme files inside.
