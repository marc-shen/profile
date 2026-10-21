Active modulefiles belong to ~/Software/share/modulefiles, generated for this machine.
Generate one for an installed application:
  software-app module gcc 14.1
  module avail
  module load gcc/14.1
  module unload gcc
Pixi modules source the workspace activation hook. A manually compiled prefix gets
PATH, CMAKE_PREFIX_PATH and pkg-config paths; add CC/CXX/FC via pushenv when needed.
Fedora's /usr/share/modulefiles and Intel modules remain owned by their installers.
Project-specific modulefiles live here only when their paths use $env(HOME) or
$env(SOFTWARE_HOME). Historical Mac-only files are in archieve/modulefiles-macos-2025;
they are not added to MODULEPATH by the shared configuration.
