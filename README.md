# Custom base image for Fedora Toolbox

Recently I’ve been using Fedora Toolbox a lot for development to have a reproducible development enviroment across my different systems. To make it easier to have the same container on multiple machines I’ve created my own Dockerfile:

```docker
FROM registry.fedoraproject.org/fedora-toolbox:43

# Install extra packages
COPY extra-packages /
RUN dnf -y install $(<extra-packages)
RUN rm /extra-packages
```

It basically just uses the base image that’s used for toolbox by default and installs packages that are in the extra-packages file. Of course you can also add more things, e.g. building other packages from source and so on. The extra-packages has one extra package that should be installed per line, like this:

```zsh
clang
fish
openssh-server
```

We can build the image by having the following folder structure:

```zsh
$ ls
Dockerfile extra-packages
```

And issuing the following podman command:

```zsh
podman build . -t $USER/fedora-toolbox:latest
```

Afterwards the toolbox with the custom image can be created with:

```zsh
toolbox create -c fedora-toolbox-43 -i $USER/fedora-toolbox
```

And voilà, you can enter the new toolbox with toolbox enter! :)

## Hooking it up with VSCode

Since I’m using the VSCode flatpak I have to use the VSCode Remote extension to access my Toolbox container. To do that we have to install a SSH server into our container. You can do that by adding openssh-server to your extra-packages. Afterwards, you can configure the server by adding the following lines to our Dockerfile:

```zsh
RUN printf "Port 2222\nListenAddress localhost\nPermitEmptyPasswords yes\n" >> /etc/ssh/sshd_config \
 && /usr/libexec/openssh/sshd-keygen rsa \
 && /usr/libexec/openssh/sshd-keygen ecdsa \
 && /usr/libexec/openssh/sshd-keygen ed25519
```

We can start the SSH server on login by adding the following systemd service file to `$HOME/.config/systemd/user/toolbox_ssh.service`:

```zsh
[Unit]
Description=Launch sshd in Fedora Toolbox

[Service]
Type=longrun
ExecPre=/usr/bin/podman start fedora-toolbox-34
ExecStart=/usr/bin/toolbox run sudo /usr/sbin/sshd -D

[Install]
WantedBy=default.target
```

Afterwards we can enable & start the service with:

```zsh
systemctl --user daemon-reload
systemctl --user enable --now toolbox_sshd
```

We should also add an entry to our SSH client config to make SSH’ing in the container easier:

```zsh
Host toolbox
 HostName localhost
 Port 2222
 StrictHostKeyChecking no
 UserKnownHostsFile=/dev/null
```

We have to disable `StrictHostKeyChecking` and `UserKnownHostsFile` since the host key of the container will change every time we regenerate the container.

Afterwards we can SSH into our container by installing the `Remote - SSH` extension in VSCode.

## Launching X11/D-Bus Applications in VSCode

By default, you won’t be able to launch X11 or D-Bus applications in VSCode’s integrated terminal when using the “Remote - SSH” extension. To fix this, you have to set the `DISPLAY` and `DBUS_SESSION_BUS_ADDRESS`. The easiest way to set these to the right values is to enter your toolbox via your normal terminal (as in not via SSH) and doing echo `$DISPLAY` and echo `$DBUS_SESSION_BUS_ADDRESS`. Afterwards add these values to your launch.json, for my project it looks like this:

```c
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "(lldb) Launch",
            "type": "lldb", // if you're not using the CodeLLDB extension for debugging but instead the C/C++ one, change this to cppdbg
            "request": "launch",
            "program": "${workspaceRoot}/build/src/dev.Cogitri.Health.Devel", // Change this to the path of your exe
            "args": [],
            "cwd": "${workspaceFolder}",
            "env": {
                "DISPLAY": ":0",
                "DBUS_SESSION_BUS_ADDRESS": "unix:path=/run/user/1000/bus"
            }
        }
    ]
}
```

Afterwards launching applications via your debugger should just work.

## Resource

<https://www.cogitri.dev/posts/12-fedora-toolbox/>
