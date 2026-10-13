#!/bin/sh
set -eu

engine=${1:-}
out=${2:-strata-sm75-ubuntu-cuda13-offline}
if [ -z "$engine" ] || [ ! -f "$engine" ]; then
  echo "用法: $0 <Actions下载的strata文件> [输出目录]" >&2
  exit 2
fi
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$out/engine" "$out/config" "$out/data"
cp "$engine" "$out/engine/strata"
chmod 755 "$out/engine/strata"
cp "$repo/config/strata-single-2080ti-22g.example.json" "$out/config/strata-single-2080ti-22g.json"
cp "$repo/data/expert-profile.bin" "$out/data/expert-profile.bin"
cat > "$out/run-strata.sh" <<'EOF'
#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exe="$root/engine/strata"
export STRATA_BF16_TC=1
export STRATA_SELECT_SIMT=1
if [ ! -x "$exe" ]; then
  echo "错误: $exe 不可执行，请运行 chmod +x $exe" >&2
  exit 126
fi
cd "$root"
exec "$exe" \
  --pack ../Strata-data/packs/swift-iq3_xxs \
  --native ../Strata-data/models/swift-IQ3_XXS/Swift-Qwen3.8-Flash-Next-GSQ-RCO-IQ3_XXS-00001-of-00002.gguf \
  --ple-gguf ../Strata-data/models/swift-IQ3_XXS/Swift-Qwen3.8-Flash-Next-GSQ-RCO-IQ3_XXS-00001-of-00002.gguf \
  --expert-profile "$root/data/expert-profile.bin" \
  --expert-cache auto --prefill auto --spec 4 --mtp ../Strata-data/mtp/rt \
  --max-context 262144 --kv int8 --resident-experts --vram-reserve-mib 700 \
  --ple-row-cache 8388608 --ple-inflight 1024 --conversation-cache-mib 13312 \
  --conversation-cache-slots 4 --spec-min-p 0.70 --aux-cpus auto "$@"
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
