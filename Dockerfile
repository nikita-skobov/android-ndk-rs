FROM rust:stretch

# we want to use rust:stretch
# even though its pretty old at this point
# because openjdk-8-jre does not exist in the latest rust
# docker image. we can just update rust below, and i dont
# think rust has any issues with java so it shouldnt matter


RUN apt-get update
RUN apt-get install -yq openjdk-8-jre unzip wget cmake

RUN rustup toolchain install 1.50.0
RUN rustup default 1.50.0

RUN rustup target add armv7-linux-androideabi
RUN rustup target add aarch64-linux-android
RUN rustup target add i686-linux-android
RUN rustup target add x86_64-linux-android

# TODO: get latest versions of these?
# Install Android SDK
ENV ANDROID_HOME /opt/android-sdk-linux
RUN mkdir ${ANDROID_HOME} && \
    cd ${ANDROID_HOME} && \
    wget -q https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip && \
    unzip -q sdk-tools-linux-4333796.zip && \
    rm sdk-tools-linux-4333796.zip && \
    chown -R root:root /opt
RUN yes | ${ANDROID_HOME}/tools/bin/sdkmanager "platform-tools" | grep -v = || true
RUN yes | ${ANDROID_HOME}/tools/bin/sdkmanager "platforms;android-29" | grep -v = || true
RUN yes | ${ANDROID_HOME}/tools/bin/sdkmanager "build-tools;29.0.0"  | grep -v = || true
RUN ${ANDROID_HOME}/tools/bin/sdkmanager --update | grep -v = || true

# Install Android NDK
RUN cd /usr/local && \
    wget -q http://dl.google.com/android/repository/android-ndk-r20-linux-x86_64.zip && \
    unzip -q android-ndk-r20-linux-x86_64.zip && \
    rm android-ndk-r20-linux-x86_64.zip
ENV NDK_HOME /usr/local/android-ndk-r20

# Copy contents to container. Should only use this on a clean directory
COPY . /root/cargo-apk

# Install binary
RUN cargo install --path /root/cargo-apk/cargo-apk

# Remove source and build files
RUN rm -rf /root/cargo-apk

# Make directory for user code
RUN mkdir /root/src
WORKDIR /root/src