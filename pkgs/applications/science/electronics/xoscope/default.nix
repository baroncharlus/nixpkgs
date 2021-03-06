{stdenv, fetchurl, gtk2, pkgconfig}:

stdenv.mkDerivation rec {
  name = "xoscope-2.0";

  src = fetchurl {
    url = "mirror://sourceforge/xoscope/${name}.tgz";
    sha256 = "00xlvvqyw6l1ljbsx1vgx2v1jfh0xacz1a0yhq1dj6yxf5wh58x8";
  };

  nativeBuildInputs = [ pkgconfig ];
  buildInputs = [ gtk2 ];

  # from: https://aur.archlinux.org/packages.php?ID=12140&detail=1
  patches = [ ./gtkdepre.diff ];

  meta = {
    description = "Oscilloscope through the sound card";
    homepage = http://xoscope.sourceforge.net;
    license = stdenv.lib.licenses.gpl2Plus;
    maintainers = with stdenv.lib.maintainers; [viric];
    platforms = with stdenv.lib.platforms; linux;
  };
}
