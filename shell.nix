{ pkgs ? import <nixpkgs> { config = { allowUnfree = true; android_sdk.accept_license = true; }; } }:

let
  androidSdk = pkgs.androidenv.composeAndroidPackages {
    platformVersions = [ "35" ];
    buildToolsVersions = [ "34.0.0" ];
    ndkVersions = [ "28.1.13356709" ];
    cmdLineToolsVersion = "11.0";
    cmakeVersions = [ "3.22.1" ];
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
    # Create writable SDK overlay (nix store is read-only, Gradle needs writable SDK dir)
    SDK_OVERLAY="$HOME/.cache/sift-android-sdk"
    NIX_SDK="${androidHome}"
    BUILD_TOOLS="34.0.0"

    mkdir -p "$SDK_OVERLAY"/{platforms,build-tools,platform-tools,ndk,licenses,cmake,cmdline-tools}

    # Symlink nix-provided components into writable overlay
    [ -d "$NIX_SDK/platforms" ] && ln -sfn "$NIX_SDK/platforms"/* "$SDK_OVERLAY/platforms/" 2>/dev/null
    [ -d "$NIX_SDK/build-tools" ] && ln -sfn "$NIX_SDK/build-tools"/* "$SDK_OVERLAY/build-tools/" 2>/dev/null
    [ -d "$NIX_SDK/platform-tools" ] && ln -sfn "$NIX_SDK/platform-tools"/* "$SDK_OVERLAY/platform-tools/" 2>/dev/null
    [ -d "$NIX_SDK/licenses" ] && cp -rn "$NIX_SDK/licenses"/* "$SDK_OVERLAY/licenses/" 2>/dev/null
    # Flutter expects cmdline-tools/latest, nix puts it in cmdline-tools/<version>
    for ctdir in "$NIX_SDK/cmdline-tools"/*; do
      [ -d "$ctdir" ] && ln -sfn "$ctdir" "$SDK_OVERLAY/cmdline-tools/$(basename "$ctdir")" 2>/dev/null
      [ -d "$ctdir" ] && ln -sfn "$ctdir" "$SDK_OVERLAY/cmdline-tools/latest" 2>/dev/null
      break
    done

    # NDK: try ndk/ dir first (from ndkVersions), then ndk-bundle/ (from includeNDK)
    for ndk_dir in "$NIX_SDK"/ndk/* "$NIX_SDK"/ndk-bundle/*; do
      [ -d "$ndk_dir" ] && ln -sfn "$ndk_dir" "$SDK_OVERLAY/ndk/$(basename "$ndk_dir")" 2>/dev/null
    done
    # CMake
    for cmake_dir in "$NIX_SDK"/cmake/*; do
      [ -d "$cmake_dir" ] && ln -sfn "$cmake_dir" "$SDK_OVERLAY/cmake/$(basename "$cmake_dir")" 2>/dev/null
    done

    export ANDROID_HOME="$SDK_OVERLAY"
    export ANDROID_SDK_ROOT="$SDK_OVERLAY"
    export ANDROID_NDK_HOME="$SDK_OVERLAY/ndk/$(ls "$SDK_OVERLAY/ndk/" 2>/dev/null | head -1)"
    export JAVA_HOME="${pkgs.jdk17}"
    export GRADLE_OPTS="-Dorg.gradle.jvmargs=-Xmx2g -Dorg.gradle.project.android.aapt2FromMavenOverride=$NIX_SDK/build-tools/$BUILD_TOOLS/aapt2"
    # If http_proxy is set, write gradle.properties so Gradle daemon uses proxy
    if [ -n "$http_proxy" ]; then
      _hp=$(echo "$http_proxy" | sed 's|https*://||;s|/.*$||')
      _h=$(echo "$_hp" | cut -d: -f1)
      _p=$(echo "$_hp" | cut -d: -f2)
      mkdir -p "$HOME/.gradle"
      cat > "$HOME/.gradle/gradle.properties" << EOF
systemProp.http.proxyHost=$_h
systemProp.http.proxyPort=$_p
systemProp.https.proxyHost=$_h
systemProp.https.proxyPort=$_p
EOF
    fi

    echo "sift dev environment"
    echo "  Rust:  $(rustc --version)"
    echo "  Java:  $(java -version 2>&1 | head -1)"
    echo "  SDK:   $NIX_SDK (overlay: $SDK_OVERLAY)"
  '';
}

# 国内 nix 镜像：
# nix-shell --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store"
# cargo/flutter 走代理：
# http_proxy=http://127.0.0.1:7897 https_proxy=http://127.0.0.1:7897 nix-shell --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store" shell.nix
