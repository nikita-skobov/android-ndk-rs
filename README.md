# Fork notes:

The following are notes from this fork of android-ndk-rs:

This was forked in order to use the latest android-ndk-rs project in miniquad for android. Previously, miniquad for android required an older fork of android-ndk-glue (now deprecated) and it successfully built on an older version of rust. This would cause conflicts with packages that required newer rust versions. This fork basically replicates the changes done by [not-fl3 here](https://github.com/rust-windowing/android-rs-glue/commit/cf76e53e96e4d08e25fd90d609ad2a9e94e732f6).

Also I added a dockerfile similarly to what he had in his fork.

To use this fork with miniquad you would do:

1. prepare docker image
```sh
# get the miniquad fork of android-ndk-rs
# and checkout the branch where the fork resides (miniglue)
git clone https://github.com/nikita-skobov/android-ndk-rs
cd android-ndk-rs
git fetch origin && git checkout miniglue

# create the docker image to be able to easily
# cross compile for android
docker build -t miniglue .
```
2. go to a different folder, and make your sample project. make sure to make it a `--lib` so the android-ndk-rs glue macro works correctly (maybe its possible it will work with --bin but im not sure)
```
cargo new --lib miniquadandroid && cd miniquadandroid
```

3. Add the following to the Cargo.toml:
```
[dependencies]
miniquad = { version = "*", features = ["log-impl"] }

[target.'cfg(target_os = "android")'.dependencies]
ndk = { git = "https://github.com/nikita-skobov/android-ndk-rs", branch = "miniglue" }
ndk-glue = { git = "https://github.com/nikita-skobov/android-ndk-rs", branch = "miniglue" }

[[example]]
name = "androidexample"
crate-type = ["cdylib"]
```
4. `mkdir examples && echo "" > examples/androidexample.rs`
5. edit the example file you just made and add some simple miniquad example like:
```
use miniquad::*;

#[cfg_attr(target_os = "android", ndk_glue::main())]
fn main() {
    realmain();
}


struct Stage;
impl EventHandler for Stage {
    fn update(&mut self, _ctx: &mut miniquad::Context) {}

    fn draw(&mut self, ctx: &mut miniquad::Context) {
        ctx.clear(Some((0., 1., 0., 1.)), None, None);
    }
}


pub fn realmain() {
    // test to make sure logging works on android:
    info!("EEEEEEEEEEE eee eeee");
    miniquad::start(miniquad::conf::Conf::default(), |ctx| miniquad::UserData::owning(Stage, ctx));
}
```
The important part here is the `cfg_attr` where we use the modified `ndk_glue::main` macro. This essentially generates some code that properly calls the correct android ndk, and sokol functions. when that auto-generated initialization is done, their code will call our main, which we use to call the `realmain`.
6. Compile by first going into your docker image:
```
docker run -it --rm -v $(pwd):/root/src -w /root/src miniglue
```
7. Once you're in the docker image, you can compile by doing:
```
cargo apk build --example androidexample
```
8. If successful, you should be able to see your .apk file in:
```
target/debug/apk/examples/androidpls.apk
```

Everything below is the original readme:


# Rust on Android

[![Rust](https://github.com/rust-windowing/android-ndk-rs/workflows/Rust/badge.svg)](https://github.com/rust-windowing/android-ndk-rs/actions) ![MIT license](https://img.shields.io/badge/License-MIT-green.svg) ![APACHE2 license](https://img.shields.io/badge/License-APACHE2-green.svg)

Libraries and tools for Rust programming on Android targets:

Name | Description | Badges
--- | --- | ---
`ndk-sys` | Raw FFI bindings to the NDK | [![crates.io](https://img.shields.io/crates/v/ndk-sys.svg)](https://crates.io/crates/ndk-sys) [![crates.io](https://docs.rs/ndk-sys/badge.svg)](https://docs.rs/ndk-sys)
`ndk` | Safe abstraction of the bindings | [![crates.io](https://img.shields.io/crates/v/ndk.svg)](https://crates.io/crates/ndk) [![crates.io](https://docs.rs/ndk/badge.svg)](https://docs.rs/ndk)
`ndk-glue`| Startup code | [![crates.io](https://img.shields.io/crates/v/ndk-glue.svg)](https://crates.io/crates/ndk-glue) [![crates.io](https://docs.rs/ndk-glue/badge.svg)](https://docs.rs/ndk-glue)
`ndk-build` | Everything for building apk's | [![crates.io](https://img.shields.io/crates/v/ndk-build.svg)](https://crates.io/crates/ndk-build) [![crates.io](https://docs.rs/ndk-build/badge.svg)](https://docs.rs/ndk-build)
`cargo-apk` | Build tool | [![crates.io](https://img.shields.io/crates/v/cargo-apk.svg)](https://crates.io/crates/cargo-apk) [![crates.io](https://docs.rs/cargo-apk/badge.svg)](https://docs.rs/cargo-apk)

See [`ndk-examples`](./ndk-examples) for examples using the NDK and the README files of the crates for more details.

## Hello world

Quick start for setting up a new project with support for Android. For communication with the Android framework in our native Rust application we require a `NativeActivity`. `ndk-glue` will do the necessary initialization when calling `main` but requires a few adjustments:

`Cargo.toml`
```toml
[lib]
crate-type = ["lib", "cdylib"]
```

Wraps `main` function using attribute macro `ndk::glue::main`:

`src/lib.rs`
```rust
#[cfg_attr(target_os = "android", ndk_glue::main(backtrace = "on"))]
pub fn main() {
    println!("hello world");
}
```

`src/main.rs`
```rust
fn main() {
    $crate::main();
}
```

Install `cargo apk` for building, running and debugging your application:
```sh
cargo install cargo-apk
```

We can now directly execute our `Hello World` application on a real connected device or an emulator:
```sh
cargo apk run
```

## Logging and stdout
Stdout is redirected to the android log api when using `ndk-glue`. Any logger that logs to
stdout, like `println!`, should therefore work.

Use can filter the output in logcat
```
adb logcat RustStdoutStderr:D *:S
```

### Android logger
Android logger can be setup using feature "logger" and attribute macro like so:

`src/lib.rs`
```rust
#[cfg_attr(target_os = "android", ndk_glue::main(logger(level = "debug", tag = "my-tag")))]
pub fn main() {
    log!("hello world");
}
```

## Overriding crate paths
The macro `ndk_glue::main` tries to determine crate names from current _Cargo.toml_.
In cases when it is not possible the default crate names will be used.
You can override this names with specific paths like so:
```rust
#[ndk_glue::main(
  ndk_glue = "path::to::ndk_glue",
  logger(android_logger = "path::to::android_logger",
         log = "path::to::log")
)]
fn main() {}
```

## JNI
Java Native Interface (JNI) allows executing Java code in a VM from native applications.
`ndk-examples` contains an `jni_audio` example which will print out all output audio devices in the log.

- [`jni`](https://crates.io/crates/jni), JNI bindings for Rust

## Winit and glutin
TODO shameless plug

## Flutter
TODO shameless plug
