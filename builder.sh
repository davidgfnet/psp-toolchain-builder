#!/usr/bin/env bash
set -eo pipefail

PKGBLACKLIST=(
  "lua51" "lua52" "lua53" "luasocket"      # Only Lua54 is built
  "tremor"                                 # TODO: Fix packages with issues
)

# Modes: download-sources, build
if [ $# -lt 1 ]; then
  echo "Usage:"
  echo "  $0 download-sources [--force]"
  echo "  $0 build [package-name]"
  exit 1
fi

MODE=$1
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PKGDIR=$ROOT/packages
SRCDIR=$ROOT/sources

# helper: parse_pkgbuild
parse_pkgbuild(){
  unset prepare
  unset build
  unset package
  unset depends
  unset source
  unset sha256sums
  unset url
  unset license

  local file=$1 prefix=$2
  source "$file"
  eval "${prefix}pkgname=\$pkgname"
  eval "${prefix}pkgver=\$pkgver"
  eval "${prefix}pkgrel=\$pkgrel"
  eval "${prefix}depends=(\${depends[@]:-})"
  eval "${prefix}source=(\${source[@]:-})"
  eval "${prefix}sha256sums=(\${sha256sums[@]:-})"
  eval "${prefix}license=\${license:-}"  # optional
  eval "${prefix}url=\${url:-}"          # optional
}

if [[ "$MODE" == "download-sources" ]]; then
  mkdir -p "$SRCDIR"

  # detect force flag
  FORCE=false
  if [[ "${2:-}" == "--force" ]]; then
    FORCE=true
  fi

  for pb in `find "$PKGDIR" -name '*.pkgbuild' -type f`; do
    parse_pkgbuild "$pb" ""
    pkgsrcdir="$SRCDIR/$pkgname"
    mkdir -p "$pkgsrcdir"

    for i in "${!source[@]}"; do
      url="${source[$i]}"
      sum="${sha256sums[$i]}"

      if [[ "$url" == git+* ]]; then
        repo="${url#git+}"
        [[ "$repo" == *"#commit="* ]] && \
          { commit="${repo#*#commit=}"; repo="${repo%%#*}"; } || \
          commit="HEAD"
        srcname="$(basename "$repo" .git)"
        archive="$pkgsrcdir/${srcname}.tar.gz"

        # skip git if archive exists and not forced
        if [[ -f "$archive" && "$FORCE" != "true" ]]; then
          echo "==> [$pkgname] $srcname.tar.gz exists, skipping"
          continue
        fi

        tmpdir=$(mktemp -d)
        tgtdir="$tmpdir/$srcname"
        mkdir -p "$tgtdir"

        echo "==> [$pkgname] cloning $repo"
        git clone --recursive "$repo" "$tgtdir"
        echo "==> [$pkgname] checking out $commit"
        git -C "$tgtdir" fetch --all
        git -C "$tgtdir" checkout "$commit"

        echo "==> [$pkgname] staging git sources into ${srcname}.tar.gz"
        rm -rf "$tgtdir/.git"
        tar czf "$archive" -C "$tmpdir" .
        rm -rf "$tmpdir"

      elif [[ "$url" == http* ]]; then
        file="${url##*/}"
        dst="$pkgsrcdir/$file"

        if [[ -f "$dst" && "$FORCE" != "true" ]]; then
          echo "==> [$pkgname] verifying existing $file"
          if [[ "$sum" != "SKIP" ]] && echo "$sum  $dst" | sha256sum -c -; then
            echo "==> [$pkgname] checksum OK, skipping download"
          else
            echo "==> [$pkgname] checksum failed or SKIP, redownloading $file"
            curl -L "$url" -o "$dst"
          fi
        else
          echo "==> [$pkgname] downloading $file"
          curl -L "$url" -o "$dst"
        fi

        echo "==> [$pkgname] verifying $file"
        if [[ "$sum" != "SKIP" ]]; then
          echo "$sum  $dst" | sha256sum -c -
        else
          echo "--> SKIP checksum for $file"
        fi
      else
        file="${url##*/}"
        dirname=`dirname "$pb"`
        cp "$dirname/$url" "$pkgsrcdir/$file"

        echo "==> [$pkgname] verifying $file"
        if [[ "$sum" != "SKIP" ]]; then
          echo "$sum  $pkgsrcdir/$file" | sha256sum -c -
        else
          echo "--> SKIP checksum for $file"
        fi
      fi
    done
  done

  exit 0

elif [[ "$MODE" == "build" ]]; then
  : "${PSPDEV:?PSPDEV must be set}"
  case ":$PATH:" in *":$PSPDEV/bin:"*) ;; *) echo "PSPDEV/bin not in PATH" >&2; exit 1;; esac

  MANIFEST="$PSPDEV/manifest.yaml"

  CONTINUE=false
  if [[ "${2:-}" == "--continue" ]]; then
    CONTINUE=true
  else
    echo "packages:" > "$MANIFEST"
  fi

  # collect deps and topo-sort
  declare -A deps visited
  pkg_order=()
  for pb in `find "$PKGDIR" -name '*.pkgbuild' -type f`; do
    parse_pkgbuild "$pb" ""
    deps[$pkgname]="${depends[*]}"
  done
  visit(){
    local p=$1
    [[ ${visited[$p]:-0} -eq 1 ]] && return
    visited[$p]=1
    for d in ${deps[$p]}; do visit "$d"; done
    pkg_order+=("$p")
  }
  for p in "${!deps[@]}"; do visit "$p"; done

  # if continuing, figure out where to resume
  if [[ "$CONTINUE" == true ]]; then
    # grab last-built name from the existing manifest
    last=$(grep '^[[:space:]]*-[[:space:]]*name:' "$MANIFEST" \
           | tail -n1 | awk -F'"' '{print $2}')
    # find its index
    start=0
    for i in "${!pkg_order[@]}"; do
      [[ "${pkg_order[i]}" == "$last" ]] && { start=$((i+1)); break; }
    done
    targets=("${pkg_order[@]:start}")
  else
    targets=("${pkg_order[@]}")
  fi
  echo "Building packages in order: ${targets[*]}"

  for p in "${targets[@]}"; do
    # Check if item is in the PKGBLACKLIST
    for blocked in "${PKGBLACKLIST[@]}"; do
      if [[ "$p" == "$blocked" ]]; then
        echo "Skipping blacklisted package: $p"
        continue 2  # Skip this iteration of the outer loop
      fi
    done

    fp=`find "$PKGDIR" -name "$p.pkgbuild" -type f -print -quit`
    parse_pkgbuild "$fp" ""

    # extract archives into build directory
    builddir=$(mktemp -d)
    psrcdir="$SRCDIR/$pkgname"

    echo "==> start $pkgname build"
    export PSPDEV pkgdir="$PSPDEV"
    export MAKEFLAGS="-j$(getconf _NPROCESSORS_ONLN)"
    echo "[$pkgname] extracting sources"
    for f in `find "$psrcdir" -maxdepth 1 -type f`; do
      case "$f" in
        *.tar.gz|*.tgz)   tar xzf "$f" -C "$builddir" ;; 
        *.tar.bz2)        tar xjf "$f" -C "$builddir" ;; 
        *.tar.xz)         tar xJf "$f" -C "$builddir" ;; 
        *.zip)            unzip -q "$f" -d "$builddir" ;; 
        *)                cp -a "$f" "$builddir"/ ;; 
      esac
    done
    export srcdir="$builddir"
    # export CPPFLAGS CFLAGS CXXFLAGS LDFLAGS MAKEFLAGS CHOST
    echo "==> building $pkgname"
    type prepare &>/dev/null && (cd "$builddir" && prepare)
    type build   &>/dev/null && (cd "$builddir" && build)
    type package &>/dev/null && (cd "$builddir" && package)
    rm -rf "$builddir"

    {
      echo "  - name:     \"$pkgname\"" 
      echo "    pkgver:   \"$pkgver\""
      echo "    pkgrel:   \"$pkgrel\""
      [[ -n "$license" ]] && echo "    license:  \"$license\""
      [[ -n "$url"     ]] && echo "    url:      \"$url\""
      echo "    sources:"
      for i in "${!source[@]}"; do
        echo "      - url:    \"${source[$i]}\""
        echo "        sha256: \"${sha256sums[$i]}\""
      done
    } >> "$MANIFEST"
  done

  exit 0
else
  echo "Invalid command \"$MODE\""
  exit 1
fi

echo "Unknown mode: $MODE" >&2; exit 1
