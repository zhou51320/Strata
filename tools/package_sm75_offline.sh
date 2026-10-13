#!/bin/sh
set -eu

engine=${1:-}
out=${2:-strata-sm75-ubuntu-cuda13-offline}
if [ -z "$engine" ] || [ ! -f "$engine" ]; then
  echo "用法: $0 <Actions下载的strata文件> [输出目录]" >&2
  exit 2
fi
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$out/engine" "$out/config" "$out/data" "$out/lib"
cp "$engine" "$out/engine/strata"
chmod 755 "$out/engine/strata"
cp "$repo/config/strata-single-2080ti-22g.example.json" "$out/config/strata-single-2080ti-22g.json"
cp "$repo/data/expert-profile.bin" "$out/data/expert-profile.bin"
for libdir in /usr/local/cuda-13.0/lib64 /usr/local/cuda/lib64; do
  if [ -d "$libdir" ]; then
    for name in libcudart.so.13* libcublas.so.13* libcublasLt.so.13*; do
      for lib in "$libdir"/$name; do
        [ -f "$lib" ] && cp -L "$lib" "$out/lib/"
      done
    done
    break
  fi
done
cat > "$out/run-strata.sh" <<'EOF'
#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exe="$root/engine/strata"
export STRATA_BF16_TC=1
export STRATA_SELECT_SIMT=1
if [ -d "$root/lib" ]; then
  export LD_LIBRARY_PATH="$root/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi
if [ ! -x "$exe" ]; then
  echo "错误: $exe 不可执行，请运行 chmod +x $exe" >&2
  exit 126
fi
cd "$root"
exec python3 -m serve.server --engine strata \
  --config "$root/config/strata-single-2080ti-22g.json" "$@"
EOF
chmod 755 "$out/run-strata.sh"
cat > "$out/README.txt" <<'EOF'
Strata RTX 2080 Ti single-card bundle

Strata-data must be next to this directory:
  ../Strata-data/models/
  ../Strata-data/packs/swift-iq3_xxs/
  ../Strata-data/mtp/rt/

Run: ./run-strata.sh
EOF
echo "已生成: $out"
