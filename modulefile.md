## 安装homebrew （Linux version）

https://brew.sh

## 安装 modules

```shell
brew install modules
```

Modules 官网 https://modules.sourceforge.net 看说明文档，写modulefiles

可以将文件放在 `~/config/modules/modulefiles/`下面

对应当前所用到的可能的文件，结构如下

```shell
$ tree
.
├── gcc
│   └── 14.2
├── hdf5
│   ├── 1.14.5
│   ├── mpi-1.14.5
│   └── parallel-1.14.3
└── mpi
    ├── mpich-4.2.3
    └── openmpi-5.0.6
```



修改module的配置文件

```shell
$ brew list modules # 运行这行
/opt/homebrew/Cellar/modules/5.5.0/bin/add.modules
/opt/homebrew/Cellar/modules/5.5.0/bin/envml
/opt/homebrew/Cellar/modules/5.5.0/bin/mkroot
/opt/homebrew/Cellar/modules/5.5.0/bin/modulecmd
/opt/homebrew/Cellar/modules/5.5.0/etc/ (2 files) #这个路径下的initrc文件
/opt/homebrew/Cellar/modules/5.5.0/init/ksh-functions/ (2 files)
/opt/homebrew/Cellar/modules/5.5.0/init/zsh-functions/_module
/opt/homebrew/Cellar/modules/5.5.0/init/ (20 files)
/opt/homebrew/Cellar/modules/5.5.0/lib/libtclenvmodules.dylib
/opt/homebrew/Cellar/modules/5.5.0/libexec/modulecmd.tcl
/opt/homebrew/Cellar/modules/5.5.0/modulefiles/ (6 files)
/opt/homebrew/Cellar/modules/5.5.0/sbom.spdx.json
/opt/homebrew/Cellar/modules/5.5.0/share/doc/ (9 files)
/opt/homebrew/Cellar/modules/5.5.0/share/man/ (3 files)
/opt/homebrew/Cellar/modules/5.5.0/share/nagelfar/ (5 files)
/opt/homebrew/Cellar/modules/5.5.0/share/vim/ (3 files)
```

修改`/opt/homebrew/Cellar/modules/5.5.0/etc/initrc`文件，按照你上面的输出来。

在其中增加一行`module use --append {/Users/marcshen/.config/modules/modulefiles}`改成你的路径。

修改完大概张这个样子

```shell
# enable default modulepaths
module use --append {/opt/homebrew/Cellar/modules/5.5.0/modulefiles}
module use --append {/Users/marcshen/.config/modules/modulefiles}
```



## 安装gcc 14

```shell
brew install gcc
```

对应的modulefiles （示例，后面的路径不对，你要重新安装）

`vim ~/config/modules/modulefiles/gcc/14.2`

```shell
#%Module
conflict     gcc
prepend-path PATH /opt/homebrew/Cellar/gcc/14.2.0_1/bin
prepend-path LD_LIBRARY_PATH /opt/homebrew/Cellar/gcc/14.2.0_1/lib
prepend-path MANPATH /opt/homebrew/Cellar/gcc/14.2.0_1/share/man
prepend-path CPATH /opt/homebrew/Cellar/gcc/14.2.0_1/include

```

这个是很早写的，写的很烂，建议找gpt按照下面的几个modulefile格式改写一下



## 安装openmpi

先让gcc生效

```shell
export HOMEBREW_CXX=g++-14
export HOMEBREW_CC=gcc-14
```

安装openmpi

```shell
brew install open-mpi --build-from-source

#这时候运行 mpifort --version应该如下
#❯ mpifort --version
#GNU Fortran (Homebrew GCC 14.2.0_1) 14.2.0
#Copyright (C) 2024 Free Software Foundation, Inc.
#This is free software; see the source for copying conditions.  There is NO
#warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

brew unlink open-mpi
```

对应的modulefile

`vim ~/config/modules/modulefiles/mpi/openmpi-5.0.6`

```
#%Module1.0######################################################################
##
## MPI modulefile
##
#################################################################################
proc ModulesHelp { } {
  puts stderr "\tMPI\n"
}

module-whatis      "Sets up MPI"

conflict           mpi ompi openmpi mpich intel-mpi open-mpi
prereq             gcc/14.2

set                basedir               /opt/homebrew/Cellar/open-mpi/5.0.6/
prepend-path       PATH                  $basedir/bin
prepend-path       LD_LIBRARY_PATH       $basedir/lib

append-path -d { } LOCAL_LDFLAGS      -L $basedir/lib
append-path -d { } LOCAL_INCLUDE      -I $basedir/include
append-path -d { } LOCAL_CFLAGS       -I $basedir/include
append-path -d { } LOCAL_FCFLAGS      -I $basedir/include
append-path -d { } LOCAL_CXXFLAGS     -I $basedir/include

setenv             CXX                   $basedir/bin/mpicxx
setenv             CC                    $basedir/bin/mpicc
setenv             FC                    $basedir/bin/mpif90

setenv             SLURM_MPI_TYPE        pmix_v3
setenv             MPIHOME               $basedir
setenv             MPI_HOME              $basedir
setenv             OPENMPI_HOME          $basedir

```

修改其中的basedir理论上就行



## 安装mpich

安装mpich

```
brew install mpich --build-from-source

#这时候运行 mpifort --version应该如下
#❯ mpifort --version
#GNU Fortran (Homebrew GCC 14.2.0_1) 14.2.0
#Copyright (C) 2024 Free Software Foundation, Inc.
#This is free software; see the source for copying conditions.  There is NO
#warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

brew unlink mpich
```



对应的modulefile

`vim ~/config/modules/modulefiles/mpi/mpich-4.2.3`

```
#%Module1.0######################################################################
##
## MPI modulefile
##
#################################################################################
proc ModulesHelp { } {
  puts stderr "\tMPI\n"
}

module-whatis      "Sets up MPI"

conflict           mpi ompi openmpi mpich intel-mpi open-mpi
prereq             gcc/14.2

set                basedir               /opt/homebrew/Cellar/mpich/4.2.3/
prepend-path       PATH                  $basedir/bin
prepend-path       LD_LIBRARY_PATH       $basedir/lib

append-path -d { } LOCAL_LDFLAGS      -L $basedir/lib
append-path -d { } LOCAL_INCLUDE      -I $basedir/include
append-path -d { } LOCAL_CFLAGS       -I $basedir/include
append-path -d { } LOCAL_FCFLAGS      -I $basedir/include
append-path -d { } LOCAL_CXXFLAGS     -I $basedir/include

setenv             CXX                   $basedir/bin/mpicxx
setenv             CC                    $basedir/bin/mpicc
setenv             FC                    $basedir/bin/mpif90 

setenv             SLURM_MPI_TYPE        pmix_v3
setenv             MPIHOME               $basedir
setenv             MPI_HOME              $basedir
setenv             OPENMPI_HOME          $basedir
```



## 安装 hypre

没用过，没测试过，希望管用，虽然是能安装，但是依赖好像是open-mpi

```
module load mpi/openmpi-5.0.6

brew install hypre --build-from-source
```



## 安装 hdf5

这个可能会有些奇怪的问题，在mac上会有小问题，但Linux应该问题不大，希望。所以我们提供两个版本的，总有一个能正常用。这时候我们最开始安装的modules的含金量就体现出来了，这下能兼容很多个不同版本。



此时要先启用openmpi

```
module load mpi/openmpi-5.0.6
```

### 官方非多线程版

```
brew install hdf5 --build-from-source
brew unlink hdf5
```

Module file

`vim ~/config/modules/modulefiles/hdf5/1.14.5`

```
#%Module1.0######################################################################
##
## HDF5 with MPI support modulefile
##
#################################################################################
proc ModulesHelp { } {
  puts stderr "\tHDF5 \n"
}

module-whatis      "Sets up HDF5 "    

conflict           hdf5 phdf5 hdf5-mpi hdf5-parallel
prereq             gcc/14.2

set                basedir               /opt/homebrew/Cellar/hdf5/1.14.5/
prepend-path       PATH                  $basedir/bin
prepend-path       LD_LIBRARY_PATH       $basedir/lib
prepend-path       LIBRARY_PATH          $basedir/lib
prepend-path       MANPATH               $basedir/man
prepend-path       HDF5_ROOT             $basedir
prepend-path       HDF5DIR               $basedir
append-path        -d { } LDFLAGS        -L$basedir/lib
append-path        -d { } INCLUDE        -I$basedir/include
append-path        CPATH                 $basedir/include
append-path        -d { } FFLAGS         -I$basedir/include
append-path        -d { } FCFLAGS        -I$basedir/include
append-path        -d { } LOCAL_LDFLAGS  -L$basedir/lib
append-path        -d { } LOCAL_INCLUDE  -I$basedir/include
append-path        -d { } LOCAL_CFLAGS   -I$basedir/include
append-path        -d { } LOCAL_FFLAGS   -I$basedir/include
append-path        -d { } LOCAL_FCFLAGS  -I$basedir/include
append-path        -d { } LOCAL_CXXFLAGS -I$basedir/include

```







### 官方多线程版

```
brew install hdf5-mpi --build-from-source
brew unlink hdf5-mpi
```



modulefile

`vim ~/config/modules/modulefiles/hdf5/mpi-1.14.5`

```
#%Module1.0######################################################################
##
## HDF5 with MPI support modulefile
##
#################################################################################
proc ModulesHelp { } {
  puts stderr "\tHDF5 with MPI support\n"
}

module-whatis      "Sets up HDF5 with MPI support"    

conflict           hdf5 phdf5 hdf5-mpi hdf5-parallel
prereq             gcc/14.2
prereq             mpi/openmpi-5.0.6

set                basedir               /opt/homebrew/Cellar/hdf5-mpi/1.14.5/
prepend-path       PATH                  $basedir/bin
prepend-path       LD_LIBRARY_PATH       $basedir/lib
prepend-path       LIBRARY_PATH          $basedir/lib
prepend-path       MANPATH               $basedir/man
prepend-path       HDF5_ROOT             $basedir
prepend-path       HDF5DIR               $basedir
append-path        -d { } LDFLAGS        -L$basedir/lib
append-path        -d { } INCLUDE        -I$basedir/include
append-path        CPATH                 $basedir/include
append-path        -d { } FFLAGS         -I$basedir/include
append-path        -d { } FCFLAGS        -I$basedir/include
append-path        -d { } LOCAL_LDFLAGS  -L$basedir/lib
append-path        -d { } LOCAL_INCLUDE  -I$basedir/include
append-path        -d { } LOCAL_CFLAGS   -I$basedir/include
append-path        -d { } LOCAL_FFLAGS   -I$basedir/include
append-path        -d { } LOCAL_FCFLAGS  -I$basedir/include
append-path        -d { } LOCAL_CXXFLAGS -I$basedir/include

```





### 非官方多线程版(比较靠谱)

```
brew tap abinit/tap

brew install hdf5-parallel --build-from-source

brew unlink hdf5-parallel
```

Module file

`vim ~/config/modules/modulefiles/hdf5/parallel-1.14.3`

```
#%Module1.0######################################################################
##
## HDF5 with MPI support modulefile
##
#################################################################################
proc ModulesHelp { } {
  puts stderr "\tHDF5 with MPI support\n"
}

module-whatis      "Sets up HDF5 with MPI support"    

conflict           hdf5 phdf5 hdf5-mpi hdf5-parallel
prereq             gcc/14.2
prereq             mpi/openmpi-5.0.6

set                basedir               /opt/homebrew/Cellar/hdf5-parallel/1.14.3/
prepend-path       PATH                  $basedir/bin
prepend-path       LD_LIBRARY_PATH       $basedir/lib
prepend-path       LIBRARY_PATH          $basedir/lib
prepend-path       MANPATH               $basedir/man
prepend-path       HDF5_ROOT             $basedir
prepend-path       HDF5DIR               $basedir
append-path        -d { } LDFLAGS        -L$basedir/lib
append-path        -d { } INCLUDE        -I$basedir/include
append-path        CPATH                 $basedir/include
append-path        -d { } FFLAGS         -I$basedir/include
append-path        -d { } FCFLAGS        -I$basedir/include
append-path        -d { } LOCAL_LDFLAGS  -L$basedir/lib
append-path        -d { } LOCAL_INCLUDE  -I$basedir/include
append-path        -d { } LOCAL_CFLAGS   -I$basedir/include
append-path        -d { } LOCAL_FFLAGS   -I$basedir/include
append-path        -d { } LOCAL_FCFLAGS  -I$basedir/include
append-path        -d { } LOCAL_CXXFLAGS -I$basedir/include

```



## 差不多依赖就安装完了

```
module load hdf5/parallel-1.14.3
```

这样会自动拉取依赖open-mpi和gcc-14和hdf5，环境变量也自动生效。

理论上就可以正常编译了。

如果记不住哪个包安装在哪里，可以用`brew list`，比如`brew list open-mpi`。



综上。
