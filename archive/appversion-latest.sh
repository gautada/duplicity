pkg="duplicity"
suite="stable"
arch="amd64"

curl -fsSL "https://deb.debian.org/debian/dists/${suite}/main/binary-${arch}/Packages.xz" |
  xz -dc |
  awk -v pkg="$pkg" '
    BEGIN { RS=""; FS="\n" }
    {
      p=""; v="";
      for (i=1; i<=NF; i++) {
        if ($i ~ /^Package: /) p=substr($i,10);
        if ($i ~ /^Version: /) v=substr($i,10);
      }
      if (p == pkg) print v;
    }
  ' | sed 's/-.*//'
