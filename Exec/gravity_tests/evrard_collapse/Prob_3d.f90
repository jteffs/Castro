   subroutine PROBINIT (init,name,namlen,problo,probhi)
     
     use probdata_module, only: initialize

     use bl_fort_module, only : rt => c_real
     implicit none

     integer :: init, namlen
     integer :: name(namlen)
     real(rt)         :: problo(3), probhi(3)

     call initialize(name, namlen)

   end subroutine PROBINIT


   ! ::: -----------------------------------------------------------
   ! ::: This routine is called at problem setup time and is used
   ! ::: to initialize data on each grid.  
   ! ::: 
   ! ::: NOTE:  all arrays have one cell of ghost zones surrounding
   ! :::        the grid interior.  Values in these cells need not
   ! :::        be set here.
   ! ::: 
   ! ::: INPUTS/OUTPUTS:
   ! ::: 
   ! ::: level     => amr level of grid
   ! ::: time      => time at which to init data             
   ! ::: lo,hi     => index limits of grid interior (cell centered)
   ! ::: nstate    => number of state components.  You should know
   ! :::		   this already!
   ! ::: state     <=  Scalar array
   ! ::: delta     => cell size
   ! ::: xlo,xhi   => physical locations of lower left and upper
   ! :::              right hand corner of grid.  (does not include
   ! :::		   ghost region).
   ! ::: -----------------------------------------------------------
   subroutine ca_initdata(level,time,lo,hi,nscal, &
                          state,state_l1,state_l2,state_l3,state_h1,state_h2,state_h3, &
                          delta,xlo,xhi)

     use probdata_module
     use eos_module, only: eos_input_re, eos
     use eos_type_module, only: eos_t
     use meth_params_module, only : NVAR, URHO, UMX, UMY, UMZ, UTEMP, &
          UEDEN, UEINT, UFS
     use network, only : nspec
     use bl_constants_module, only: ZERO, HALF, ONE, TWO, M_PI
     use fundamental_constants_module, only: Gconst, M_solar
     use prob_params_module, only: center

     use bl_fort_module, only : rt => c_real
     implicit none

     integer :: level, nscal
     integer :: lo(3), hi(3)
     integer :: state_l1,state_l2,state_l3,state_h1,state_h2,state_h3
     real(rt)         :: xlo(3), xhi(3), time, delta(3)
     real(rt)         :: state(state_l1:state_h1,state_l2:state_h2,state_l3:state_h3,NVAR)

     real(rt)         :: loc(3)
     real(rt)         :: radius

     type (eos_t) :: zone_state

     integer :: i,j,k

     ! Loop through the zones and set the zone state depending on whether we are
     ! inside the sphere or if we are in an ambient zone.

     !$OMP PARALLEL DO PRIVATE(i, j, k, loc, radius, zone_state)
     do k = lo(3), hi(3)   
        loc(3) = xlo(3) + delta(3)*dble(k+HALF-lo(3)) 

        do j = lo(2), hi(2)     
           loc(2) = xlo(2) + delta(2)*dble(j+HALF-lo(2))

           do i = lo(1), hi(1)   
              loc(1) = xlo(1) + delta(1)*dble(i+HALF-lo(1))

              radius = sum( (loc - center)**2 )**HALF

              if (radius <= sphere_radius) then
                 zone_state % rho = (sphere_mass * M_solar) / (TWO * M_PI * sphere_radius**2 * radius)
              else
                 zone_state % rho = ambient_density
              endif

              zone_state % e     = 0.05 * Gconst * sphere_mass * m_solar / radius
              zone_state % xn(:) = ONE / nspec

              call eos(eos_input_re, zone_state)

              state(i,j,k,URHO)  = zone_state % rho
              state(i,j,k,UTEMP) = zone_state % T
              state(i,j,k,UEINT) = zone_state % e * zone_state % rho
              state(i,j,k,UFS:UFS+nspec-1) = zone_state % xn(:) * zone_state % rho

              state(i,j,k,UMX) = state(i,j,k,URHO) * smallu
              state(i,j,k,UMY) = state(i,j,k,URHO) * smallu
              state(i,j,k,UMZ) = state(i,j,k,URHO) * smallu

              state(i,j,k,UEDEN) = state(i,j,k,UEINT) + &
                ( state(i,j,k,UMX)**2 + state(i,j,k,UMY)**2 + state(i,j,k,UMZ)**2 ) / &
                ( TWO * state(i,j,k,URHO) )

           enddo
        enddo
     enddo
     !$OMP END PARALLEL DO

   end subroutine ca_initdata
