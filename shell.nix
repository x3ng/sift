{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    cargo
    rustc
    rust-analyzer
    rustfmt
    clippy
  ];

  shellHook = ''
    echo "sift dev environment (Rust $(rustc --version))"
  '';
}

# 国内镜像加速：
# nix-shell --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store"
# nix-shell --option substituters "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
