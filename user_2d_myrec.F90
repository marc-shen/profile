module m_userfile
  use m_globalnamespace
  use m_aux
  use m_readinput
  use m_domain
  use m_particles
  use m_fields
  use m_thermalplasma
  use m_particlelogistics
  use m_helpers
  use m_exchangearray, only: exchangeArray
#ifdef USROUTPUT
  use m_writeusroutput
#endif

! This file is based on `user_2d_shock_inj_04.F90`

  implicit none

  !--- PRIVATE variables -----------------------------------------!
  real :: dgamma_up, B0, lambda_width  !,yy_offset
  private :: dgamma_up, B0, lambda_width !, yy_offset
  !...............................................................!

  !--- PRIVATE functions -----------------------------------------!
  private :: userSpatialDistribution
  !...............................................................!
contains
  !--- initialization -----------------------------------------!
  !FINISH: Finish
  subroutine userReadInput()
    implicit none
    ! call getInput('problem', 'gamma', gamma_up)
    !call getInput('problem', 'dgamma', dgamma_up)
    call getInput('problem', 'B0', B0)
    call getInput('problem', 'lambda', lambda_width)
    call getInput('problem', 'dgamma', dgamma_up)
    ! call getInput('problem', 'yy_offset', yy_offset)
  end subroutine userReadInput

  !FINISH: Finish
  function userSLBload(x_glob, y_glob, z_glob, &
                       dummy1, dummy2, dummy3)
    real :: userSLBload
    ! global coordinates
    real, intent(in), optional :: x_glob, y_glob, z_glob
    ! global box dimensions
    real, intent(in), optional :: dummy1, dummy2, dummy3
    return
  end function

  !FINISH: Finish
  function userSpatialDistribution(x_glob, y_glob, z_glob, &
                                   dummy1, dummy2, dummy3)
    real :: userSpatialDistribution
    real, intent(in), optional :: x_glob, y_glob, z_glob
    real, intent(in), optional :: dummy1, dummy2, dummy3
    ! userSpatialDistribution = 1.0 / (cosh((y_glob - dummy1) / dummy2))**2
    return
  end function

  !FINISH: Finish
  subroutine userInitParticles()
    implicit none
    real :: dens, yy_offset !, lambda_width
    type(region) :: back_region
    procedure(spatialDistribution), pointer :: spat_distr_ptr => null()
    spat_distr_ptr => userSpatialDistribution

    ! yy_offset = 0.5 * REAL(global_mesh%sy)

    dens = 0.5 * ppc0
#if defined(twoD) || defined (threeD)
    back_region % y_min = 0.0
    back_region % y_max = REAL(global_mesh % sy)
#endif
    ! shift_beta = sqrt(1.0 - 1.0 / gamma_up**2)
    back_region % x_min = 0.0
    back_region % x_max = REAL(global_mesh % sx)
    call fillRegionWithThermalPlasma(back_region, (/1, 2/), 2, dens, 0.25, &
                                    zero_current=.true.)! , &
    !                                dummy1 = yy_offset, dummy2 = lambda_width)

  end subroutine userInitParticles

  !FINISH: Finish
  subroutine userInitFields()
    implicit none
    integer :: i, j, k
    integer :: i_glob, j_glob, k_glob
    real :: B0, random, yy_offset !, lambda_width ! , x_glob, y_glob, z_glob
    
    ! ex(:,:,:) = 0; ey(:,:,:) = 0; ez(:,:,:) = 0
    ! bx(:,:,:) = 0; by(:,:,:) = 0; bz(:,:,:) = 0
    ! jx(:,:,:) = 0; jy(:,:,:) = 0; jz(:,:,:) = 0

    yy_offset = 0.5 * REAL(global_mesh%sy)
    
    k = 0

    do i = 0, this_meshblock%ptr%sx - 1
      i_glob = i + this_meshblock%ptr%x0 ! <- converting local to global coordinates
      do j = 0, this_meshblock%ptr%sy - 1
        j_glob = REAL(j + this_meshblock%ptr%y0)
        ! do k = 0, this_meshblock%ptr%sz - 1
          ! k_glob = k + this_meshblock%ptr%z0

        ! x_glob = REAL(i + this_meshblock%ptr%x0)
        ! y_glob = REAL(j + this_meshblock%ptr%y0)
        ! z_glob = REAL(k + this_meshblock%ptr%z0)

        ! notice that `ex` is staggered in y and z direction ...
        ! ex(i, j, k) = 0
        ! ... and `ey` is staggered in x and z direction ...
        ! ey(i, j, k) = 0
        ! ez(i, j, k) = 0
        bx(i, j, k) = B0 * tanh((j_glob-yy_offset)/lambda_width)
        call random_number(random)
        by(i, j, k) = random * 0.03 * B0
        bz(i, j, k) = 0
        ! bz(i, j, k) = B0 / cosh((y_glob-yy_offset)/lambda_)
        ! end do
      end do
    end do
  end subroutine userInitFields
  !............................................................!

  !--- driving ------driving------------------------------------------!
  subroutine userCurrentDeposit(step)
    implicit none
    integer, optional, intent(in) :: step
    ! called after particles move and deposit ...
    ! ... and before the currents are added to the electric field
  end subroutine userCurrentDeposit

  subroutine userDriveParticles(step)
    implicit none
    integer, optional, intent(in) :: step
    ! ... dummy loop ...
    ! integer :: s, ti, tj, tk, p
    ! do s = 1, nspec
    !   do ti = 1, species(s)%tile_nx
    !     do tj = 1, species(s)%tile_ny
    !       do tk = 1, species(s)%tile_nz
    !         do p = 1, species(s)%prtl_tile(ti, tj, tk)%npart_sp
    !           ...
    !         end do
    !       end do
    !     end do
    !   end do
    ! end do
  end subroutine userDriveParticles

  subroutine userExternalFields(xp, yp, zp, &
                                ex_ext, ey_ext, ez_ext, &
                                bx_ext, by_ext, bz_ext)
    implicit none
    real, intent(in) :: xp, yp, zp
    real, intent(out) :: ex_ext, ey_ext, ez_ext
    real, intent(out) :: bx_ext, by_ext, bz_ext
    ! some functions of xp, yp, zp
    ex_ext = 0.0; ey_ext = 0.0; ez_ext = 0.0
    bx_ext = 0.0; by_ext = 0.0; bz_ext = 0.0
  end subroutine userExternalFields
  !............................................................!

  !--- boundaries ---------------------------------------------!
  subroutine userParticleBoundaryConditions(step)
    implicit none
    integer, optional, intent(in) :: step
  end subroutine userParticleBoundaryConditions

  subroutine userFieldBoundaryConditions(step, updateE, updateB)
    implicit none
    integer, optional, intent(in) :: step
    logical, optional, intent(in) :: updateE, updateB
    logical :: updateE_, updateB_

    if (present(updateE)) then
      updateE_ = updateE
    else
      updateE_ = .true.
    end if

    if (present(updateB)) then
      updateB_ = updateB
    else
      updateB_ = .true.
    end if
  end subroutine userFieldBoundaryConditions
  !............................................................!

#include "optional.F"
end module m_userfile
