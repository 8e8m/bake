#!/bin/sh
# source install

set -eo pipefail

cd "$(dirname "$(readlink -f $0)")"

TARGET="${TARGET:-/usr/local}"
INSTALL="bake"
BUILD=0

usage() {
    echo "compiles and installs Bake into /usr/local (or TARGET) in bin/"
    echo ""
    echo "--alternatives          Includes awake and shake into the build"
    echo "--target=DIRECTORY      Target directory like /usr or /usr/local"
    echo "--prebuilt              Program is prebuilt"
    echo ""
    exit 1
}

while [ ! -z $1 ]; do
    case $(echo "$1" | cut -d= -f1) in
        "--target")
            TARGET=$(echo "$1" | cut -d= -f2)
            ;;
        "--alternatives")
            INSTALL="bake shake awake"
            ;;
        "--help")
            usage
            ;;
        "--prebuilt")
            BUILD=1
            ;;
        *)
            echo "Unknown option: " $1
            usage
            ;;
    esac
    shift
done

if [ -z $BUILD ]; then
    ./awake bake.l
fi

if [ -z "$NOMAN" ]; then
    mkdir -p "$TARGET/share/man/man1"
    gzip -c bake.1 > "$TARGET/share/man/man1/bake.1.gz"
fi

mkdir -p "$TARGET/bin"
install -m 755 $INSTALL "$TARGET/bin"
