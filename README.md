# Using a custom image with toolbox

Toolbox supports creating a new container with a user supplied image, by passing the --image flag when creating a new container:

```zsh
toolbox create --image <image-name>:<tag>
```

Since toolbox builds on Podman and other OCI technologies, you can build a toolbox compatible image from a standard `Containerfile` (<https://containertoolbx.org/doc/>). This facilitates creating a custom environment without repetitive manual configuration.

## Creating your own Containerfile

Recently I’ve been using Fedora Toolbox a lot for development to have a reproducible development enviroment across my different systems. To make it easier to have the same container on multiple machines I’ve created my own Containerfile:

```docker
FROM registry.fedoraproject.org/fedora-toolbox:43

# Install extra packages
COPY extra-packages /
RUN dnf -y install $(<extra-packages)
RUN rm /extra-packages
```

It basically just uses the base image that’s used for toolbox by default and installs packages that are in the extra-packages file. Of course you can also add more things, e.g. building other packages from source and so on. The extra-packages has one extra package that should be installed per line, like this:

```zsh
zsh
zsh-autosuggestions
zsh-syntax-highlighting
openssh-server
```

We can build the image by having the following folder structure:

```zsh
$ ls
Containerfile extra-packages
```

## Building an image

### Local

To build an image (and assign it the name toolbox):

```zsh
podman build -t toolbox -f /path/to/Containerfile
```

Now pass this image to toolbox and create a new container (also named toolbox):

```zsh
toolbox create -i toolbox toolbox
```

## Helper script

To make things easier, a simple helper script placed alongside the Containerfile is useful for rebuilding locally:

```bash
#!/bin/bash

# Set desired name via CLI argument, but default to "toolbox"
name="${1:-toolbox}"

echo "Cleaning existing image and container(s) if any exist"
toolbox rmi "$name" --force &> /dev/null

cd $(dirname "${BASH_SOURCE[0]}")

echo "Building image"
podman build -t "$name" -f Containerfile

echo "Creating toolbox"
toolbox create -i "$name" "$name"
```

To build a clean image and create a toolbox container (named toolbox by default) ensure your build script is executable, then run:

```zsh
./build.sh
```

Or if you would like to specify a different name:

```zsh
./build.sh toolbox-custom-name
```

Now, if you would like to modify your custom toolbox, rather than making ad-hoc changes, simply modify your Containerfile and rebuild.

This is a simple but powerful method for keeping your environment fully reproducible. For example, when Fedora has a new release, simply increment the version tag in the `FROM` line of your Containerfile, rebuild, and you will have an up-to-date toolbox including all of your customizations.

Building locally is simple and convenient, but an interesting alternative is to build and publish your image to a container registry using a CI/CD pipeline like GitHub Actions.

And voilà, you can enter the new toolbox with `toolbox enter $name`! :)

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

- <https://www.cogitri.dev/posts/12-fedora-toolbox/>
- <https://williamvandervalk.com/posts/custom-toolbox-image/#local>
