!=====================================================================
!
!          S p e c f e m 3 D  G l o b e  V e r s i o n  5 . 0
!          --------------------------------------------------
!
!          Main authors: Dimitri Komatitsch and Jeroen Tromp
!                        Princeton University, USA
!             and University of Pau / CNRS / INRIA, France
! (c) Princeton University / California Institute of Technology and University of Pau / CNRS / INRIA
!                            March 2010
!
! This program is free software; you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation; either version 2 of the License, or
! (at your option) any later version.
!
! This program is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License along
! with this program; if not, write to the Free Software Foundation, Inc.,
! 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
!
!=====================================================================

!--------------------------------------------------------------------------------------------------
!
! PPM - point profile models
!
! for generic models given as depth profiles at lon/lat using a text-file format like:
!
! #lon(deg), lat(deg), depth(km), Vs-perturbation wrt PREM(%), Vs-PREM (km/s)
!  -10.00000       31.00000       40.00000      -1.775005       4.400000    
!  -10.00000       32.00000       40.00000      -1.056823       4.400000    
! ...
!
!--------------------------------------------------------------------------------------------------

  module module_PPM

  include "constants.h"

  ! file
  character(len=150):: PPM_file_path = "./DATA/PPM/model.txt"

  ! smoothing parameters
  logical,parameter:: GAUSS_SMOOTHING = .false.
  
  double precision,parameter:: sigma_h = 10.0 ! 50.0  ! km, horizontal
  double precision,parameter:: sigma_v = 10.0 ! 20.0   ! km, vertical

  double precision,parameter:: pi_by180 = PI/180.0d0
  double precision,parameter:: degtokm = pi_by180*R_EARTH_KM

  double precision,parameter:: const_a = sigma_v/3.0
  double precision,parameter:: const_b = sigma_h/3.0/(R_EARTH_KM*pi_by180)
  integer,parameter:: NUM_GAUSSPOINTS = 10
  
  double precision,parameter:: pi_by2 = PI/2.0d0
  double precision,parameter:: radtodeg = 180.0d0/PI
  
  ! ----------------------
  ! scale perturbations in shear speed to perturbations in density and vp
  logical,parameter:: SCALE_MODEL = .false.

  ! factor to convert perturbations in shear speed to perturbations in density
  ! taken from s20rts (see also Qin, 2009, sec. 5.2)
  double precision, parameter :: SCALE_RHO = 0.40d0     

  ! SCEC version 4 model relationship http://www.data.scec.org/3Dvelocity/
  !double precision, parameter :: SCALE_RHO = 0.254d0   

  ! see: P wave seismic velocity and Vp/Vs ratio beneath the Italian peninsula from local earthquake tomography 
  ! (Davide Scadi et al.,2008. tectonophysics)
  !! becomes unstable !!
  !double precision, parameter :: SCALE_VP =  1.75d0 !  corresponds to average vp/vs ratio
  
  ! Zhou et al. 2005: global upper-mantle structure from finite-frequency surface-wave tomography
  ! http://www.gps.caltech.edu/~yingz/pubs/Zhou_JGR_2005.pdf   
  !double precision, parameter :: SCALE_VP =  0.5d0 ! by lab measurements Montagner & Anderson, 1989
  
  ! Qin et al. 2009, sec. 5.2
  double precision, parameter :: SCALE_VP =  0.588d0 ! by Karato, 1993
  
  end module module_PPM

!  
!--------------------------------------------------------------------------------------------------
!

  subroutine model_ppm_broadcast(myrank,PPM_V)

! standard routine to setup model 

  implicit none
  
  include "constants.h"
  ! standard include of the MPI library
  include 'mpif.h'

! point profile model_variables
  type model_ppm_variables
    double precision,dimension(:),pointer :: dvs,lat,lon,depth
    double precision :: maxlat,maxlon,minlat,minlon,maxdepth,mindepth
    double precision :: dlat,dlon,ddepth,max_dvs,min_dvs
    integer :: num_v,num_latperlon,num_lonperdepth
  end type model_ppm_variables
  type (model_ppm_variables) PPM_V

  integer :: myrank
  integer :: ier
  
  ! upper mantle structure
  if(myrank == 0) call read_model_ppm(PPM_V)
  
  ! broadcast the information read on the master to the nodes      
  call MPI_BCAST(PPM_V%num_v,1,MPI_INTEGER,0,MPI_COMM_WORLD,ier)          
  call MPI_BCAST(PPM_V%num_latperlon,1,MPI_INTEGER,0,MPI_COMM_WORLD,ier)    
  call MPI_BCAST(PPM_V%num_lonperdepth,1,MPI_INTEGER,0,MPI_COMM_WORLD,ier)    
  if( myrank /= 0 ) then
    allocate(PPM_V%lat(PPM_V%num_v),PPM_V%lon(PPM_V%num_v),PPM_V%depth(PPM_V%num_v),PPM_V%dvs(PPM_V%num_v))
  endif
  call MPI_BCAST(PPM_V%dvs(1:PPM_V%num_v),PPM_V%num_v,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_BCAST(PPM_V%lat(1:PPM_V%num_v),PPM_V%num_v,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_BCAST(PPM_V%lon(1:PPM_V%num_v),PPM_V%num_v,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_BCAST(PPM_V%depth(1:PPM_V%num_v),PPM_V%num_v,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_BCAST(PPM_V%maxlat,1,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_BCAST(PPM_V%minlat,1,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_BCAST(PPM_V%maxlon,1,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_BCAST(PPM_V%minlon,1,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_BCAST(PPM_V%maxdepth,1,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_BCAST(PPM_V%mindepth,1,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_BCAST(PPM_V%dlat,1,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_BCAST(PPM_V%dlon,1,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)
  call MPI_BCAST(PPM_V%ddepth,1,MPI_DOUBLE_PRECISION,0,MPI_COMM_WORLD,ier)      
  
  end subroutine model_ppm_broadcast


!  
!--------------------------------------------------------------------------------------------------
!

  subroutine read_model_ppm(PPM_V)

  use module_PPM
  
  implicit none

  ! point profile model_variables
  type model_ppm_variables
    double precision,dimension(:),pointer :: dvs,lat,lon,depth
    double precision :: maxlat,maxlon,minlat,minlon,maxdepth,mindepth
    double precision :: dlat,dlon,ddepth,max_dvs,min_dvs
    integer :: num_v,num_latperlon,num_lonperdepth
  end type model_ppm_variables
  type (model_ppm_variables) PPM_V

  ! local parameters
  integer ::            ier,counter,i
  double precision ::    lon,lat,depth,dvs,vs
  character(len=150) ::  filename,line

  call get_value_string(filename, 'model.PPM', trim(PPM_file_path))

  !e.g. mediterranean model
  ! counts entries
  counter=0
  open(unit=10,file=trim(filename),status='old',action='read',iostat=ier)
  if( ier /= 0 ) then
    write(IMAIN,*) ' error count opening: ',trim(filename)
    call exit_mpi(0,"error count opening model ppm")
  endif
  
  ! first line is text and will be ignored
  read(10,'(a150)') line 
  
  ! counts number of data lines
  ier = 0
  do while (ier == 0 ) 
    read(10,*,iostat=ier) lon,lat,depth,dvs,vs
    if( ier == 0 ) then
      counter = counter + 1
    endif
  enddo
  close(10)
  
  PPM_V%num_v = counter
  if( counter < 1 ) then
    write(IMAIN,*)
    write(IMAIN,*) '  model PPM:',filename
    write(IMAIN,*) '     no values read in!!!!!!'
    write(IMAIN,*)
    write(IMAIN,*)
    call exit_mpi(0,' no model PPM ')
  else
    write(IMAIN,*)
    write(IMAIN,*) 'model PPM:',trim(filename)
    write(IMAIN,*) '  values: ',counter
    write(IMAIN,*)
  endif

  allocate(PPM_V%lat(counter),PPM_V%lon(counter),PPM_V%depth(counter),PPM_V%dvs(counter))
  PPM_V%min_dvs = 0.0
  PPM_V%max_dvs = 0.0
  PPM_V%dvs(:) = 0.0
  
  ! vs values
  open(unit=10,file=trim(filename),status='old',action='read',iostat=ier)
  if( ier /= 0 ) then
    write(IMAIN,*) ' error opening: ',trim(filename)
    call exit_mpi(0,"error opening model ppm")
  endif  
  read(10,'(a150)') line   ! first line is text
  counter=0
  ier = 0
  do while (ier == 0 ) 
    read(10,*,iostat=ier) lon,lat,depth,dvs,vs
    if( ier == 0 ) then
      counter = counter + 1
      PPM_V%lat(counter) = lat
      PPM_V%lon(counter) = lon
      PPM_V%depth(counter) = depth
      PPM_V%dvs(counter) = dvs/100.0
      
      !debug
      !if( abs(depth - 100.0) < 1.e-3) write(IMAIN,*) '  lon/lat/depth : ',lon,lat,depth,' dvs:',dvs
    endif
  enddo
  close(10)
  if( counter /= PPM_V%num_v ) then
    write(IMAIN,*)
    write(IMAIN,*) '  model PPM:',filename
    write(IMAIN,*) '     error values read in!!!!!!'
    write(IMAIN,*) '  expected: ',PPM_V%num_v
    write(IMAIN,*) '  got: ',counter
    call exit_mpi(0,' error model PPM ')
  endif

  
  ! gets depths (in km) of upper and lower limit
  PPM_V%minlat = minval( PPM_V%lat(1:PPM_V%num_v) )
  PPM_V%maxlat = maxval( PPM_V%lat(1:PPM_V%num_v) )

  PPM_V%minlon = minval( PPM_V%lon(1:PPM_V%num_v) )
  PPM_V%maxlon = maxval( PPM_V%lon(1:PPM_V%num_v) )

  PPM_V%mindepth = minval( PPM_V%depth(1:PPM_V%num_v) )  
  PPM_V%maxdepth = maxval( PPM_V%depth(1:PPM_V%num_v) )

  PPM_V%min_dvs = minval(PPM_V%dvs(1:PPM_V%num_v))
  PPM_V%max_dvs = maxval(PPM_V%dvs(1:PPM_V%num_v))
  
  write(IMAIN,*) 'model PPM:'
  write(IMAIN,*) '  latitude min/max   : ',PPM_V%minlat,PPM_V%maxlat
  write(IMAIN,*) '  longitude min/max: ',PPM_V%minlon,PPM_V%maxlon
  write(IMAIN,*) '  depth min/max      : ',PPM_V%mindepth,PPM_V%maxdepth  
  write(IMAIN,*)
  write(IMAIN,*) '  dvs min/max : ',PPM_V%min_dvs,PPM_V%max_dvs
  write(IMAIN,*)
  if( SCALE_MODEL ) then
    write(IMAIN,*) '  scaling: '
    write(IMAIN,*) '    rho: ',SCALE_RHO
    write(IMAIN,*) '    vp : ',SCALE_VP
    write(IMAIN,*)
  endif
  if( GAUSS_SMOOTHING ) then
    write(IMAIN,*) '  smoothing: '
    write(IMAIN,*) '    sigma horizontal : ',sigma_h
    write(IMAIN,*) '    sigma vertical   : ',sigma_v
    write(IMAIN,*)
  endif

  ! steps lengths
  PPM_V%dlat = 0.0d0
  lat = PPM_V%lat(1)
  do i=1,PPM_V%num_v
    if( abs(lat - PPM_V%lat(i)) > 1.e-15 ) then 
      PPM_V%dlat = PPM_V%lat(i) - lat
      exit
    endif
  enddo

  PPM_V%dlon = 0.0d0
  lon = PPM_V%lon(1)
  do i=1,PPM_V%num_v
    if( abs(lon - PPM_V%lon(i)) > 1.e-15 ) then 
      PPM_V%dlon = PPM_V%lon(i) - lon 
      exit
    endif
  enddo

  PPM_V%ddepth = 0.0d0
  depth = PPM_V%depth(1)
  do i=1,PPM_V%num_v
    if( abs(depth - PPM_V%depth(i)) > 1.e-15 ) then 
      PPM_V%ddepth = PPM_V%depth(i) - depth
      exit
    endif
  enddo  
  
  if( abs(PPM_V%dlat) < 1.e-15 .or. abs(PPM_V%dlon) < 1.e-15 .or. abs(PPM_V%ddepth) < 1.e-15) then
    write(IMAIN,*) '  model PPM:',filename
    write(IMAIN,*) '     error in delta values:'
    write(IMAIN,*) '     dlat : ',PPM_V%dlat,' dlon: ',PPM_V%dlon,' ddepth: ',PPM_V%ddepth
    call exit_mpi(0,' error model PPM ')  
  else
    write(IMAIN,*) '  model increments:'
    write(IMAIN,*) '  ddepth: ',sngl(PPM_V%ddepth),' dlat:',sngl(PPM_V%dlat),' dlon:',sngl(PPM_V%dlon)
    write(IMAIN,*)
  endif

  PPM_V%num_latperlon = int( (PPM_V%maxlat - PPM_V%minlat) / PPM_V%dlat) + 1
  PPM_V%num_lonperdepth = int( (PPM_V%maxlon - PPM_V%minlon) / PPM_V%dlon ) + 1  
  
  end subroutine read_model_ppm


!  
!--------------------------------------------------------------------------------------------------
!

  subroutine model_ppm(radius,theta,phi,dvs,dvp,drho,PPM_V)

! returns dvs,dvp and drho for given radius,theta,phi  location

  use module_PPM

  implicit none

  ! point profile model_variables
  type model_ppm_variables
    double precision,dimension(:),pointer :: dvs,lat,lon,depth
    double precision :: maxlat,maxlon,minlat,minlon,maxdepth,mindepth
    double precision :: dlat,dlon,ddepth,max_dvs,min_dvs
    integer :: num_v,num_latperlon,num_lonperdepth
  end type model_ppm_variables
  type (model_ppm_variables) PPM_V

  double precision radius,theta,phi,dvs,dvp,drho

  ! local parameters
  integer:: i,j,k 
  double precision:: lat,lon,r_depth
  double precision:: min_dvs,max_dvs

  double precision:: g_dvs,g_depth,g_lat,g_lon,x,g_weight,weight_sum,weight_prod
  
  ! initialize
  dvs = 0.0d0  
  dvp = 0.0d0
  drho = 0.0d0

  ! depth of given radius (in km)
  r_depth = R_EARTH_KM*(1.0 - radius)  ! radius is normalized between [0,1]
  if(r_depth>PPM_V%maxdepth .or. r_depth < PPM_V%mindepth) return

  lat=(pi_by2-theta)*radtodeg
  if( lat < PPM_V%minlat .or. lat > PPM_V%maxlat ) return
    
  lon=phi*radtodeg
  if(lon>180.0d0) lon=lon-360.0d0 
  if( lon < PPM_V%minlon .or. lon > PPM_V%maxlon ) return
  
  ! search location value  
  if( .not. GAUSS_SMOOTHING ) then
    call get_PPMmodel_value(lat,lon,r_depth,PPM_V,dvs)  
    return
  endif

  !write(IMAIN,*) '  model ppm at ',sngl(lat),sngl(lon),sngl(r_depth)
  
  ! loop over neighboring points  
  dvs = 0.0
  weight_sum = 0.0
  do i=-NUM_GAUSSPOINTS,NUM_GAUSSPOINTS
    g_depth = r_depth + i*const_a
    do j=-NUM_GAUSSPOINTS,NUM_GAUSSPOINTS
      g_lon = lon + j*const_b
      do k=-NUM_GAUSSPOINTS,NUM_GAUSSPOINTS
        g_lat = lat + k*const_b

        call get_PPMmodel_value(g_lat,g_lon,g_depth,PPM_V,g_dvs)

        ! horizontal weighting
        x = (g_lat-lat)*degtokm
        call get_Gaussianweight(x,sigma_h,g_weight)
        g_dvs = g_dvs*g_weight        
        weight_prod = g_weight
        
        x = (g_lon-lon)*degtokm
        call get_Gaussianweight(x,sigma_h,g_weight)
        g_dvs = g_dvs*g_weight
        weight_prod = weight_prod * g_weight
        
        !vertical weighting
        x = g_depth-r_depth
        call get_Gaussianweight(x,sigma_v,g_weight)
        g_dvs = g_dvs*g_weight
        weight_prod = weight_prod * g_weight

        ! averaging
        weight_sum = weight_sum + weight_prod        
        dvs = dvs + g_dvs
      enddo
    enddo
  enddo
  
  if( weight_sum > 1.e-15) dvs = dvs / weight_sum


  ! store min/max
  max_dvs = PPM_V%max_dvs
  min_dvs = PPM_V%min_dvs 

  if( dvs > max_dvs ) max_dvs = dvs
  if( dvs < min_dvs ) min_dvs = dvs
  
  PPM_V%max_dvs = max_dvs
  PPM_V%min_dvs = min_dvs

  !write(IMAIN,*) '    dvs = ',sngl(dvs),' weight: ',sngl(weight_sum),(sngl((2*PI*sigma_h**2)*sqrt(2*PI)*sigma_v))

  if( SCALE_MODEL ) then
    ! scale density and shear velocity
    drho = SCALE_RHO*dvs
    ! scale vp and shear velocity
    dvp = SCALE_VP*dvs
  endif  

  end subroutine model_ppm
  
!  
!--------------------------------------------------------------------------------------------------
!

  subroutine get_PPMmodel_value(lat,lon,depth,PPM_V,dvs)

  implicit none

  include "constants.h"

  ! point profile model_variables
  type model_ppm_variables
    double precision,dimension(:),pointer :: dvs,lat,lon,depth
    double precision :: maxlat,maxlon,minlat,minlon,maxdepth,mindepth
    double precision :: dlat,dlon,ddepth,max_dvs,min_dvs
    integer :: num_v,num_latperlon,num_lonperdepth
  end type model_ppm_variables
  type (model_ppm_variables) PPM_V

  double precision lat,lon,depth,dvs

  !integer i,j,k 
  !double precision r_top,r_bottom 
  
  integer index,num_latperlon,num_lonperdepth
  
  dvs = 0.0  
  
  if( lat > PPM_V%maxlat ) return
  if( lat < PPM_V%minlat ) return
  if( lon > PPM_V%maxlon ) return
  if( lon < PPM_V%minlon ) return
  if( depth > PPM_V%maxdepth ) return
  if( depth < PPM_V%mindepth ) return

  ! direct access: assumes having a regular interval spacing
  num_latperlon = PPM_V%num_latperlon ! int( (PPM_V%maxlat - PPM_V%minlat) / PPM_V%dlat) + 1
  num_lonperdepth = PPM_V%num_lonperdepth ! int( (PPM_V%maxlon - PPM_V%minlon) / PPM_V%dlon ) + 1
  
  index = int( (depth-PPM_V%mindepth)/PPM_V%ddepth )*num_lonperdepth*num_latperlon  &
          + int( (lon-PPM_V%minlon)/PPM_V%dlon )*num_latperlon &
          + int( (lat-PPM_V%minlat)/PPM_V%dlat ) + 1
  dvs = PPM_V%dvs(index)
          
  !  ! loop-wise: slower performance        
  !  do i=1,PPM_V%num_v
  !    ! depth
  !    r_top = PPM_V%depth(i) 
  !    r_bottom = PPM_V%depth(i) + PPM_V%ddepth 
  !    if( depth > r_top .and. depth <= r_bottom ) then
  !      ! longitude
  !      do j=i,PPM_V%num_v
  !        if( lon >= PPM_V%lon(j) .and. lon < PPM_V%lon(j)+PPM_V%dlon ) then
  !          ! latitude
  !          do k=j,PPM_V%num_v
  !            if( lat >= PPM_V%lat(k) .and. lat < PPM_V%lat(k)+PPM_V%dlat ) then
  !              dvs = PPM_V%dvs(k)                
  !              return
  !            endif
  !          enddo                  
  !        endif
  !      enddo    
  !    endif
  !  enddo

  end subroutine

!  
!--------------------------------------------------------------------------------------------------
!

  subroutine get_Gaussianweight(x,sigma,weight)

  implicit none

  include "constants.h"
  
  double precision:: x,sigma,weight
    
  double precision,parameter:: one_over2pisqrt = 0.3989422804014327
  
  ! normalized version  
  !weight = one_over2pisqrt*exp(-0.5*x*x/(sigma*sigma))/sigma

  ! only exponential
  weight = exp(-0.5*x*x/(sigma*sigma))

  end subroutine

!  
!--------------------------------------------------------------------------------------------------
!

  subroutine smooth_model(myrank, nproc_xi,nproc_eta,&
            rho_vp,rho_vs,nspec_stacey, &
            iregion_code,xixstore,xiystore,xizstore, &
            etaxstore,etaystore,etazstore, &
            gammaxstore,gammaystore,gammazstore, &
            xstore,ystore,zstore,rhostore,dvpstore, &
            kappavstore,kappahstore,muvstore,muhstore,eta_anisostore,&
            nspec,HETEROGEN_3D_MANTLE, &
            NEX_XI,NCHUNKS,ABSORBING_CONDITIONS,PPM_V )

! smooth model parameters
  
  implicit none

  include 'mpif.h'
  include "constants.h"
  include "precision.h"

  ! point profile model_variables
  type model_ppm_variables
    double precision,dimension(:),pointer :: dvs,lat,lon,depth
    double precision :: maxlat,maxlon,minlat,minlon,maxdepth,mindepth
    double precision :: dlat,dlon,ddepth,max_dvs,min_dvs
    integer :: num_v,num_latperlon,num_lonperdepth
  end type model_ppm_variables
  type (model_ppm_variables) PPM_V

  integer :: myrank, nproc_xi, nproc_eta

  integer NEX_XI

  integer nspec,nspec_stacey,NCHUNKS

  logical ABSORBING_CONDITIONS
  logical HETEROGEN_3D_MANTLE

! arrays with jacobian matrix
  real(kind=CUSTOM_REAL), dimension(NGLLX,NGLLY,NGLLZ,nspec) :: &
    xixstore,xiystore,xizstore,etaxstore,etaystore,etazstore,gammaxstore,gammaystore,gammazstore

! arrays with mesh parameters
  double precision xstore(NGLLX,NGLLY,NGLLZ,nspec)
  double precision ystore(NGLLX,NGLLY,NGLLZ,nspec)
  double precision zstore(NGLLX,NGLLY,NGLLZ,nspec)

! for anisotropy
  real(kind=CUSTOM_REAL), dimension(NGLLX,NGLLY,NGLLZ,nspec) :: rhostore,dvpstore,kappavstore,kappahstore,&
        muvstore,muhstore,eta_anisostore
  
! Stacey
  real(kind=CUSTOM_REAL) rho_vp(NGLLX,NGLLY,NGLLZ,nspec_stacey)
  real(kind=CUSTOM_REAL) rho_vs(NGLLX,NGLLY,NGLLZ,nspec_stacey)

! model_attenuation_variables
!  type model_attenuation_variables
!    sequence
!    double precision min_period, max_period
!    double precision                          :: QT_c_source        ! Source Frequency
!    double precision, dimension(:), pointer   :: Qtau_s             ! tau_sigma
!    double precision, dimension(:), pointer   :: QrDisc             ! Discontinutitues Defined
!    double precision, dimension(:), pointer   :: Qr                 ! Radius
!    integer, dimension(:), pointer            :: interval_Q                 ! Steps
!    double precision, dimension(:), pointer   :: Qmu                ! Shear Attenuation
!    double precision, dimension(:,:), pointer :: Qtau_e             ! tau_epsilon
!    double precision, dimension(:), pointer   :: Qomsb, Qomsb2      ! one_minus_sum_beta
!    double precision, dimension(:,:), pointer :: Qfc, Qfc2          ! factor_common
!    double precision, dimension(:), pointer   :: Qsf, Qsf2          ! scale_factor
!    integer, dimension(:), pointer            :: Qrmin              ! Max and Mins of idoubling
!    integer, dimension(:), pointer            :: Qrmax              ! Max and Mins of idoubling
!    integer                                   :: Qn                 ! Number of points
!    integer dummy_pad ! padding 4 bytes to align the structure
!  end type model_attenuation_variables
!
!  type (model_attenuation_variables) AM_V
! model_attenuation_variables

! attenuation
  !logical ATTENUATION,ATTENUATION_3D
  !integer vx, vy, vz, vnspec
  !double precision  T_c_source
  !double precision, dimension(N_SLS)                     :: tau_s
  !double precision, dimension(vx, vy, vz, vnspec)        :: Qmu_store
  !double precision, dimension(N_SLS, vx, vy, vz, vnspec) :: tau_e_store

  !integer NEX_PER_PROC_XI,NEX_PER_PROC_ETA,NEX_XI,ichunk
  !integer nglob
  
  !integer nspec_ani
  !real(kind=CUSTOM_REAL), dimension(NGLLX,NGLLY,NGLLZ,nspec_ani) :: &
  !  c11store,c12store,c13store,c14store,c15store,c16store, &
  !  c22store,c23store,c24store,c25store,c26store,c33store,c34store, &
  !  c35store,c36store,c44store,c45store,c46store,c55store,c56store,c66store

  !logical TRANSVERSE_ISOTROPY,ANISOTROPIC_3D_MANTLE,ANISOTROPIC_INNER_CORE
  !logical OCEANS

  ! local parameters
  integer i,j,k,ispec
  integer iregion_code
 
! only include the neighboring 3 x 3 slices
  integer, parameter :: NSLICES = 3
  integer ,parameter :: NSLICES2 = NSLICES * NSLICES

  integer :: sizeprocs, ier, ixi, ieta
  integer :: islice(NSLICES2), islice0(NSLICES2), nums

  real(kind=CUSTOM_REAL) :: sigma_h, sigma_h2, sigma_h3, sigma_v, sigma_v2, sigma_v3

  real(kind=CUSTOM_REAL) :: x0, y0, z0, norm, norm_h, norm_v, element_size
  real(kind=CUSTOM_REAL), dimension(NGLLX,NGLLY,NGLLZ) :: factor, exp_val
  
  real(kind=CUSTOM_REAL), dimension(NGLLX,NGLLY,NGLLZ,nspec) :: jacobian, jacobian0 
  real(kind=CUSTOM_REAL), dimension(NGLLX,NGLLY,NGLLZ,nspec) :: xl, yl, zl, xx, yy, zz

  real(kind=CUSTOM_REAL), dimension(:,:,:,:,:),allocatable :: slice_jacobian
  real(kind=CUSTOM_REAL), dimension(:,:,:,:,:),allocatable :: slice_x, slice_y, slice_z

  real(kind=CUSTOM_REAL), dimension(:,:,:,:,:,:),allocatable :: slice_kernels
  real(kind=CUSTOM_REAL), dimension(NGLLX,NGLLY,NGLLZ,nspec) :: ks_rho,ks_kv,ks_kh,ks_muv,ks_muh,ks_eta,ks_dvp,ks_rhovp,ks_rhovs
  real(kind=CUSTOM_REAL), dimension(NGLLX,NGLLY,NGLLZ,nspec) :: tk_rho,tk_kv,tk_kh,tk_muv,tk_muh,tk_eta,tk_dvp,tk_rhovp,tk_rhovs
  real(kind=CUSTOM_REAL), dimension(NGLLX,NGLLY,NGLLZ,nspec) :: bk  

  real(kind=CUSTOM_REAL) xixl,xiyl,xizl,etaxl,etayl,etazl,gammaxl,gammayl,gammazl,jacobianl

  real(kind=CUSTOM_REAL), dimension(:,:,:,:), allocatable:: xix,xiy,xiz,etax,etay,etaz,gammax,gammay,gammaz
  
  real(kind=CUSTOM_REAL), dimension(NGLLX,NGLLY,NGLLZ,nspec) :: x, y, z
  real(kind=CUSTOM_REAL), dimension(nspec) :: cx0, cy0, cz0, cx, cy, cz
  double precision :: starttime

  integer :: ii, ispec2, rank, mychunk

  ! Gauss-Lobatto-Legendre points of integration and weights
  double precision, dimension(NGLLX) :: xigll, wxgll
  double precision, dimension(NGLLY) :: yigll, wygll
  double precision, dimension(NGLLZ) :: zigll, wzgll

  ! array with all the weights in the cube
  double precision, dimension(NGLLX,NGLLY,NGLLZ) :: wgll_cube  

  real(kind=CUSTOM_REAL), parameter :: ZERO_ = 0.0_CUSTOM_REAL

  real(kind=CUSTOM_REAL) maxlat,maxlon,maxdepth
  real(kind=CUSTOM_REAL) minlat,minlon,mindepth
  real(kind=CUSTOM_REAL) radius,theta,phi,lat,lon,r_depth,margin_v,margin_h

!----------------------------------------------------------------------------------------------------
  ! smoothing parameters
  logical,parameter:: GAUSS_SMOOTHING = .false. ! set to true to use this smoothing routine

  sigma_h = 100.0  ! km, horizontal
  sigma_v = 50.0   ! km, vertical
  
  ! check if smoothing applies
  if( .not. GAUSS_SMOOTHING ) return
!----------------------------------------------------------------------------------------------------

  ! check region: only smooth in mantle & crust
  if( iregion_code /= IREGION_CRUST_MANTLE ) return
  
  
  sizeprocs = NCHUNKS*NPROC_XI*NPROC_ETA  
  element_size = (TWO_PI*R_EARTH/1000.d0)/(4*NEX_XI)

  if (myrank == 0) then
    write(IMAIN, *) "model smoothing defaults:"
    write(IMAIN, *) "  NPROC_XI , NPROC_ETA, NCHUNKS: ",nproc_xi,nproc_eta,nchunks
    write(IMAIN, *) "  total processors                    : ",sizeprocs
    write(IMAIN, *) "  element size on surface(km): ",element_size 
    write(IMAIN, *) "  smoothing sigma horizontal : ",sigma_h," vertical: ", sigma_v
  endif


  if (nchunks == 0) call exit_mpi(myrank,'no chunks')

  element_size = element_size * 1000  ! e.g. 9 km on the surface, 36 km at CMB
  element_size = element_size / R_EARTH

  sigma_h = sigma_h * 1000.0 ! m
  sigma_h = sigma_h / R_EARTH ! scale  
  sigma_v = sigma_v * 1000.0 ! m
  sigma_v = sigma_v / R_EARTH ! scale
  
  sigma_h2 = sigma_h ** 2
  sigma_v2 = sigma_v ** 2

  ! search radius
  sigma_h3 = 3.0  * sigma_h + element_size 
  sigma_h3 = sigma_h3 ** 2
  sigma_v3 = 3.0  * sigma_v + element_size 
  sigma_v3 = sigma_v3 ** 2
  ! theoretic normal value 
  ! (see integral over -inf to +inf of exp[- x*x/(2*sigma) ] = sigma * sqrt(2*pi) )
  norm_h = 2.0*PI*sigma_h**2
  norm_v = sqrt(2.0*PI) * sigma_v
  norm   = norm_h * norm_v

  if (myrank == 0) then
    write(IMAIN, *) "  spectral elements                 : ",nspec
    write(IMAIN, *) "  normalization factor              : ",norm
  endif

  ! GLL points
  call zwgljd(xigll,wxgll,NGLLX,GAUSSALPHA,GAUSSBETA)
  call zwgljd(yigll,wygll,NGLLY,GAUSSALPHA,GAUSSBETA)
  call zwgljd(zigll,wzgll,NGLLZ,GAUSSALPHA,GAUSSBETA)
  do k=1,NGLLZ
    do j=1,NGLLY
      do i=1,NGLLX
        wgll_cube(i,j,k) = wxgll(i)*wygll(j)*wzgll(k)
      enddo
    enddo
  enddo

  ! ---- figure out the neighboring 8 or 7 slices: (ichunk,ixi,ieta) index start at 0------
  ! note: ichunk is set to CHUNK_AB etc., while mychunk starts from 0
  mychunk = myrank / (nproc_xi * nproc_eta)
  ieta = (myrank - mychunk * nproc_xi * nproc_eta) / nproc_xi
  ixi = myrank - mychunk * nproc_xi * nproc_eta - ieta * nproc_xi

  ! get the neighboring slices:
  call get_all_eight_slices(mychunk,ixi,ieta,&
        islice0(1),islice0(2),islice0(3),islice0(4),islice0(5),islice0(6),islice0(7),islice0(8),&
        nproc_xi,nproc_eta)

  ! remove the repeated slices (only 8 for corner slices in global case)
  islice(1) = myrank; j = 1
  do i = 1, 8
    if (.not. any(islice(1:i) == islice0(i)) .and. islice0(i) < sizeprocs) then
      j = j + 1
      islice(j) = islice0(i)
    endif
  enddo
  nums = j 

  if( myrank == 0 ) then
    write(IMAIN, *) 'slices:',nums
    write(IMAIN, *) '  ',islice(1:nums)
    write(IMAIN, *)
  endif

  ! read in the topology files of the current and neighboring slices
  ! read in myrank slice
  xl(:,:,:,:) = xstore(:,:,:,:)
  yl(:,:,:,:) = ystore(:,:,:,:)
  zl(:,:,:,:) = zstore(:,:,:,:)
  
  ! build jacobian
  allocate(xix(NGLLX,NGLLY,NGLLZ,nspec),xiy(NGLLX,NGLLY,NGLLZ,nspec),xiz(NGLLX,NGLLY,NGLLZ,nspec))
  xix(:,:,:,:) = xixstore(:,:,:,:)
  xiy(:,:,:,:) = xiystore(:,:,:,:)
  xiz(:,:,:,:) = xizstore(:,:,:,:)

  allocate(etax(NGLLX,NGLLY,NGLLZ,nspec),etay(NGLLX,NGLLY,NGLLZ,nspec),etaz(NGLLX,NGLLY,NGLLZ,nspec))  
  etax(:,:,:,:) = etaxstore(:,:,:,:)
  etay(:,:,:,:) = etaystore(:,:,:,:)
  etaz(:,:,:,:) = etazstore(:,:,:,:)
  
  allocate(gammax(NGLLX,NGLLY,NGLLZ,nspec),gammay(NGLLX,NGLLY,NGLLZ,nspec),gammaz(NGLLX,NGLLY,NGLLZ,nspec))  
  gammax(:,:,:,:) = gammaxstore(:,:,:,:)
  gammay(:,:,:,:) = gammaystore(:,:,:,:)
  gammaz(:,:,:,:) = gammazstore(:,:,:,:)
  

  ! get the location of the center of the elements
  do ispec = 1, nspec
    do k = 1, NGLLZ
      do j = 1, NGLLY
        do i = 1, NGLLX
          ! build jacobian            
          !         get derivatives of ux, uy and uz with respect to x, y and z
          xixl = xix(i,j,k,ispec)
          xiyl = xiy(i,j,k,ispec)
          xizl = xiz(i,j,k,ispec)
          etaxl = etax(i,j,k,ispec)
          etayl = etay(i,j,k,ispec)
          etazl = etaz(i,j,k,ispec)
          gammaxl = gammax(i,j,k,ispec)
          gammayl = gammay(i,j,k,ispec)
          gammazl = gammaz(i,j,k,ispec)
          ! compute the jacobian
          jacobianl = xixl*(etayl*gammazl-etazl*gammayl) - xiyl*(etaxl*gammazl-etazl*gammaxl) &
                        + xizl*(etaxl*gammayl-etayl*gammaxl)
                        
          if( abs(jacobianl) > 1.e-25 ) then
            jacobianl = 1.0_CUSTOM_REAL / jacobianl
          else
            jacobianl = ZERO_
          endif

          jacobian(i,j,k,ispec) = jacobianl
        enddo
      enddo
    enddo
    cx0(ispec) = (xl(1,1,1,ispec) + xl(NGLLX,NGLLY,NGLLZ,ispec))*0.5
    cy0(ispec) = (yl(1,1,1,ispec) + yl(NGLLX,NGLLY,NGLLZ,ispec))*0.5
    cz0(ispec) = (zl(1,1,1,ispec) + zl(NGLLX,NGLLY,NGLLZ,ispec))*0.5
  enddo
  jacobian0(:,:,:,:) = jacobian(:,:,:,:)

  deallocate(xix,xiy,xiz,etax,etay,etaz,gammax,gammay,gammaz)

  if (myrank == 0) write(IMAIN, *) 'distributing locations, jacobians and model values ...'
  call mpi_barrier(MPI_COMM_WORLD,ier)

  ! get location/jacobian info from slices
  allocate( slice_x(NGLLX,NGLLY,NGLLZ,NSPEC,nums))
  allocate( slice_y(NGLLX,NGLLY,NGLLZ,NSPEC,nums))
  allocate( slice_z(NGLLX,NGLLY,NGLLZ,NSPEC,nums))
  allocate( slice_jacobian(NGLLX,NGLLY,NGLLZ,NSPEC,nums))
  do rank=0,sizeprocs-1
    if( rank == myrank) then
      jacobian(:,:,:,:) = jacobian0(:,:,:,:)
      x(:,:,:,:) = xstore(:,:,:,:)
      y(:,:,:,:) = ystore(:,:,:,:)
      z(:,:,:,:) = zstore(:,:,:,:)
    endif
    ! every process broadcasts its info
    call MPI_BCAST(x,NGLLX*NGLLY*NGLLZ*NSPEC,CUSTOM_MPI_TYPE,rank,MPI_COMM_WORLD,ier)
    call MPI_BCAST(y,NGLLX*NGLLY*NGLLZ*NSPEC,CUSTOM_MPI_TYPE,rank,MPI_COMM_WORLD,ier)
    call MPI_BCAST(z,NGLLX*NGLLY*NGLLZ*NSPEC,CUSTOM_MPI_TYPE,rank,MPI_COMM_WORLD,ier)
    call MPI_BCAST(jacobian,NGLLX*NGLLY*NGLLZ*NSPEC,CUSTOM_MPI_TYPE,rank,MPI_COMM_WORLD,ier)
    
    ! only relevant process info gets stored
    do ii=1,nums
      if( islice(ii) == rank ) then
        slice_x(:,:,:,:,ii) = x(:,:,:,:)
        slice_y(:,:,:,:,ii) = y(:,:,:,:)
        slice_z(:,:,:,:,ii) = z(:,:,:,:)
        slice_jacobian(:,:,:,:,ii) = jacobian(:,:,:,:)
      endif
    enddo    
  enddo

  ! arrays to smooth
  allocate( slice_kernels(NGLLX,NGLLY,NGLLZ,NSPEC,nums,9))
  do rank=0,sizeprocs-1
    if( rank == myrank) then
      ks_rho(:,:,:,:) = rhostore(:,:,:,:)
      ks_kv(:,:,:,:) = kappavstore(:,:,:,:)
      ks_kh(:,:,:,:) = kappahstore(:,:,:,:)
      ks_muv(:,:,:,:) = muvstore(:,:,:,:)
      ks_muh(:,:,:,:) = muhstore(:,:,:,:)
      ks_eta(:,:,:,:) = eta_anisostore(:,:,:,:)
      if( HETEROGEN_3D_MANTLE ) then
        ks_dvp(:,:,:,:) = dvpstore(:,:,:,:)
      endif
      if( ABSORBING_CONDITIONS ) then
        if( iregion_code == IREGION_CRUST_MANTLE) then
          ks_rhovp(:,:,:,1:nspec_stacey) = rho_vp(:,:,:,1:nspec_stacey)
          ks_rhovs(:,:,:,1:nspec_stacey) = rho_vs(:,:,:,1:nspec_stacey)      
        endif
      endif
      ! in case of 
      !if(ANISOTROPIC_INNER_CORE .and. iregion_code == IREGION_INNER_CORE) then
      ! or
      !if(ANISOTROPIC_3D_MANTLE .and. iregion_code == IREGION_CRUST_MANTLE) then
      ! or
      !if(ATTENUATION .and. ATTENUATION_3D) then      
      ! one should add the c**store and tau_* arrays here as well       
    endif
    ! every process broadcasts its info
    call MPI_BCAST(ks_rho,NGLLX*NGLLY*NGLLZ*NSPEC,CUSTOM_MPI_TYPE,rank,MPI_COMM_WORLD,ier)
    call MPI_BCAST(ks_kv,NGLLX*NGLLY*NGLLZ*NSPEC,CUSTOM_MPI_TYPE,rank,MPI_COMM_WORLD,ier)
    call MPI_BCAST(ks_kh,NGLLX*NGLLY*NGLLZ*NSPEC,CUSTOM_MPI_TYPE,rank,MPI_COMM_WORLD,ier)
    call MPI_BCAST(ks_muv,NGLLX*NGLLY*NGLLZ*NSPEC,CUSTOM_MPI_TYPE,rank,MPI_COMM_WORLD,ier)
    call MPI_BCAST(ks_muh,NGLLX*NGLLY*NGLLZ*NSPEC,CUSTOM_MPI_TYPE,rank,MPI_COMM_WORLD,ier)
    call MPI_BCAST(ks_eta,NGLLX*NGLLY*NGLLZ*NSPEC,CUSTOM_MPI_TYPE,rank,MPI_COMM_WORLD,ier)
    call MPI_BCAST(ks_dvp,NGLLX*NGLLY*NGLLZ*NSPEC,CUSTOM_MPI_TYPE,rank,MPI_COMM_WORLD,ier)
    call MPI_BCAST(ks_rhovp,NGLLX*NGLLY*NGLLZ*NSPEC,CUSTOM_MPI_TYPE,rank,MPI_COMM_WORLD,ier)
    call MPI_BCAST(ks_rhovs,NGLLX*NGLLY*NGLLZ*NSPEC,CUSTOM_MPI_TYPE,rank,MPI_COMM_WORLD,ier)

    ! only relevant process info gets stored
    do ii=1,nums
      if( islice(ii) == rank ) then        
        slice_kernels(:,:,:,:,ii,1) = ks_rho(:,:,:,:)
        slice_kernels(:,:,:,:,ii,2) = ks_kv(:,:,:,:)
        slice_kernels(:,:,:,:,ii,3) = ks_kh(:,:,:,:)
        slice_kernels(:,:,:,:,ii,4) = ks_muv(:,:,:,:)
        slice_kernels(:,:,:,:,ii,5) = ks_muh(:,:,:,:)
        slice_kernels(:,:,:,:,ii,6) = ks_eta(:,:,:,:)
        slice_kernels(:,:,:,:,ii,7) = ks_dvp(:,:,:,:)
        slice_kernels(:,:,:,:,ii,8) = ks_rhovp(:,:,:,:)
        slice_kernels(:,:,:,:,ii,9) = ks_rhovs(:,:,:,:)        
      endif
    enddo      
  enddo

  ! get the global maximum value of the original kernel file
  !call mpi_barrier(MPI_COMM_WORLD,ier)
  !call mpi_reduce(maxval(abs(muvstore(:,:,:,:))), max_old, 1, &
  !              CUSTOM_MPI_TYPE, MPI_MAX, 0, MPI_COMM_WORLD,ier)

  if (myrank == 0) write(IMAIN, *) 'start looping over elements and points for smoothing ...'

! loop over all the slices
  tk_rho(:,:,:,:) = 0.0_CUSTOM_REAL
  tk_kh(:,:,:,:) = 0.0_CUSTOM_REAL
  tk_kv(:,:,:,:) = 0.0_CUSTOM_REAL
  tk_muh(:,:,:,:) = 0.0_CUSTOM_REAL
  tk_muv(:,:,:,:) = 0.0_CUSTOM_REAL
  tk_eta(:,:,:,:) = 0.0_CUSTOM_REAL
  tk_dvp(:,:,:,:) = 0.0_CUSTOM_REAL
  tk_rhovp(:,:,:,:) = 0.0_CUSTOM_REAL
  tk_rhovs(:,:,:,:) = 0.0_CUSTOM_REAL
  
  bk(:,:,:,:) = 0.0_CUSTOM_REAL
  do ii = 1, nums
    if (myrank == 0) starttime = MPI_WTIME()
    if (myrank == 0) write(IMAIN, *) '  slice number = ', ii
   
    ! read in the topology, jacobian, calculate center of elements    
    xx(:,:,:,:) = slice_x(:,:,:,:,ii)
    yy(:,:,:,:) = slice_y(:,:,:,:,ii)
    zz(:,:,:,:) = slice_z(:,:,:,:,ii)    
    jacobian(:,:,:,:) = slice_jacobian(:,:,:,:,ii)

    ! get the location of the center of the elements
    do ispec2 = 1, nspec
      cx(ispec2) = (xx(1,1,1,ispec2) + xx(NGLLX,NGLLZ,NGLLY,ispec2))*0.5
      cy(ispec2) = (yy(1,1,1,ispec2) + yy(NGLLX,NGLLZ,NGLLY,ispec2))*0.5
      cz(ispec2) = (zz(1,1,1,ispec2) + zz(NGLLX,NGLLZ,NGLLY,ispec2))*0.5
    enddo

    !if (myrank == 0) write(IMAIN, *) '    location:',cx(1),cy(1),cz(1)
    !if (myrank == 0) write(IMAIN, *) '    dist:',(cx(1)-cx0(1))**2+(cy(1)-cy0(1))**2,(cz(1)-cz0(1))**2
    !if (myrank == 0) write(IMAIN, *) '    sigma:',sigma_h3,sigma_v3
    
    ! array values
    ks_rho(:,:,:,:) = slice_kernels(:,:,:,:,ii,1)
    ks_kv(:,:,:,:) = slice_kernels(:,:,:,:,ii,2)
    ks_kh(:,:,:,:) = slice_kernels(:,:,:,:,ii,3)
    ks_muv(:,:,:,:) = slice_kernels(:,:,:,:,ii,4)
    ks_muh(:,:,:,:) = slice_kernels(:,:,:,:,ii,5)
    ks_eta(:,:,:,:) = slice_kernels(:,:,:,:,ii,6)
    ks_dvp(:,:,:,:) = slice_kernels(:,:,:,:,ii,7)
    ks_rhovp(:,:,:,:) = slice_kernels(:,:,:,:,ii,8)
    ks_rhovs(:,:,:,:) = slice_kernels(:,:,:,:,ii,9)

    ! loop over elements to be smoothed in the current slice    
    do ispec = 1, nspec 

      if (myrank == 0 .and. mod(ispec,100) == 0 ) write(IMAIN, *) '    ispec ', ispec,' sec:',MPI_WTIME()-starttime

      ! --- only double loop over the elements in the search radius ---
      do ispec2 = 1, nspec
        
        ! checks distance between centers of elements        
        if ( (cx(ispec2)-cx0(ispec))**2 + (cy(ispec2)-cy0(ispec))** 2 > sigma_h3 &
            .or. (cz(ispec2)-cz0(ispec))** 2 > sigma_v3 ) cycle

        factor(:,:,:) = jacobian(:,:,:,ispec2) * wgll_cube(:,:,:) ! integration factors

        ! loop over GLL points of the elements in current slice (ispec)
        do k = 1, NGLLZ 
          do j = 1, NGLLY
            do i = 1, NGLLX
              
              x0 = xl(i,j,k,ispec) 
              y0 = yl(i,j,k,ispec) 
              z0 = zl(i,j,k,ispec) ! current point (i,j,k,ispec)

              ! gaussian function
              exp_val(:,:,:) = exp( -(xx(:,:,:,ispec2)-x0)**2/(2.0*sigma_h2) &
                                    -(yy(:,:,:,ispec2)-y0)**2/(2.0*sigma_h2) &
                                    -(zz(:,:,:,ispec2)-z0)**2/(2.0*sigma_v2) ) * factor(:,:,:)

              ! smoothed kernel values
              tk_rho(i,j,k,ispec) = tk_rho(i,j,k,ispec) + sum(exp_val(:,:,:) * ks_rho(:,:,:,ispec2))
              tk_kv(i,j,k,ispec) = tk_kv(i,j,k,ispec) + sum(exp_val(:,:,:) * ks_kv(:,:,:,ispec2))
              tk_kh(i,j,k,ispec) = tk_kh(i,j,k,ispec) + sum(exp_val(:,:,:) * ks_kh(:,:,:,ispec2))
              tk_muv(i,j,k,ispec) = tk_muv(i,j,k,ispec) + sum(exp_val(:,:,:) * ks_muv(:,:,:,ispec2))
              tk_muh(i,j,k,ispec) = tk_muh(i,j,k,ispec) + sum(exp_val(:,:,:) * ks_muh(:,:,:,ispec2))
              tk_eta(i,j,k,ispec) = tk_eta(i,j,k,ispec) + sum(exp_val(:,:,:) * ks_eta(:,:,:,ispec2))
              tk_dvp(i,j,k,ispec) = tk_dvp(i,j,k,ispec) + sum(exp_val(:,:,:) * ks_dvp(:,:,:,ispec2))
              tk_rhovp(i,j,k,ispec) = tk_rhovp(i,j,k,ispec) + sum(exp_val(:,:,:) * ks_rhovp(:,:,:,ispec2))
              tk_rhovs(i,j,k,ispec) = tk_rhovs(i,j,k,ispec) + sum(exp_val(:,:,:) * ks_rhovs(:,:,:,ispec2))
              
              ! normalization, integrated values of gaussian smoothing function
              bk(i,j,k,ispec) = bk(i,j,k,ispec) + sum(exp_val(:,:,:))

            enddo 
          enddo
        enddo ! (i,j,k)
      enddo ! (ispec2)
    enddo   ! (ispec)
  enddo     ! islice

  if (myrank == 0) write(IMAIN, *) 'Done with integration ...'

  ! gets depths (in km) of upper and lower limit
  maxlat = PPM_V%maxlat
  minlat = PPM_V%minlat
  
  maxlon = PPM_V%maxlon
  minlon = PPM_V%minlon
  
  maxdepth = PPM_V%maxdepth
  mindepth = PPM_V%mindepth

  margin_v = sigma_v*R_EARTH/1000.0 ! in km
  margin_h = sigma_h*R_EARTH/1000.0 * 180.0/(R_EARTH_KM*PI) ! in degree

  ! compute the smoothed kernel values
  do ispec = 1, nspec

    ! depth of given radius (in km)
    call xyz_2_rthetaphi(cx0(ispec),cy0(ispec),cz0(ispec),radius,theta,phi)
    r_depth = R_EARTH_KM - radius*R_EARTH_KM  ! radius is normalized between [0,1]
    if(r_depth>=maxdepth+margin_v .or. r_depth+margin_v < mindepth) cycle

    lat=(PI/2.0d0-theta)*180.0d0/PI
    if( lat < minlat-margin_h .or. lat > maxlat+margin_h ) cycle
      
    lon=phi*180.0d0/PI
    if(lon>180.0d0) lon=lon-360.0d0 
    if( lon < minlon-margin_h .or. lon > maxlon+margin_h ) cycle

    do k = 1, NGLLZ
      do j = 1, NGLLY
        do i = 1, NGLLX

          ! check if bk value has an entry
          if (abs(bk(i,j,k,ispec) ) > 1.e-25 ) then
            
            ! check if (integrated) normalization value is close to theoretically one
            if (abs(bk(i,j,k,ispec) - norm) > 1.e-3*norm ) then ! check the normalization criterion
              print *, 'Problem here --- ', myrank, ispec, i, j, k, bk(i,j,k,ispec), norm
              call exit_mpi(myrank, 'Error computing Gaussian function on the grid')
            endif

            rhostore(i,j,k,ispec) = tk_rho(i,j,k,ispec) / bk(i,j,k,ispec)
            kappavstore(i,j,k,ispec) = tk_kv(i,j,k,ispec) / bk(i,j,k,ispec)
            kappahstore(i,j,k,ispec) = tk_kh(i,j,k,ispec) / bk(i,j,k,ispec)
            muvstore(i,j,k,ispec) = tk_muv(i,j,k,ispec) / bk(i,j,k,ispec)
            muhstore(i,j,k,ispec) = tk_muh(i,j,k,ispec) / bk(i,j,k,ispec)
            eta_anisostore(i,j,k,ispec) = tk_eta(i,j,k,ispec) / bk(i,j,k,ispec)
            if( HETEROGEN_3D_MANTLE ) then
              dvpstore(i,j,k,ispec) = tk_dvp(i,j,k,ispec) / bk(i,j,k,ispec)
            endif
          endif
          
        enddo
      enddo
    enddo
  enddo

  if( ABSORBING_CONDITIONS ) then
    if( iregion_code == IREGION_CRUST_MANTLE) then
      do ispec = 1, nspec_stacey

        ! depth of given radius (in km)
        call xyz_2_rthetaphi(cx0(ispec),cy0(ispec),cz0(ispec),radius,theta,phi)
        r_depth = R_EARTH_KM - radius*R_EARTH_KM  ! radius is normalized between [0,1]
        if(r_depth>=maxdepth+margin_v .or. r_depth+margin_v < mindepth) cycle

        lat=(PI/2.0d0-theta)*180.0d0/PI
        if( lat < minlat-margin_h .or. lat > maxlat+margin_h ) cycle
          
        lon=phi*180.0d0/PI
        if(lon>180.0d0) lon=lon-360.0d0 
        if( lon < minlon-margin_h .or. lon > maxlon+margin_h ) cycle

        do k = 1, NGLLZ
          do j = 1, NGLLY
            do i = 1, NGLLX

              ! check if bk value has an entry
              if (abs(bk(i,j,k,ispec) ) > 1.e-25 ) then
                rho_vp(i,j,k,ispec) = tk_rhovp(i,j,k,ispec)/bk(i,j,k,ispec)
                rho_vs(i,j,k,ispec) = tk_rhovs(i,j,k,ispec)/bk(i,j,k,ispec)              
              endif
              
            enddo
          enddo
        enddo
      enddo
    endif
  endif

  !if (myrank == 0) write(IMAIN, *) 'Maximum data value before smoothing = ', max_old
  
  ! the maximum value for the smoothed kernel
  !call mpi_barrier(MPI_COMM_WORLD,ier)
  !call mpi_reduce(maxval(abs(muvstore(:,:,:,:))), max_new, 1, &
  !           CUSTOM_MPI_TYPE, MPI_MAX, 0, MPI_COMM_WORLD,ier)

  !if (myrank == 0) then
  !  write(IMAIN, *) 'Maximum data value after smoothing = ', max_new
  !  write(IMAIN, *)
  !endif
  !call MPI_BARRIER(MPI_COMM_WORLD,ier)
  
  end subroutine


!  
!--------------------------------------------------------------------------------------------------
!

  subroutine get_all_eight_slices(ichunk,ixi,ieta,&
           ileft,iright,ibot,itop, ilb,ilt,irb,irt,&
           nproc_xi,nproc_eta)

  implicit none

  integer, intent(IN) :: ichunk,ixi,ieta,nproc_xi,nproc_eta
 
  integer, intent(OUT) :: ileft,iright,ibot,itop,ilb,ilt,irb,irt
  integer :: get_slice_number

  
  integer :: ichunk_left, islice_xi_left, islice_eta_left, &
           ichunk_right, islice_xi_right, islice_eta_right, &
           ichunk_bot, islice_xi_bot, islice_eta_bot, &
           ichunk_top, islice_xi_top, islice_eta_top, &
           ileft0,iright0,ibot0,itop0, &
           ichunk_left0, islice_xi_left0, islice_eta_left0, &
           ichunk_right0, islice_xi_right0, islice_eta_right0, &
           ichunk_bot0, islice_xi_bot0, islice_eta_bot0, &
           ichunk_top0, islice_xi_top0, islice_eta_top0


! get the first 4 immediate slices
  call get_lrbt_slices(ichunk,ixi,ieta, &
             ileft, ichunk_left, islice_xi_left, islice_eta_left, &
             iright, ichunk_right, islice_xi_right, islice_eta_right, &
             ibot, ichunk_bot, islice_xi_bot, islice_eta_bot, &
             itop, ichunk_top, islice_xi_top, islice_eta_top, &
             nproc_xi,nproc_eta)

! get the 4 diagonal neighboring slices (actually 3 diagonal slices at the corners)
  ilb = get_slice_number(ichunk,ixi-1,ieta-1,nproc_xi,nproc_eta)
  ilt = get_slice_number(ichunk,ixi-1,ieta+1,nproc_xi,nproc_eta)
  irb = get_slice_number(ichunk,ixi+1,ieta-1,nproc_xi,nproc_eta)
  irt = get_slice_number(ichunk,ixi+1,ieta+1,nproc_xi,nproc_eta)
  
  if (ixi==0) then
    call get_lrbt_slices(ichunk_left,islice_xi_left,islice_eta_left, &
               ileft0, ichunk_left0, islice_xi_left0, islice_eta_left0, &
               iright0, ichunk_right0, islice_xi_right0, islice_eta_right0, &
               ibot0, ichunk_bot0, islice_xi_bot0, islice_eta_bot0, &
               itop0, ichunk_top0, islice_xi_top0, islice_eta_top0, &
               nproc_xi,nproc_eta)

    if (ichunk == 0 .or. ichunk == 1 .or. ichunk == 3 .or. ichunk == 5) then
      ilb = get_slice_number(ichunk_bot0,islice_xi_bot0,islice_eta_bot0,nproc_xi,nproc_eta)
      ilt = get_slice_number(ichunk_top0,islice_xi_top0,islice_eta_top0,nproc_xi,nproc_eta)
    else if (ichunk == 2) then
      ilb = get_slice_number(ichunk_right0,islice_xi_right0,islice_eta_right0,nproc_xi,nproc_eta)
      ilt = get_slice_number(ichunk_left0,islice_xi_left0,islice_eta_left0,nproc_xi,nproc_eta)
    else 
      ilb = get_slice_number(ichunk_left0,islice_xi_left0,islice_eta_left0,nproc_xi,nproc_eta)
      ilt = get_slice_number(ichunk_right0,islice_xi_right0,islice_eta_right0,nproc_xi,nproc_eta)
    endif
  endif

  if (ixi==nproc_xi-1) then
    call get_lrbt_slices(ichunk_right,islice_xi_right,islice_eta_right, &
               ileft0, ichunk_left0, islice_xi_left0, islice_eta_left0, &
               iright0, ichunk_right0, islice_xi_right0, islice_eta_right0, &
               ibot0, ichunk_bot0, islice_xi_bot0, islice_eta_bot0, &
               itop0, ichunk_top0, islice_xi_top0, islice_eta_top0, &
               nproc_xi,nproc_eta)
    if (ichunk == 0 .or. ichunk == 1 .or. ichunk == 3 .or. ichunk == 5) then
      irb = get_slice_number(ichunk_bot0,islice_xi_bot0,islice_eta_bot0,nproc_xi,nproc_eta)
      irt = get_slice_number(ichunk_top0,islice_xi_top0,islice_eta_top0,nproc_xi,nproc_eta)
    else if (ichunk == 2) then
      irb = get_slice_number(ichunk_left0,islice_xi_left0,islice_eta_left0,nproc_xi,nproc_eta)
      irt = get_slice_number(ichunk_right0,islice_xi_right0,islice_eta_right0,nproc_xi,nproc_eta)
    else
      irb = get_slice_number(ichunk_right0,islice_xi_right0,islice_eta_right0,nproc_xi,nproc_eta)
      irt = get_slice_number(ichunk_left0,islice_xi_left0,islice_eta_left0,nproc_xi,nproc_eta)
    endif
  endif

  if (ieta==0) then
    call get_lrbt_slices(ichunk_bot,islice_xi_bot,islice_eta_bot, &
               ileft0, ichunk_left0, islice_xi_left0, islice_eta_left0, &
               iright0, ichunk_right0, islice_xi_right0, islice_eta_right0, &
               ibot0, ichunk_bot0, islice_xi_bot0, islice_eta_bot0, &
               itop0, ichunk_top0, islice_xi_top0, islice_eta_top0, &
               nproc_xi,nproc_eta)
    if (ichunk == 1 .or. ichunk == 2) then
      ilb = get_slice_number(ichunk_left0,islice_xi_left0,islice_eta_left0,nproc_xi,nproc_eta)
      irb = get_slice_number(ichunk_right0,islice_xi_right0,islice_eta_right0,nproc_xi,nproc_eta)
    else if (ichunk == 3 .or. ichunk == 4) then
      ilb = get_slice_number(ichunk_right0,islice_xi_right0,islice_eta_right0,nproc_xi,nproc_eta)
      irb = get_slice_number(ichunk_left0,islice_xi_left0,islice_eta_left0,nproc_xi,nproc_eta)
    else if (ichunk == 0) then
      ilb = get_slice_number(ichunk_top0,islice_xi_top0,islice_eta_top0,nproc_xi,nproc_eta)
      irb = get_slice_number(ichunk_bot0,islice_xi_bot0,islice_eta_bot0,nproc_xi,nproc_eta)
    else
      ilb = get_slice_number(ichunk_bot0,islice_xi_bot0,islice_eta_bot0,nproc_xi,nproc_eta)
      irb = get_slice_number(ichunk_top0,islice_xi_top0,islice_eta_top0,nproc_xi,nproc_eta)
    endif
  endif
  
  if (ieta==nproc_eta-1) then
    call get_lrbt_slices(ichunk_top,islice_xi_top,islice_eta_top, &
               ileft0, ichunk_left0, islice_xi_left0, islice_eta_left0, &
               iright0, ichunk_right0, islice_xi_right0, islice_eta_right0, &
               ibot0, ichunk_bot0, islice_xi_bot0, islice_eta_bot0, &
               itop0, ichunk_top0, islice_xi_top0, islice_eta_top0, &
               nproc_xi,nproc_eta)

    if (ichunk == 1 .or. ichunk == 4) then
      ilt = get_slice_number(ichunk_left0,islice_xi_left0,islice_eta_left0,nproc_xi,nproc_eta)
      irt = get_slice_number(ichunk_right0,islice_xi_right0,islice_eta_right0,nproc_xi,nproc_eta)
    else if (ichunk == 2 .or. ichunk == 3) then
      ilt = get_slice_number(ichunk_right0,islice_xi_right0,islice_eta_right0,nproc_xi,nproc_eta)
      irt = get_slice_number(ichunk_left0,islice_xi_left0,islice_eta_left0,nproc_xi,nproc_eta)
    else if (ichunk == 0) then
      ilt = get_slice_number(ichunk_bot0,islice_xi_bot0,islice_eta_bot0,nproc_xi,nproc_eta)
      irt = get_slice_number(ichunk_top0,islice_xi_top0,islice_eta_top0,nproc_xi,nproc_eta)
    else
      ilt = get_slice_number(ichunk_top0,islice_xi_top0,islice_eta_top0,nproc_xi,nproc_eta)
      irt = get_slice_number(ichunk_bot0,islice_xi_bot0,islice_eta_bot0,nproc_xi,nproc_eta)
    endif

  endif

  end subroutine get_all_eight_slices

!  
!--------------------------------------------------------------------------------------------------
!

  subroutine get_lrbt_slices(ichunk,ixi,ieta, &
           ileft, ichunk_left, islice_xi_left, islice_eta_left, &
           iright, ichunk_right, islice_xi_right, islice_eta_right, &
           ibot, ichunk_bot, islice_xi_bot, islice_eta_bot, &
           itop, ichunk_top, islice_xi_top, islice_eta_top, &
           nproc_xi,nproc_eta)

  implicit none

  integer, intent(IN) :: ichunk, ixi, ieta, nproc_xi, nproc_eta
  integer, intent(OUT) :: ileft, ichunk_left, islice_xi_left, islice_eta_left, &
           iright, ichunk_right, islice_xi_right, islice_eta_right, &
           ibot, ichunk_bot, islice_xi_bot, islice_eta_bot, &
           itop, ichunk_top, islice_xi_top, islice_eta_top

  integer, parameter :: NCHUNKS = 6

  integer, dimension(NCHUNKS) :: chunk_left,chunk_right,chunk_bot,chunk_top, &
             slice_xi_left,slice_eta_left,slice_xi_right,slice_eta_right, &
             slice_xi_bot,slice_eta_bot,slice_xi_top,slice_eta_top
  integer :: get_slice_number

! set up mapping arrays -- assume chunk/slice number starts from 0
  chunk_left(:) = (/2,6,6,1,6,4/) - 1
  chunk_right(:) = (/4,1,1,6,1,2/) - 1
  chunk_bot(:) = (/5,5,2,5,4,5/) - 1
  chunk_top(:) = (/3,3,4,3,2,3/) - 1

  slice_xi_left(:) = (/nproc_xi-1,nproc_xi-1,nproc_xi-1-ieta,nproc_xi-1,ieta,nproc_xi-1/)
  slice_eta_left(:) = (/ieta,ieta,nproc_eta-1,ieta,0,ieta/)
  slice_xi_right(:) = (/0,0,ieta,0,nproc_xi-1-ieta,0/)
  slice_eta_right(:) = (/ieta,ieta,nproc_eta-1,ieta,0,ieta/)

  slice_xi_bot(:) = (/nproc_xi-1,ixi,ixi,nproc_xi-1-ixi,nproc_xi-1-ixi,0/)
  slice_eta_bot(:) = (/nproc_eta-1-ixi,nproc_eta-1,nproc_eta-1,0,0,ixi/)
  slice_xi_top(:) = (/nproc_xi-1,ixi,nproc_xi-1-ixi,nproc_xi-1-ixi,ixi,0/)
  slice_eta_top(:) = (/ixi,0,nproc_eta-1,nproc_eta-1,0,nproc_eta-1-ixi /)

  ichunk_left = ichunk
  ichunk_right = ichunk
  ichunk_bot = ichunk
  ichunk_top = ichunk

  islice_xi_left = ixi-1
  islice_eta_left = ieta
  islice_xi_right = ixi+1
  islice_eta_right = ieta

  islice_xi_bot = ixi
  islice_eta_bot = ieta-1
  islice_xi_top = ixi
  islice_eta_top = ieta+1

  if (ixi == 0) then
    ichunk_left=chunk_left(ichunk+1)
    islice_xi_left=slice_xi_left(ichunk+1)
    islice_eta_left=slice_eta_left(ichunk+1)
  endif
  if (ixi == nproc_xi - 1) then
    ichunk_right=chunk_right(ichunk+1)
    islice_xi_right=slice_xi_right(ichunk+1)
    islice_eta_right=slice_eta_right(ichunk+1)
  endif
  if (ieta == 0) then
    ichunk_bot=chunk_bot(ichunk+1)
    islice_xi_bot=slice_xi_bot(ichunk+1)
    islice_eta_bot=slice_eta_bot(ichunk+1)
  endif
  if (ieta == nproc_eta - 1) then
    ichunk_top=chunk_top(ichunk+1)
    islice_xi_top=slice_xi_top(ichunk+1)
    islice_eta_top=slice_eta_top(ichunk+1)
  endif
  
  ileft = get_slice_number(ichunk_left,islice_xi_left,islice_eta_left,nproc_xi,nproc_eta)
  iright = get_slice_number(ichunk_right,islice_xi_right,islice_eta_right,nproc_xi,nproc_eta)
  ibot = get_slice_number(ichunk_bot,islice_xi_bot,islice_eta_bot,nproc_xi,nproc_eta)
  itop = get_slice_number(ichunk_top,islice_xi_top,islice_eta_top,nproc_xi,nproc_eta)

  end subroutine get_lrbt_slices

!  
!--------------------------------------------------------------------------------------------------
!

  integer function get_slice_number(ichunk,ixi,ieta,nproc_xi,nproc_eta)

  implicit none

  integer :: ichunk, ixi, ieta, nproc_xi, nproc_eta

   get_slice_number = ichunk*nproc_xi*nproc_eta+ieta*nproc_xi+ixi

 end function get_slice_number
  
 