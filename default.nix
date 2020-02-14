{ cairo, callPackage, curl, fetchgit, gfortran, hdf5-fortran, imagemagick,
  makeWrapper , netcdf, netcdfcxx4, netcdffortran, perl, stdenv, tcsh,
  xorg }:

let
  NCL = callPackage ../NCL.nix { };
  xlibs = with xorg; [
    libXrender
    libX11
    libXaw
    libXext
    libXmu
    libXt
    libSM
    libXpm
    libICE
  ];
  cairo-with-x11 = cairo.override { x11Support = true; };
in stdenv.mkDerivation rec {
  pname = "ROMS-plot";
  version = "0.0";

  src = ../ROMS-plot;

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [
    cairo-with-x11
    curl
    gfortran
    hdf5-fortran
    netcdf
    netcdffortran
    netcdfcxx4
    perl
  ] ++ xlibs;
  propagatedBuildInputs = [ NCL imagemagick tcsh ];

  prePatch = ''
    substituteInPlace src/Compilers/Darwin-gfortran.mk \
     --replace "\$(shell which \''${FC})" "${gfortran}/bin/gfortran"

    substituteInPlace src/Compilers/Darwin-gfortran.mk \
      --replace "/usr/bin/cpp" "${gfortran}/bin/cpp"

    substituteInPlace src/Compilers/Darwin-gfortran.mk \
      --replace "LIBS += -L/opt/X11/lib -lX11" "LIBS += -lX11 -lcairo -lfreetype"
  '';

  patches = [ ./0001-On-master-any-make.patch ];

  buildPhase = ''
    mkdir -p $out/Build_plt
    mkdir -p $out/bin
    cd src

    NCARG_ROOT=${NCL.out} \
    NC_CONFIG=nf-config \
    USE_NETCDF4=yes \
    SCRATCH_DIR=$out/Build_plt \
    PLT_LARGE=yes \
    PLT_BINDIR=$out/bin \
    make
  '';

  hardeningDisable = [ "format" ];

  installPhase = ''
    cp Bin/ncgm2gif.sh $out/bin/ncgm2gif.sh
    cp Bin/ncgm2png.sh $out/bin/ncgm2png.sh
    
    substituteInPlace $out/bin/ncgm2gif.sh \
      --replace "#!/bin/csh" "#!${tcsh.out}/bin/tcsh"

    substituteInPlace $out/bin/ncgm2png.sh \
      --replace "#!/bin/csh" "#!${tcsh.out}/bin/tcsh"

    substituteInPlace $out/bin/ncgm2gif.sh \
      --replace "/opt/local/bin/convert" "${imagemagick.out}/bin/convert"

    substituteInPlace $out/bin/ncgm2png.sh \
      --replace "/opt/local/bin/convert" "${imagemagick.out}/bin/convert"

    for i in $out/bin/*; do
      echo "Wrapping ''${i}"
      wrapProgram $i \
        --set NCARG_ROOT ${NCL.out}
    done
  '';
}
