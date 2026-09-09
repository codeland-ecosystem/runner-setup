# runner-setup

Setup scripts for CodeLand runners.

## Host setup (fresh Debian 13)

Prepares a host machine to run CodeLand LXC runners: installs LXC, creates the
`virt` user, installs the ephemeral helper scripts, installs the OpenResty
reverse proxy, and builds the `crunner0` base container with all language
runtimes.

```bash
sudo MANAGER_PUBKEY="$(cat ~/.ssh/id_rsa_cl-worker.pub)" bash host-setup.sh
```

The runner host scripts live in `host-scripts/` and are installed by the setup
script:

- `lxc-start-ephemeral` / `lxc-destroy-ephemeral` — create/tear down overlay
  runners (installed to `~/.local/bin`)
- `lxc-start-persistent` / `lxc-stop-persistent` — create/stop persistent
  runners whose writable layer lives on shared NFS
- `lxc-start` / `lxc-copy` / `lxc-attach` — cgroup v2 systemd-run wrappers
- `lxc-mount-hack` / `lxc-mount-persistent` / `lxc-hack-destroy` /
  `lxc-hack-chown` — privileged helpers (installed to `/usr/local/bin`)
- `clean_crunners.sh` — zombie runner cleanup
- `nginx.conf` — OpenResty reverse proxy that routes `port_container` host
  headers to the runner's crunner API

## Persistent runners (NFS)

Persistent runners keep their writable layer on a shared NFS export so they can
move between workers. See [docs/nfs-setup.md](docs/nfs-setup.md) for how to set
up the NFS share. Set `NFS_SERVER` when running `host-setup.sh` to mount it
automatically.

## Base runner OS

Each runner is an **LXC container** cloned from the `crunner0` base template,
built from:

```
Debian GNU/Linux 13 (trixie), x86_64
```

Runners are **unprivileged** (userns, uid 165536/65536) and run the
`crunner` API server on port 1500 to execute submitted code. The OpenResty
proxy routes `port_container` host headers to each runner's crunner.

## Language installers

Each `installers/*.sh` installs a single language runtime inside a runner
container. The base container is built by concatenating/running these inside
`crunner0`. To build a custom installer for a runner:

```bash
cat {java,ruby,typescript,csharp}.sh > ~/installer.sh
```

### What's installed in the base container

The `crunner0` template ships with:

| Language | Installer | Notes |
|----------|-----------|-------|
| bash | `bash.sh` | present by default |
| C | `c.sh` | gcc |
| C++ | `c++.sh` | g++ |
| C# | `csharp.sh` | mono |
| EJS | `ejs.sh` | via npm |
| Fortran | `fortran.sh` | gfortran |
| Go | `go.sh` | |
| Groovy | `groovy.sh` | |
| Haskell | `haskell.sh` | ghc |
| JavaScript / Node | `javascript.sh` | node + npm + express/ejs/redis/axios |
| Java | `java.sh` | openjdk JRE |
| Kotlin | `kotin.sh` | |
| Lua | `lua.sh` | lua5.3 + luarocks |
| Markdown | `md.sh` | pandoc |
| Mustache | `mustache.sh` | ruby-mustache |
| Perl | `perl.sh` | |
| PHP | `php.sh` | php-cli |
| Python 3 | `python3.sh` | python3 + pip3 |
| R | `r.sh` | r-base / Rscript |
| Ruby | `ruby.sh` | |
| Rust | `rust.sh` | rustc |
| Scala | `scala.sh` | |
| Swift | `swift.sh` | |
| TypeScript | `typescript.sh` | via npm (ts-node) |
| crunner | `crunner.sh` | the code-execution API server on port 1500 |

### Not installed (not packaged for Debian 13 / external-repo only)

These installers exist but do **not** install successfully on Debian 13
(trixie), so their runtimes are **absent** from the base container:

| Language | Installer | Reason |
|----------|-----------|--------|
| Brainfuck | `bf.sh` | `lci`/`bf` not packaged for trixie |
| Clojure | `clojure.sh` | needs `leiningen` + openjdk-11 (not in trixie) |
| Dart | `dart.sh` | external Google repo (focal/ubuntu-targeted) |
| LOLCODE | `lolcode.sh` | `lci` not packaged for trixie |
| PowerShell | `powershell.sh` | Microsoft repo targets Ubuntu focal |
| Python 2 | `python2.sh` | EOL, removed from Debian |
| Solidity | `solidity.sh` | PPA targeted at Ubuntu |

Install these manually inside the container if needed, or add Debian 13
packages/repos when they become available.
