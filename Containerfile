FROM registry.fedoraproject.org/fedora-toolbox:43

# Install extra packages
COPY extra-packages /
RUN dnf -y install $(<extra-packages)
RUN rm /extra-packages
