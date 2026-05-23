{ pkgs ? import <nixpkgs> { config = { allowUnfree = true; android_sdk.accept_license = true; }; } }:

let
  androidSdk = pkgs.androidenv.composeAndroidPackages {
    platformVersions = [ "34" ];
    abiVersions = [ "x86_64" "arm64-v8a" ];
    includeNDK = true;
    includeEmulator = false;
  };
  androidHome = "${androidSdk.androidsdk}/libexec/android-sdk";
in

pkgs.mkShell {
  buildInputs = with pkgs; [
    cargo
    rustc
    rust-analyzer
    rustfmt
    clippy
    flutter
    jdk17
    gradle
    android-tools
    androidSdk.platform-tools
  ];

  shellHook = ''
    export ANDROID_HOME="${androidHome}"
    export ANDROID_SDK_ROOT="${androidHome}"
    export ANDROID_NDK_HOME="${androidHome}/ndk-bundle"
    export JAVA_HOME="${pkgs.jdk17}"
    export GRADLE_OPTS="-Dorg.gradle.jvmargs=-Xmx2g"

    echo "sift dev environment"
    echo "  Rust:  $(rustc --version)"
    echo "  Java:  $(java -version 2>&1 | head -1)"
    echo "  SDK:   $ANDROID_HOME"
  '';
}

# 国内 nix 镜像：
# nix-shell --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store"
# cargo/flutter 走代理：
# http_proxy=http://127.0.0.1:7897 https_proxy=http://127.0.0.1:7897 nix-shell --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store" shell.nix
