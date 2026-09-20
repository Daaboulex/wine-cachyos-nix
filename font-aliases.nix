{
  runCommand,
  libxml2,
  fontconfig,
  src,
}:
runCommand "wine-cachyos-font-aliases" { nativeBuildInputs = [ libxml2 ]; } ''
  conf=30-win32-aliases.conf
  cp ${src}/wine-cachyos/$conf ${fontconfig.out}/share/xml/fontconfig/fonts.dtd .
  xmllint --noout --dtdvalid fonts.dtd $conf
  install -Dm644 $conf $out/etc/fonts/conf.d/$conf
''
