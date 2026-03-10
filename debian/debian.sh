#!/bin/sh
cd "$(dirname "$(readlink -f "$0")")"
cd ../..
set -e
v=20260310
mv bake bake-0~$v || echo "this is normal after the first time"
rm -f bake_0~$v.orig.tar.xz
tar cJv \
  --exclude='.gitignore' --exclude='.git' --exclude=debian \
  -f bake_0~$v.orig.tar.xz bake-0~$v/
cd bake-0~$v
dpkg-buildpackage -us -uc
grep 'home' bake || \
  echo "if you see this message there are no references to home in the executable"
./bake -s2 bake.l
for i in bake bake-dbg ../*deb ../*xz; do gpg --yes -u emil@chud.cyou --detach-sign $i; done
rm -rf ../export-auto
mkdir -p ../export-auto/
cp bake bake.sig bake-dbg bake-dbg.sig ../export-auto
cd ..
cp bake_0~$v-1_amd64.deb bake_0~$v-1_amd64.deb.sig \
   bake_0~$v-1.debian.tar.xz bake_0~$v-1.debian.tar.xz.sig \
   export-auto
