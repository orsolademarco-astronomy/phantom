!--------------------------------------------------------------------------!
! The Phantom Smoothed Particle Hydrodynamics code, by Daniel Price et al. !
! Copyright (c) 2007-2017 The Authors (see AUTHORS)                        !
! See LICENCE file for usage and distribution conditions                   !
! http://users.monash.edu.au/~dprice/phantom                               !
!--------------------------------------------------------------------------!
!+
!  MODULE: growth
!
!  DESCRIPTION:
!  Contains routine for dust growth and fragmentation
!
!  REFERENCES:
!  Stepinski & Valageas (1997)
!  Kobayashi & Tanaka (2008)
!
!  OWNER: Arnaud Vericel
!
!  $Id$
!
!  RUNTIME PARAMETERS:
!    ifrag             -- fragmentation of dust (0=off, 1=on, 2=Kobayashi)
!    grainsizemin      -- minimum grain size in cm
!    isnow             -- snow line (0=off, 1=position based, 2=temperature based)
!    rsnow             -- snow line position in AU
!	 Tsnow			   -- snow line condensation temperature in K
!    vfragin           -- inward fragmentation threshold in m/s
!    vfragout          -- outward fragmentation threshold in m/s
!    vfrag			   -- uniform fragmentation threshold in m/s
!
!  DEPENDENCIES: part,physcon,units,eos,infile_utiles,io,dim,options
!+
!--------------------------------------------------------------------------

module growth
 use units,	only:udist,unit_density,unit_velocity
 use physcon,	only:au,Ro
 use part,		only:xyzmh_ptmass
 implicit none
 
 !--Default values for the growth and fragmentation of dust in the input file
 integer, public	:: ifrag	= 1         
 integer, public	:: isnow	= 0         
 
 real, public		:: grainsizemin	= 1.e-3
 real, public		:: rsnow	= 100.
 real, public		:: Tsnow	= 20.
 real, public		:: vfrag	= 15.   
 real, public		:: vfragin	= 5.       
 real, public		:: vfragout	= 15.    
 
 public			:: growth_rate,get_vrelonvfrag
 public			:: write_options_growth,read_options_growth,print_growthinfo,init_growth
 public			:: vrelative
 
contains
	
!------------------------------------------------
!+
!  Initialise variables for computing growth rate
!+
!------------------------------------------------
subroutine init_growth(ierr)
 use io,	only:error
 use part,	only:dustprop
 use dim,	only:maxp_growth
 use dust,	only:grainsize,graindens
 integer, intent(out) :: ierr
 
 integer			  :: i
 
 i = 0
 ierr = 0
 
 dustprop(1,:) = grainsize
 dustprop(2,:) = graindens
 
 !-- Check that all the parameters are > 0 when needed
 do i=1,maxp_growth
	!print*,'INIT GROWTH',dustprop(1,i),dustprop(2,i)
 	if (dustprop(1,i) < 0) then
		call error('init_growth','grainsize < 0',var='dustprop',val=dustprop(1,i))
 		ierr = 1 
 	endif
 	if (dustprop(2,i) < 0) then
		call error('init_growth','graindens < 0',var='dustprop',val=dustprop(2,i))
    	ierr = 1 
    endif
 	if (dustprop(3,i) < 0) then
		call error('init_growth','vrel/vfrag < 0',var='dustprop',val=dustprop(3,i))
    	ierr = 1 
    endif
 enddo
 
 if (ifrag > 0) then
	if (grainsizemin < 0) then
		call error('init_growth','grainsizemin < 0',var='grainsizemin',val=grainsizemin)
		ierr = 1
    endif
	select case(isnow)
	case(0) !-- uniform vfrag
 		if (vfrag <= 0) then
			call error('init_growth','vfrag <= 0',var='vfrag',val=vfrag)
			ierr = 2
		endif
 	case(1) !--position based snow line
    	if (rsnow <= 0) then
	   		call error('init_growth','rsnow <= 0',var='rsnow',val=rsnow)
	   		ierr = 2
    	endif 
 	case(2) !-- temperature based snow line
 		if (Tsnow <= 0) then
       		call error('init_growth','Tsnow <= 0',var='Tsnow',val=Tsnow)
   	  		ierr = 2
 		endif
 	case default 
 		ierr = 0
 	end select
 endif
 
 if (isnow > 0) then
	 if (vfragin <= 0) then
 		call error('init_growth','vfragin <= 0',var='vfragin',val=vfragin)
 		ierr = 3
	 endif
	 if (vfragout <= 0) then
 	 	call error('init_growth','vfragout <= 0',var='vfragout',val=vfragout)
 		ierr = 3
	 endif
 endif
 
end subroutine init_growth	
		
!----------------------------------------------------------
!+
!  print information about growth and fragmentation of dust
!+
!----------------------------------------------------------
subroutine print_growthinfo(iprint)
 integer, intent(in) :: iprint
 
 if (ifrag == 0) write(iprint,"(a)")    ' Using pure growth model where ds = + vrel*rhod/graindens*dt    '
 if (ifrag == 1) write(iprint,"(a)")    ' Using growth/frag where ds = (+ or -) vrel*rhod/graindens*dt   '
 if (ifrag == 2) write(iprint,"(a)")    ' Using growth with Kobayashi fragmentation model       		 '
 if (ifrag > 0) then
 	write(iprint,"(2(a,1pg10.3),a)")' grainsizemin = ',grainsizemin*udist,' cm = ',grainsizemin,' (code units)'
 	if (isnow == 1) then
 		write(iprint,"(a)")              ' ===> Using position based snow line <===	           					    '
		write(iprint,"(2(a,1pg10.3),a)") '   rsnow = ',rsnow*udist/au            ,'    AU = ',rsnow   ,' (code units)'    
    endif
	if (isnow == 2) then
  		write(iprint,"(a)")              ' ===> Using temperature based snow line <===							    '
 		write(iprint,"(2(a,1pg10.3),a)") '   Tsnow = ',Tsnow				        ,'     K = ',Tsnow   ,' (code units)'
 	endif
	if (isnow == 0) then
		write(iprint,"(2(a,1pg10.3),a)") '   vfrag = ',vfrag*unit_velocity/100   ,'   m/s = ',vfrag   ,' (code units)'
    else
		write(iprint,"(2(a,1pg10.3),a)") ' vfragin = ',vfragin*unit_velocity/100 ,'   m/s = ',vfragin ,' (code units)'
		write(iprint,"(2(a,1pg10.3),a)") ' vfragin = ',vfragout*unit_velocity/100,'   m/s = ',vfragout,' (code units)'
    endif
 endif
	
end subroutine print_growthinfo

!-----------------------------------------------------------------------
!+
!  Main routine that make the dust grow and shatter.
!  It is currently available only for the 
!  two-fluid dust method.
!+
!-----------------------------------------------------------------------
subroutine growth_rate(xyzh,vxyzu,dustprop,rhod,ts,dsdt) 
 real, intent(inout)	:: dustprop(:)
 real, intent(out)		:: dsdt
 real, intent(in)		:: rhod,ts
 real, intent(in)		:: xyzh(:),vxyzu(:)
 
 real					:: vrel
 
 !--compute vrel and vrel/vfrag from get_vrelonvfrag subroutine
 call get_vrelonvfrag(xyzh,vxyzu,dustprop(3),dustprop(4),rhod,vrel,ts)
 !
 !--If statements to compute ds
 !--dustprop(1)= size, dustprop(2) = intrinsic density, dustprop(3) = local vrel/vfrag, dustprop(4) = vd - vg
 !
 if (dustprop(3) >= 1.) then ! vrel/vfrag < 1 --> growth
 	dsdt = rhod/dustprop(2)*vrel
 elseif (dustprop(3) < 1. .and. ifrag > 0) then ! vrel/vfrag > 1 --> fragmentation 
	select case(ifrag)
	case(1)
		dsdt = -rhod/dustprop(2)*vrel ! Symmetrical of Stepinski & Valageas
	case(2)
	    dsdt = -rhod/dustprop(2)*vrel*(dustprop(3)**2)/(1+dustprop(3)**2) ! Kobayashi model
	case default
    end select
	
	if (dustprop(1) < grainsizemin) then
		dustprop(1) = grainsizemin ! Prevent dust from becoming too small
	endif
 endif
end subroutine growth_rate
 
!-----------------------------------------------------------------------
!+
!  Compute the local ratio vrel/vfrag and vrel
!+
!-----------------------------------------------------------------------
subroutine get_vrelonvfrag(xyzh,vxyzu,vrelonvfrag,dv,rhod,vrel,ts) 
 use eos,			only:ieos,get_spsound,get_temperature	
 use options,		only:alpha
 real, intent(in)	:: xyzh(4),vxyzu(4),rhod,dv,ts
 real, intent(out)	:: vrelonvfrag,vrel
 
 real				:: St,Vt,cs,T,r
 
 !--compute sound speed & terminal velocity
 !cs = get_spsound(ieos,xyzh,rhod,vxyzu)
 Vt = sqrt((2**0.5)*Ro*alpha)*cs
 
 !--compute the Stokes number
 r = sqrt(xyzh(1)**2+xyzh(2)**2)
 St = sqrt(xyzmh_ptmass(4,1)/r**3)*ts !G=1 in code units
 
 !--compute vrel
 vrel = vrelative(cs,St,dv,Vt,alpha)
 
 !
 !--If statements to compute local ratio vrel/vfrag 
 !
 select case(isnow)
 case(0) !--uniform vfrag
	vrelonvfrag = vrel / vfrag
 case(1) !--position based snow line in cylindrical geometry
	if (r < rsnow) vrelonvfrag = vrel / vfragin
	if (r > rsnow) vrelonvfrag = vrel / vfragout
 case(2) !--temperature based snow line wrt eos
 	!T = get_temperature(ieos,xyzh,rhod,vxyzu)
	if (T > Tsnow) vrelonvfrag = vrel / vfragin
	if (T < Tsnow) vrelonvfrag = vrel / vfragout
 case default
 	vrelonvfrag = 0.
	vrel = 0.
 end select
 
end subroutine get_vrelonvfrag

!-----------------------------------------------------------------------
!+
!  Write growth options in the input file
!+
!-----------------------------------------------------------------------
subroutine write_options_growth(iunit)
 use infile_utils,	only:write_inopt
 integer, intent(in)	:: iunit

 write(iunit,"(/,a)") '# options controlling growth'
 call write_inopt(ifrag,'ifrag','dust fragmentation (0=off,1=on,2=Kobayashi)',iunit)
 if (ifrag /= 0) then
 	call write_inopt(grainsizemin,'grainsizemin','minimum grain size in cm',iunit)
 	call write_inopt(isnow,'isnow','snow line (0=off,1=position based,2=temperature based)',iunit)
 	if (isnow == 1) call write_inopt(rsnow,'rsnow','position of the snow line in AU',iunit)
 	if (isnow == 2) call write_inopt(rsnow,'Tsnow','snow line condensation temperature in K',iunit)
 	if (isnow == 0) call write_inopt(vfrag,'vfrag','uniform fragmentation threshold in m/s',iunit)
 	if (isnow > 0) then
 		call write_inopt(vfragin,'vfragin','inward fragmentation threshold in m/s',iunit)
 		call write_inopt(vfragout,'vfragout','outward fragmentation threshold in m/s',iunit)
	endif
 endif

end subroutine write_options_growth

!-----------------------------------------------------------------------
!+
!  Read growth options from the input file
!+
!-----------------------------------------------------------------------
subroutine read_options_growth(name,valstring,imatch,igotall,ierr)
 character(len=*), intent(in)	:: name,valstring
 logical,intent(out)			:: imatch,igotall
 integer,intent(out)			:: ierr
 
 integer,save					:: ngot = 0
  
 imatch  = .true.
 igotall = .false.
 
 select case(trim(name))
 case('ifrag')
    read(valstring,*,iostat=ierr) ifrag
    ngot = ngot + 1
 case('grainsizemin')
    read(valstring,*,iostat=ierr) grainsizemin
	grainsizemin = grainsizemin / udist
    ngot = ngot + 1
 case('isnow')
    read(valstring,*,iostat=ierr) isnow
	ngot = ngot + 1
 case('rsnow')
    read(valstring,*,iostat=ierr) rsnow
	rsnow = rsnow * au / udist
    ngot = ngot + 1
 case('Tsnow')
    read(valstring,*,iostat=ierr) Tsnow
    ngot = ngot + 1
 case('vfrag')
    read(valstring,*,iostat=ierr) vfrag
	vfrag = vfrag * 100 / unit_velocity
	ngot = ngot + 1
 case('vfragin')
    read(valstring,*,iostat=ierr) vfragin
	vfragin = vfragin * 100 / unit_velocity
	ngot = ngot + 1
 case('vfragout')
    read(valstring,*,iostat=ierr) vfragout
	vfragout = vfragout * 100 / unit_velocity
	ngot = ngot + 1
    case default
    imatch = .false.
 end select
 
 if (ifrag == 0 .and. ngot == 1) igotall = .true.
 if (isnow == 0) then
 	if (ngot == 4) igotall = .true.
 elseif (isnow > 0) then
 	if (ngot == 6) igotall = .true.
 else
 	igotall = .false.
 endif
end subroutine read_options_growth

!--Compute the relative velocity following Stepinski & Valageas (1997)
real function vrelative(spsound,St,dv,Vt,alpha)
 real, intent(in) :: spsound,St,alpha,dv,Vt
 real			  :: Sc

 !--compute Schmidt number Sc
 Sc = (1+St)*sqrt(1+dv**2/Vt**2)

 !--then compute vrel
 vrelative = sqrt(2**(1.5)*Ro*alpha)*spsound*sqrt(Sc-1)/(Sc)
 
 return
end function vrelative

end module growth
